import 'dart:convert';

import 'package:http/http.dart' as http;

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
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/login');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _fromResponse(response);
  }

  static Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? batch,
    String? jurusan,
    String? jenisKelamin,
  }) async {
    final Map<String, dynamic> body = {
      'name': name,
      'email': email,
      'password': password,
    };

    if (batch?.isNotEmpty == true) {
      body['batch'] = batch;
    }
    if (jurusan?.isNotEmpty == true) {
      body['jurusan'] = jurusan;
    }
    if (jenisKelamin?.isNotEmpty == true) {
      body['jenis_kelamin'] = jenisKelamin;
    }

    final uri = Uri.parse('$baseUrl/api/register');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _fromResponse(response);
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
