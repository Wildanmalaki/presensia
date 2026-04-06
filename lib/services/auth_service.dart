import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TrainingOption {
  const TrainingOption({required this.id, required this.title});

  final int id;
  final String title;

  factory TrainingOption.fromJson(Map<String, dynamic> json) {
    return TrainingOption(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
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
    final trainings =
        (json['trainings'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(TrainingOption.fromJson)
            .toList();

    return BatchOption(
      id: json['id'] as int,
      label: 'Batch ${(json['batch_ke'] ?? '').toString()}',
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

  static const String _tokenKey = 'auth_token';

  static Future<bool> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
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
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      final auth = _fromResponse(response);
      if (auth.success && auth.token != null) {
        await saveToken(auth.token!);
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

      return data
          .whereType<Map<String, dynamic>>()
          .map(BatchOption.fromJson)
          .toList();
    } on TimeoutException {
      throw Exception('Memuat batch terlalu lama. Coba lagi.');
    } catch (_) {
      throw Exception('Tidak dapat memuat data batch. Coba lagi.');
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
}
