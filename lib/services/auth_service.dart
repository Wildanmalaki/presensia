import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:presensia/models/auth_models.dart';
import 'package:presensia/models/leave_history_entry.dart';
import 'package:presensia/services/auth_local_storage.dart';

export 'package:presensia/models/auth_models.dart';

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

  static Future<bool> saveToken(String token) =>
      AuthLocalStorage.saveToken(token);

  static Future<bool> saveUserName(String name) =>
      AuthLocalStorage.saveUserName(name);

  static Future<String?> getToken() => AuthLocalStorage.getToken();

  static Future<String?> getUserName() => AuthLocalStorage.getUserName();

  static Future<bool> saveProfilePhotoUrl(String url) =>
      AuthLocalStorage.saveProfilePhotoUrl(url);

  static Future<String?> getProfilePhotoUrl() =>
      AuthLocalStorage.getProfilePhotoUrl();

  static Future<void> clearToken() => AuthLocalStorage.clearSession();

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
        await clearToken();
        await saveToken(auth.token!);
      } else if (auth.success) {
        await clearToken();
        return const AuthResponse(
          success: false,
          message: 'Sesi login tidak valid. Token pengguna tidak ditemukan.',
        );
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
        await clearToken();
        await saveToken(auth.token!);
      } else if (auth.success) {
        await clearToken();
        return const AuthResponse(
          success: false,
          message:
              'Registrasi berhasil, tapi sesi akun baru belum diterima. Silakan login ulang.',
        );
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
      return trainings;
      // return _deduplicateTrainings(trainings);
    } on TimeoutException {
      throw Exception('Memuat jurusan terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat data jurusan. Coba lagi.');
    }
  }

  static Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final response = await _getAuthorized('/api/profile');
      final photoUrl = _extractProfilePhotoUrl(response);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await saveProfilePhotoUrl(photoUrl);
      }
      return response;
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
      final stringResult = await _submitProfilePhotoAsString(
        imageFile: imageFile,
      );
      if (stringResult.success) {
        return stringResult;
      }

      final stringMessage = (stringResult.message ?? '').toLowerCase();
      final shouldFallbackToFile =
          stringMessage.contains('must be an image') ||
          stringMessage.contains('file') ||
          stringMessage.contains('uploaded') ||
          stringMessage.contains('invalid');
      if (!shouldFallbackToFile) {
        return stringResult;
      }

      final candidateFields = <String>['photo', 'avatar', 'image'];
      AuthResponse lastFailure = stringResult;
      for (final fieldName in candidateFields) {
        final result = await _submitProfilePhotoAsFile(
          imageFile: imageFile,
          fieldName: fieldName,
        );
        if (result.success) {
          return result;
        }
        lastFailure = result;
      }

      return lastFailure;
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

  static Future<AuthResponse> _submitProfilePhotoAsString({
    required File imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/api/profile/photo');
    final bytes = await imageFile.readAsBytes();
    final extension = imageFile.path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final encodedImage = 'data:$mimeType;base64,${base64Encode(bytes)}';

    final response = await http
        .put(
          uri,
          headers: await _headersWithAuth(),
          body: jsonEncode({'profile_photo': encodedImage}),
        )
        .timeout(_requestTimeout);
    final body = _tryDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final photoUrl = _extractProfilePhotoUrl(body);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await saveProfilePhotoUrl(photoUrl);
      }
      return AuthResponse(
        success: true,
        message: _parseMessage(body) ?? 'Foto profil berhasil diperbarui.',
        user: body?['data'] as Map<String, dynamic>?,
      );
    }

    return AuthResponse(
      success: false,
      message:
          _parseMessage(body) ??
          _fallbackResponseMessage(
            response,
            defaultMessage: 'Gagal memperbarui foto profil.',
          ),
    );
  }

  static Future<AuthResponse> _submitProfilePhotoAsFile({
    required File imageFile,
    required String fieldName,
  }) async {
    final uri = Uri.parse('$baseUrl/api/profile/photo');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authOnlyHeaders());
    request.fields['_method'] = 'PUT';
    request.files.add(
      await http.MultipartFile.fromPath(fieldName, imageFile.path),
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
      message:
          _parseMessage(body) ??
          _fallbackResponseMessage(
            response,
            defaultMessage: 'Gagal memperbarui foto profil.',
          ),
    );
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

  static Future<Map<String, dynamic>> fetchAttendanceHistory({
    required String start,
    required String end,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/absen/history',
      ).replace(queryParameters: {'start': start, 'end': end});
      final response = await http
          .get(uri, headers: await _headersWithAuth())
          .timeout(_requestTimeout);
      final body = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return body ?? <String, dynamic>{};
      }
      throw Exception(
        _parseMessage(body) ?? 'Terjadi kesalahan saat memuat riwayat.',
      );
    } on TimeoutException {
      throw Exception('Memuat riwayat absensi terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat riwayat absensi. Coba lagi.');
    }
  }

  static Future<AuthResponse> checkIn({
    required double lat,
    required double lng,
    required String address,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/absen/check-in');
      final now = DateTime.now();
      final response = await http
          .post(
            uri,
            headers: await _headersWithAuth(),
            body: jsonEncode({
              'attendance_date': _formatDate(now),
              'check_in': _formatTime(now),
              'check_in_lat': lat,
              'check_in_lng': lng,
              'check_in_address': address,
              'status': 'masuk',
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
      final now = DateTime.now();
      final response = await http
          .post(
            uri,
            headers: await _headersWithAuth(),
            body: jsonEncode({
              'attendance_date': _formatDate(now),
              'check_out': _formatTime(now),
              'check_out_lat': lat,
              'check_out_lng': lng,
              'check_out_location': '$lat,$lng',
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

  static Future<AuthResponse> requestLeave({
    required String reason,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    File? proofImage,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/izin');
      final firstDate = _normalizeDate(startDate ?? DateTime.now());
      final lastDate = _normalizeDate(endDate ?? firstDate);

      if (lastDate.isBefore(firstDate)) {
        return const AuthResponse(
          success: false,
          message: 'Tanggal selesai tidak boleh lebih awal dari tanggal mulai.',
        );
      }

      final headers = await _headersWithAuth();
      final leaveReason = _composeLeaveReason(
        reason: reason,
        leaveType: leaveType,
        proofImage: proofImage,
      );
      final proofImageBase64 = proofImage != null
          ? base64Encode(await proofImage.readAsBytes())
          : null;
      final submittedEntries = <LeaveHistoryEntry>[];

      var submittedCount = 0;
      var cursor = firstDate;

      while (!cursor.isAfter(lastDate)) {
        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'date': _formatDate(cursor),
                'alasan_izin': leaveReason,
              }),
            )
            .timeout(_requestTimeout);

        final body = _tryDecode(response.body);
        if (response.statusCode != 200 && response.statusCode != 201) {
          final fallbackMessage = submittedCount > 0
              ? 'Sebagian izin sudah terkirim sebelum proses gagal.'
              : 'Gagal mengajukan izin.';
          return AuthResponse(
            success: false,
            message: _parseMessage(body) ?? fallbackMessage,
          );
        }

        submittedEntries.add(
          _buildLeaveHistoryEntry(
            data: body?['data'],
            fallbackDate: _formatDate(cursor),
            fallbackReason: leaveReason,
            proofImagePath: proofImage?.path,
            proofImageBase64: proofImageBase64,
          ),
        );
        submittedCount += 1;
        cursor = cursor.add(const Duration(days: 1));
      }

      await _cacheLeaveHistoryEntries(submittedEntries);

      final suffix = submittedCount > 1 ? ' untuk $submittedCount hari.' : '.';
      return AuthResponse(
        success: true,
        message: 'Izin berhasil diajukan$suffix',
        token: null,
        user: null,
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

  static Future<AuthResponse> updateLeaveRequest({
    required int id,
    required String previousAttendanceDate,
    required String reason,
    required DateTime attendanceDate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/absen/$id');
      final normalizedDate = _normalizeDate(attendanceDate);
      final response = await http
          .put(
            uri,
            headers: await _headersWithAuth(),
            body: jsonEncode({
              'date': _formatDate(normalizedDate),
              'attendance_date': _formatDate(normalizedDate),
              'status': 'izin',
              'alasan_izin': reason.trim(),
            }),
          )
          .timeout(_requestTimeout);

      final body = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _upsertCachedLeaveHistoryEntry(
          previousAttendanceDate: previousAttendanceDate,
          entry: _buildLeaveHistoryEntry(
            data: body?['data'],
            fallbackDate: _formatDate(normalizedDate),
            fallbackReason: reason.trim(),
          ),
        );
        return AuthResponse(
          success: true,
          message: _parseMessage(body) ?? 'Izin berhasil diperbarui.',
          user: body?['data'] as Map<String, dynamic>?,
        );
      }

      return AuthResponse(
        success: false,
        message: _parseMessage(body) ?? 'Gagal memperbarui izin.',
      );
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Permintaan edit izin terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server saat edit izin.',
      );
    }
  }

  static Future<AuthResponse> deleteLeaveRequest({
    required int id,
    required String attendanceDate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/absen/$id');
      final response = await http
          .delete(uri, headers: await _headersWithAuth())
          .timeout(_requestTimeout);

      final body = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _removeCachedLeaveHistoryEntry(
          attendanceDate: attendanceDate,
          id: id,
        );
        return AuthResponse(
          success: true,
          message: _parseMessage(body) ?? 'Izin berhasil dihapus.',
          user: body?['data'] as Map<String, dynamic>?,
        );
      }

      return AuthResponse(
        success: false,
        message: _parseMessage(body) ?? 'Gagal menghapus izin.',
      );
    } on TimeoutException {
      return const AuthResponse(
        success: false,
        message: 'Permintaan hapus izin terlalu lama. Coba lagi.',
      );
    } catch (_) {
      return const AuthResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server saat hapus izin.',
      );
    }
  }

  static Future<void> _cacheLeaveHistoryEntries(
    List<LeaveHistoryEntry> submittedEntries,
  ) async {
    final existingList = await AuthLocalStorage.getLeaveHistoryEntries();
    final merged = existingList.map((entry) => entry.toJson()).toList();

    for (final entry in submittedEntries) {
      final date = entry.attendanceDate;
      merged.removeWhere(
        (item) =>
            _readInt(item['id']) == entry.id ||
            item['attendance_date']?.toString() == date &&
                item['status']?.toString() == 'izin',
      );
      merged.add(entry.toJson());
    }

    await AuthLocalStorage.saveLeaveHistoryEntries(
      merged.map(LeaveHistoryEntry.fromJson).toList(),
    );
  }

  static Future<void> _upsertCachedLeaveHistoryEntry({
    required String previousAttendanceDate,
    required LeaveHistoryEntry entry,
  }) async {
    final existingList = await AuthLocalStorage.getLeaveHistoryEntries();
    final merged = existingList
        .where(
          (item) =>
              item.id != entry.id &&
              item.attendanceDate != previousAttendanceDate,
        )
        .toList();
    merged.add(entry);
    await AuthLocalStorage.saveLeaveHistoryEntries(merged);
  }

  static Future<void> _removeCachedLeaveHistoryEntry({
    required String attendanceDate,
    int? id,
  }) async {
    final existingList = await AuthLocalStorage.getLeaveHistoryEntries();
    final filtered = existingList.where((entry) {
      if (id != null && entry.id == id) {
        return false;
      }
      return !(entry.attendanceDate == attendanceDate &&
          entry.status == 'izin');
    }).toList();
    await AuthLocalStorage.saveLeaveHistoryEntries(filtered);
  }

  static Future<List<Map<String, dynamic>>>
  getCachedLeaveHistoryEntries() async {
    final entries = await AuthLocalStorage.getLeaveHistoryEntries();
    return entries.map((entry) => entry.toJson()).toList();
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

  static String _fallbackResponseMessage(
    http.Response response, {
    required String defaultMessage,
  }) {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      return defaultMessage;
    }

    final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return defaultMessage;
    }

    return '${response.statusCode}: $compact';
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

  static String? _extractProfilePhotoUrl(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final directPhoto = data['profile_photo']?.toString().trim();
    if (directPhoto != null &&
        directPhoto.isNotEmpty &&
        directPhoto.toLowerCase() != 'null') {
      return directPhoto;
    }

    final user = data['user'];
    if (user is Map<String, dynamic>) {
      final nestedPhoto = user['profile_photo']?.toString().trim();
      if (nestedPhoto != null &&
          nestedPhoto.isNotEmpty &&
          nestedPhoto.toLowerCase() != 'null') {
        return nestedPhoto;
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
      final path = _normalizeMediaPath(normalized);
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
            path: _normalizeMediaPath(uri.path),
          )
          .toString();
    }

    return normalized;
  }

  static String _normalizeMediaPath(String rawPath) {
    var path = rawPath.trim();
    if (path.isEmpty) {
      return '/';
    }

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    if (path.startsWith('/profile_photo/')) {
      return '/public$path';
    }

    return path;
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _composeLeaveReason({
    required String reason,
    String? leaveType,
    File? proofImage,
  }) {
    final segments = <String>[];
    final normalizedType = leaveType?.trim();
    if (normalizedType != null && normalizedType.isNotEmpty) {
      segments.add(normalizedType);
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isNotEmpty) {
      segments.add(normalizedReason);
    }

    if (proofImage != null) {
      final fileName = proofImage.path.split(RegExp(r'[\\/]')).last.trim();
      if (fileName.isNotEmpty) {
        segments.add('Lampiran: $fileName');
      }
    }

    return segments.join(' | ');
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static LeaveHistoryEntry _buildLeaveHistoryEntry({
    dynamic data,
    required String fallbackDate,
    required String fallbackReason,
    String? proofImagePath,
    String? proofImageBase64,
  }) {
    final item = data is Map<String, dynamic> ? data : <String, dynamic>{};
    return LeaveHistoryEntry(
      id: _readInt(item['id']),
      attendanceDate:
          item['attendance_date']?.toString().trim().isNotEmpty == true
          ? item['attendance_date'].toString().trim()
          : fallbackDate,
      status: item['status']?.toString().trim().isNotEmpty == true
          ? item['status'].toString().trim()
          : 'izin',
      reason: item['alasan_izin']?.toString().trim().isNotEmpty == true
          ? item['alasan_izin'].toString().trim()
          : fallbackReason,
      proofImagePath: proofImagePath,
      proofImageBase64: proofImageBase64,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
