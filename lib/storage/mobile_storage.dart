import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kids_church_mobile/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobileStorage {
  MobileStorage({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _apiUrlKey = 'kc_api_url';
  static const _sessionIdKey = 'kc_selected_session_id';
  static const _tokenKey = 'kc_auth_token';
  static const _queueKey = 'kc_attendance_queue_v1';

  final FlutterSecureStorage _secure;

  Future<String> apiUrl() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_apiUrlKey) ?? const String.fromEnvironment('KC_API_URL');
  }

  Future<void> saveApiUrl(String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await preferences.remove(_apiUrlKey);
    } else {
      await preferences.setString(_apiUrlKey, value);
    }
  }

  Future<String> selectedSessionId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_sessionIdKey) ?? '';
  }

  Future<void> saveSelectedSessionId(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionIdKey, value);
  }

  Future<String> token() async => await _secure.read(key: _tokenKey) ?? '';

  Future<void> saveToken(String value) async {
    if (value.isEmpty) {
      await _secure.delete(key: _tokenKey);
    } else {
      await _secure.write(key: _tokenKey, value: value);
    }
  }

  Future<List<PendingAttendanceWrite>> pendingWrites() async {
    final raw = await _secure.read(key: _queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => PendingAttendanceWrite.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((item) => item.requestId.isNotEmpty && item.childId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingWrites(List<PendingAttendanceWrite> writes) async {
    if (writes.isEmpty) {
      await _secure.delete(key: _queueKey);
      return;
    }
    await _secure.write(key: _queueKey, value: jsonEncode(writes.map((item) => item.toJson()).toList()));
  }
}
