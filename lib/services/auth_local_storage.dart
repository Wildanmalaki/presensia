import 'dart:convert';

import 'package:presensia/models/leave_history_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalStorage {
  static const String tokenKey = 'auth_token';
  static const String userNameKey = 'user_name';
  static const String profilePhotoKey = 'profile_photo_url';
  static const String leaveHistoryCacheKey = 'leave_history_cache';
  static const String leaveHistoryCacheByTokenKey = 'leave_history_cache_by_token';

  static Future<bool> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(tokenKey, token);
  }

  static Future<bool> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(userNameKey, name);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userNameKey);
  }

  static Future<bool> saveProfilePhotoUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(profilePhotoKey, url);
  }

  static Future<String?> getProfilePhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(profilePhotoKey);
  }

  static Future<void> saveLeaveHistoryEntries(
    List<LeaveHistoryEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    if (token == null || token.trim().isEmpty) {
      return;
    }

    final cacheMap = _readLeaveHistoryCacheMap(
      prefs.getString(leaveHistoryCacheByTokenKey),
    );
    cacheMap[token] = entries.map((entry) => entry.toJson()).toList();

    await prefs.setString(
      leaveHistoryCacheByTokenKey,
      jsonEncode(cacheMap),
    );
    await prefs.remove(leaveHistoryCacheKey);
  }

  static Future<List<LeaveHistoryEntry>> getLeaveHistoryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    if (token == null || token.trim().isEmpty) {
      return <LeaveHistoryEntry>[];
    }

    final cacheMap = _readLeaveHistoryCacheMap(
      prefs.getString(leaveHistoryCacheByTokenKey),
    );
    final rawEntries = cacheMap[token];
    if (rawEntries is! List) {
      return <LeaveHistoryEntry>[];
    }

    return rawEntries
        .whereType<Map<String, dynamic>>()
        .map(LeaveHistoryEntry.fromJson)
        .toList();
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    if (token != null && token.trim().isNotEmpty) {
      final cacheMap = _readLeaveHistoryCacheMap(
        prefs.getString(leaveHistoryCacheByTokenKey),
      );
      cacheMap.remove(token);
      await prefs.setString(
        leaveHistoryCacheByTokenKey,
        jsonEncode(cacheMap),
      );
    }
    await prefs.remove(tokenKey);
    await prefs.remove(userNameKey);
    await prefs.remove(profilePhotoKey);
    await prefs.remove(leaveHistoryCacheKey);
  }

  static Map<String, dynamic> _readLeaveHistoryCacheMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // ignore invalid cache
    }

    return <String, dynamic>{};
  }
}
