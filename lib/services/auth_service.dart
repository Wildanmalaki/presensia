import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> _extractJsonList(
  Map<String, dynamic> source,
  List<String> keys,
) {
  for (final key in keys) {
    final value = source[key];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    if (value is Map<String, dynamic>) {
      final nestedList = value['data'];
      if (nestedList is List) {
        return nestedList.whereType<Map<String, dynamic>>().toList();
      }
    }
  }
  return const <Map<String, dynamic>>[];
}

String _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
  }
  return '';
}

int _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return 0;
}

List<TrainingOption> _deduplicateTrainings(List<TrainingOption> trainings) {
  final seenKeys = <String>{};
  final result = <TrainingOption>[];

  for (final training in trainings) {
    final normalizedTitle = training.title.trim().toLowerCase();
    final key = training.id > 0
        ? 'id:${training.id}'
        : 'title:$normalizedTitle';
    if (normalizedTitle.isEmpty || seenKeys.contains(key)) {
      continue;
    }
    seenKeys.add(key);
    result.add(training);
  }

  return result;
}

class TrainingOption {
  const TrainingOption({required this.id, required this.title});

  final int id;
  final String title;

  factory TrainingOption.fromJson(Map<String, dynamic> json) {
    final resolvedTitle = _readString(json, const [
      'title',
      'name',
      'training_name',
      'nama',
    ]);

    return TrainingOption(
      id: _readInt(json, const ['id', 'training_id']),
      title: resolvedTitle.isEmpty ? 'Jurusan tanpa nama' : resolvedTitle,
    );
  }
}

class BatchOption {
  const BatchOption({
    required this.id,
    required this.label,
    required this.trainings,
  });

  final int id;
  final String label;
  final List<TrainingOption> trainings;

  factory BatchOption.fromJson(Map<String, dynamic> json) {
    final rawTrainings = _extractJsonList(json, const [
      'trainings',
      'training',
      'jurusans',
      'majors',
    ]);
    final parsedTrainings = rawTrainings.map(TrainingOption.fromJson).toList();
    final trainings = _deduplicateTrainings(parsedTrainings);
    final batchLabel = _readString(json, const [
      'label',
      'name',
      'title',
      'batch_name',
    ]);
    final batchNumber = _readString(json, const ['batch_ke', 'batch']);

    return BatchOption(
      id: _readInt(json, const ['id', 'batch_id']),
      label: batchLabel.isNotEmpty
          ? batchLabel
          : batchNumber.isNotEmpty
          ? 'Batch $batchNumber'
          : 'Batch',
      trainings: trainings,
    );
  }
}

class AuthResponse {
  const AuthResponse({
    required this.success,
    this.message,
    this.token,
    this.user,
  });

  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? user;
}

class AuthService {
  static const String baseUrl = 'https://appabsensi.mobileprojp.com';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static Future<Map<String, String>> _headersWithAuth() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return _headers;
    }
    return {..._headers, 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, String>> _authOnlyHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return const {'Accept': 'application/json'};
    }
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, dynamic>> _getAuthorized(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .get(uri, headers: await _headersWithAuth())
        .timeout(_requestTimeout);
    final body = _tryDecode(response.body);
    if (response.statusCode == 200) {
      return body ?? <String, dynamic>{};
    }
    throw Exception(
      _parseMessage(body) ?? 'Terjadi kesalahan saat memuat data.',
    );
  }

  static const String _tokenKey = 'auth_token';
  static const String _userNameKey = 'user_name';

  static Future<bool> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_tokenKey, token);
  }

  static Future<bool> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_userNameKey, name);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
  }

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/login');
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);
      final auth = _fromResponse(response);
      if (auth.success && auth.token != null) {
        await saveToken(auth.token!);
      }
      if (auth.success && auth.user != null) {
        final name = (auth.user!['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          await saveUserName(name);
        }
      }
      return auth;
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Permintaan terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server. Coba lagi.',
      );
    }
  }

  static Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required int batchId,
    required int trainingId,
    required String jenisKelamin,
    String? passwordConfirmation,
  }) async {
    final Map<String, dynamic> body = {
      'name': name,
      'email': email,
      'password': password,
      'batch_id': batchId,
      'training_id': trainingId,
      'jenis_kelamin': jenisKelamin,
    };

    if (passwordConfirmation?.isNotEmpty == true) {
      body['password_confirmation'] = passwordConfirmation;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/register');
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      final auth = _fromResponse(response);
      if (auth.success && auth.token != null) {
        await saveToken(auth.token!);
      }
      if (auth.success && auth.user != null) {
        final name = (auth.user!['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          await saveUserName(name);
        }
      }
      return auth;
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Registrasi terlalu lama diproses. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server. Coba lagi.',
      );
    }
  }

  static Future<List<BatchOption>> fetchBatchOptions() async {
    try {
      final uri = Uri.parse('$baseUrl/api/batches');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_requestTimeout);
      final body = _tryDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(_parseMessage(body) ?? 'Gagal memuat data batch.');
      }

      final data = body?['data'];
      if (data is! List) {
        return <BatchOption>[];
      }

      final parsed = data
          .whereType<Map<String, dynamic>>()
          .map(BatchOption.fromJson)
          .toList();

      return parsed;
    } on TimeoutException {
      throw Exception('Memuat batch terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat data batch. Coba lagi.');
    }
  }

  static Future<List<TrainingOption>> fetchTrainingOptions() async {
    try {
      final uri = Uri.parse('$baseUrl/api/trainings');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_requestTimeout);
      final body = _tryDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(_parseMessage(body) ?? 'Gagal memuat data jurusan.');
      }

      final data = body?['data'];
      if (data is! List) {
        return <TrainingOption>[];
      }

      final trainings = data
          .whereType<Map<String, dynamic>>()
          .map(TrainingOption.fromJson)
          .toList();

      return _deduplicateTrainings(trainings);
    } on TimeoutException {
      throw Exception('Memuat jurusan terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat data jurusan. Coba lagi.');
    }
  }

  static Future<Map<String, dynamic>> fetchProfile() async {
    try {
      return await _getAuthorized('/api/profile');
    } on TimeoutException {
      throw Exception('Memuat profil terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat data profil. Coba lagi.');
    }
  }

  static Future<AuthResponse> updateProfile({required String name}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/profile');
      final response = await http
          .put(
            uri,
            headers: await _headersWithAuth(),
            body: jsonEncode({'name': name}),
          )
          .timeout(_requestTimeout);

      final body = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final updatedName = _extractUpdatedName(body) ?? name.trim();
        if (updatedName.isNotEmpty) {
          await saveUserName(updatedName);
        }
        return AuthResponse(
          success: true,
          message: _parseMessage(body) ?? 'Profil berhasil diperbarui.',
          user: body?['data'] as Map<String, dynamic>?,
        );
      }

      return AuthResponse(
        success: false,
        message: _parseMessage(body) ?? 'Gagal memperbarui profil.',
      );
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Permintaan ubah profil terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server saat memperbarui profil.',
      );
    }
  }

  static Future<AuthResponse> updateProfilePhoto({
    required File imageFile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/profile/photo');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _authOnlyHeaders());
      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final body = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse(
          success: true,
          message: _parseMessage(body) ?? 'Foto profil berhasil diperbarui.',
          user: body?['data'] as Map<String, dynamic>?,
        );
      }

      return AuthResponse(
        success: false,
        message: _parseMessage(body) ?? 'Gagal memperbarui foto profil.',
      );
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Upload foto profil terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server saat upload foto profil.',
      );
    }
  }

  static Future<Map<String, dynamic>> fetchAttendanceStats() async {
    try {
      return await _getAuthorized('/api/absen/stats');
    } on TimeoutException {
      throw Exception('Memuat statistik terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat statistik absen. Coba lagi.');
    }
  }

  static Future<Map<String, dynamic>> fetchAttendanceToday() async {
    try {
      return await _getAuthorized('/api/absen/today');
    } on TimeoutException {
      throw Exception('Memuat data absensi hari ini terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat data absensi hari ini. Coba lagi.');
    }
  }

  static Future<AuthResponse> checkIn({
    required double lat,
    required double lng,
    required String address,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/absen/check-in');
      final response = await http
          .post(
            uri,
            headers: await _headersWithAuth(),
            body: jsonEncode({
              'check_in_lat': lat,
              'check_in_lng': lng,
              'check_in_address': address,
            }),
          )
          .timeout(_requestTimeout);

      final body = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse(
          success: true,
          message: _parseMessage(body) ?? 'Absen masuk berhasil.',
          token: null,
          user: null,
        );
      }
      return AuthResponse(
        success: false,
        message: _parseMessage(body) ?? 'Gagal melakukan absen masuk.',
      );
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Permintaan absen masuk terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server saat absen masuk.',
      );
    }
  }

  static Future<AuthResponse> checkOut({
    required double lat,
    required double lng,
    required String address,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/absen/check-out');
      final response = await http
          .post(
            uri,
            headers: await _headersWithAuth(),
            body: jsonEncode({
              'check_out_lat': lat,
              'check_out_lng': lng,
              'check_out_address': address,
            }),
          )
          .timeout(_requestTimeout);

      final body = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse(
          success: true,
          message: _parseMessage(body) ?? 'Absen keluar berhasil.',
          token: null,
          user: null,
        );
      }
      return AuthResponse(
        success: false,
        message: _parseMessage(body) ?? 'Gagal melakukan absen keluar.',
      );
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Permintaan absen keluar terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server saat absen keluar.',
      );
    }
  }

  static Future<AuthResponse> requestLeave({required String reason}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/absen/izin');
      final response = await http
          .post(
            uri,
            headers: await _headersWithAuth(),
            body: jsonEncode({'alasan_izin': reason}),
          )
          .timeout(_requestTimeout);

      final body = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse(
          success: true,
          message: _parseMessage(body) ?? 'Izin berhasil diajukan.',
          token: null,
          user: null,
        );
      }
      return AuthResponse(
        success: false,
        message: _parseMessage(body) ?? 'Gagal mengajukan izin.',
      );
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Permintaan izin terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server saat mengajukan izin.',
      );
    }
  }

  static AuthResponse _fromResponse(http.Response response) {
    final Map<String, dynamic>? body = _tryDecode(response.body);
    final message = _parseMessage(body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AuthResponse(
        success: true,
        message: message ?? 'Berhasil.',
        token: body?['data']?['token'] as String?,
        user: body?['data']?['user'] as Map<String, dynamic>?,
      );
    }

    return AuthResponse(
      success: false,
      message: message ?? 'Terjadi kesalahan saat menghubungkan ke server.',
    );
  }

  static String? _parseMessage(Map<String, dynamic>? body) {
    if (body == null) return null;

    if (body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }

    if (body['errors'] is Map<String, dynamic>) {
      final errors = body['errors'] as Map<String, dynamic>;
      final messages = <String>[];
      for (final error in errors.values) {
        if (error is List) {
          for (final item in error) {
            if (item is String) {
              messages.add(item);
            }
          }
        } else if (error is String) {
          messages.add(error);
        }
      }
      if (messages.isNotEmpty) {
        return messages.join(' ');
      }
    }

    return null;
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static String? _extractUpdatedName(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is Map<String, dynamic>) {
      final name = data['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        final nestedName = user['name']?.toString().trim();
        if (nestedName != null && nestedName.isNotEmpty) {
          return nestedName;
        }
      }
    }
    return null;
  }

  static String? resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null) {
      return null;
    }

    final normalized = rawUrl.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }

    if (!uri.hasScheme) {
      final path = normalized.startsWith('/') ? normalized : '/$normalized';
      return '$baseUrl$path';
    }

    final baseUri = Uri.parse(baseUrl);
    final host = uri.host.toLowerCase();
    if (host == '127.0.0.1' || host == 'localhost') {
      return uri
          .replace(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : 443,
          )
          .toString();
    }

    return normalized;
  }
}
