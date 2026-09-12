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
  static const _childDetailsPrefix = 'kc_child_details_v1_';
  static const _childDetailVersionsKey = 'kc_child_detail_versions_v1';
  static const _childDetailsSyncedAtKey = 'kc_child_details_synced_at_v1';

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

  Future<Map<String, ChildDetails>> childDetails() async {
    final stored = await _secure.readAll();
    final details = <String, ChildDetails>{};
    for (final entry in stored.entries) {
      if (!entry.key.startsWith(_childDetailsPrefix) || entry.value.isEmpty) {
        continue;
      }
      try {
        final parsed = jsonDecode(entry.value);
        if (parsed is! Map) {
          continue;
        }
        final child = ChildDetails.fromJson(Map<String, dynamic>.from(parsed));
        if (child.childId.isNotEmpty) {
          details[child.childId] = child;
        }
      } catch (_) {
        // Ignore a corrupt record; a later sync will replace it.
      }
    }
    return details;
  }

  Future<Map<String, String>> childDetailVersions() async {
    final raw = await _secure.read(key: _childDetailVersionsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return {};
      return Map<String, dynamic>.from(parsed).map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      )..removeWhere((key, value) => key.isEmpty || value.isEmpty);
    } catch (_) {
      return {};
    }
  }

  Future<DateTime?> childDetailsSyncedAt() async {
    final preferences = await SharedPreferences.getInstance();
    return DateTime.tryParse(preferences.getString(_childDetailsSyncedAtKey) ?? '');
  }

  Future<void> saveChildDetails(List<ChildDetails> children, DateTime syncedAt) async {
    final stored = await _secure.readAll();
    final wantedKeys = <String>{};

    for (final child in children) {
      if (child.childId.isEmpty) {
        continue;
      }
      final key = '$_childDetailsPrefix${child.childId}';
      wantedKeys.add(key);
      await _secure.write(key: key, value: jsonEncode(_childDetailsToJson(child)));
    }

    for (final key in stored.keys) {
      if (key.startsWith(_childDetailsPrefix) && !wantedKeys.contains(key)) {
        await _secure.delete(key: key);
      }
    }

    await _saveChildDetailsSyncedAt(syncedAt);
  }

  Future<void> saveChildDetailVersions(Map<String, String> versions) async {
    if (versions.isEmpty) {
      await _secure.delete(key: _childDetailVersionsKey);
      return;
    }
    await _secure.write(key: _childDetailVersionsKey, value: jsonEncode(versions));
  }

  Future<void> applyChildDetailsDelta({
    required List<ChildDetails> changed,
    required List<String> removed,
    required Map<String, String> versions,
    required DateTime syncedAt,
  }) async {
    for (final child in changed) {
      if (child.childId.isEmpty) continue;
      await _secure.write(
        key: '$_childDetailsPrefix${child.childId}',
        value: jsonEncode(_childDetailsToJson(child)),
      );
    }

    for (final childId in removed) {
      if (childId.isEmpty) continue;
      await _secure.delete(key: '$_childDetailsPrefix$childId');
    }

    await saveChildDetailVersions(versions);
    await _saveChildDetailsSyncedAt(syncedAt);
  }

  Future<void> _saveChildDetailsSyncedAt(DateTime syncedAt) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_childDetailsSyncedAtKey, syncedAt.toUtc().toIso8601String());
  }

  Future<void> clearChildDetails() async {
    final stored = await _secure.readAll();
    for (final key in stored.keys) {
      if (key.startsWith(_childDetailsPrefix)) {
        await _secure.delete(key: key);
      }
    }
    await _secure.delete(key: _childDetailVersionsKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_childDetailsSyncedAtKey);
  }
}

Map<String, dynamic> _childDetailsToJson(ChildDetails child) => {
      'childId': child.childId,
      'fullName': child.fullName,
      'age': child.age,
      'medicalInfo': child.medicalInfo,
      'otherInfo': child.otherInfo,
      'parentA': _guardianToJson(child.parentA),
      'parentB': _guardianToJson(child.parentB),
      'additionalGuardians': child.additionalGuardians.map(_guardianToJson).toList(),
    };

Map<String, dynamic> _guardianToJson(GuardianContact guardian) => {
      'name': guardian.name,
      'phone': guardian.phone,
    };
