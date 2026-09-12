import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kids_church_mobile/models/models.dart';

class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.requestId = ''});

  final String code;
  final String message;
  final String requestId;

  bool get isAuthentication => code == 'UNAUTHORIZED' || code == 'LOGIN_FAILED';
  bool get isTerminalSession => const {
        'SESSION_CLOSED',
        'SESSION_NOT_FOUND',
        'SESSION_DATE_MISMATCH',
      }.contains(code);

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({required this.token, required this.volunteer});

  final String token;
  final Volunteer volunteer;
}

class ChildDetailsSyncResult {
  const ChildDetailsSyncResult({
    required this.changed,
    required this.changedVersions,
    required this.removed,
    required this.syncedAt,
    required this.fullSnapshot,
  });

  final List<ChildDetails> changed;
  final Map<String, String> changedVersions;
  final List<String> removed;
  final DateTime? syncedAt;
  final bool fullSnapshot;
}

class KidsChurchApi {
  KidsChurchApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String _baseUrl = '';

  String get baseUrl => _baseUrl;

  void configure(String value) {
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    final local = uri?.host == 'localhost' || uri?.host == '127.0.0.1';
    if (uri == null || !uri.hasAuthority || (uri.scheme != 'https' && !(local && uri.scheme == 'http'))) {
      throw const ApiException('INVALID_URL', 'Enter a valid HTTPS Apps Script deployment URL.');
    }
    _baseUrl = normalized;
  }

  void clearConfiguration() => _baseUrl = '';

  Future<void> health() async {
    await _call('api.health');
  }

  Future<LoginResult> login(String email, String password) async {
    final data = await _call('auth.login', data: {'email': email.trim(), 'password': password});
    return LoginResult(
      token: data['token']?.toString() ?? '',
      volunteer: Volunteer.fromJson(_map(data['volunteer'])),
    );
  }

  Future<Volunteer> me(String token) async {
    final data = await _call('auth.me', token: token);
    return Volunteer.fromJson(_map(data['volunteer']));
  }

  Future<void> logout(String token) async {
    await _call('auth.logout', token: token);
  }

  Future<List<ServiceSession>> listSessions(String token) async {
    final data = await _call('sessions.list', token: token);
    return (data['sessions'] as List<dynamic>? ?? const [])
        .map((item) => ServiceSession.fromJson(_map(item)))
        .toList(growable: false);
  }

  Future<AttendanceBootstrap> bootstrapAttendance(
    String token,
    ServiceSession session,
  ) async {
    final data = await _call(
      'attendance.bootstrap',
      token: token,
      data: {'date': session.date, 'sessionId': session.sessionId},
    );
    return AttendanceBootstrap.fromJson(data);
  }

  Future<void> setAttendance(String token, PendingAttendanceWrite write) async {
    await _call(
      'attendance.set',
      token: token,
      requestId: write.requestId,
      data: {
        'date': write.date,
        'sessionId': write.sessionId,
        'changes': [
          {'childId': write.childId, 'present': write.present},
        ],
      },
    );
  }

  Future<ChildDetails> childDetails(String token, String childId) async {
    final data = await _call('children.get', token: token, data: {'childId': childId});
    return ChildDetails.fromJson(data);
  }

  Future<ChildDetailsSyncResult> syncChildDetails(
    String token,
    Map<String, String> knownVersions,
  ) async {
    final data = await _call(
      'children.sync',
      token: token,
      data: {'knownVersions': knownVersions},
    );

    final deltaItems = data['changed'] as List<dynamic>?;
    final legacyItems = data['children'] as List<dynamic>?;
    final rawItems = deltaItems ?? legacyItems ?? const [];
    final changed = <ChildDetails>[];
    final changedVersions = <String, String>{};

    for (final item in rawItems) {
      final json = _map(item);
      final child = ChildDetails.fromJson(json);
      if (child.childId.isEmpty) continue;
      changed.add(child);
      final version = json['version']?.toString() ?? '';
      if (version.isNotEmpty) changedVersions[child.childId] = version;
    }

    return ChildDetailsSyncResult(
      changed: changed,
      changedVersions: changedVersions,
      removed: (data['removed'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      syncedAt: DateTime.tryParse(data['syncedAt']?.toString() ?? ''),
      fullSnapshot: deltaItems == null && legacyItems != null,
    );
  }

  Future<RosterBundle> myRoster(String token) async =>
      RosterBundle.fromJson(await _call('roster.mine', token: token));

  Future<void> respondToRoster(String token, String rosterId, String decision, {String notes = ''}) async {
    await _call('roster.respond', token: token, data: {
      'rosterId': rosterId,
      'decision': decision,
      'notes': notes,
    });
  }

  Future<List<ScheduleRole>> schedule(String token, ServiceSession session) async {
    final data = await _call('schedule.get', token: token, data: {
      'date': session.date,
      'sessionId': session.sessionId,
    });
    return (data['roles'] as List<dynamic>? ?? const [])
        .map((item) => ScheduleRole.fromJson(_map(item)))
        .toList(growable: false);
  }

  Future<ResourcesBundle> resources(String token) async =>
      ResourcesBundle.fromJson(await _call('resources.list', token: token));

  Future<VolunteerProfile> profile(String token) async =>
      VolunteerProfile.fromJson(await _call('profile.get', token: token));

  Future<Map<String, dynamic>> _call(
    String operation, {
    String token = '',
    String? requestId,
    Map<String, dynamic> data = const {},
  }) async {
    if (_baseUrl.isEmpty) {
      throw const ApiException('NOT_CONFIGURED', 'The server URL has not been configured.');
    }
    final id = requestId ?? _requestId();
    late http.Response response;
    try {
      response = await _postFollowingAppsScriptRedirect(
        Uri.parse(_baseUrl),
        jsonEncode({
          'version': 'v1',
          'operation': operation,
          'requestId': id,
          if (token.isNotEmpty) 'token': token,
          'data': data,
        }),
        id,
      ).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw ApiException('NETWORK_TIMEOUT', 'The server took too long to respond.', requestId: id);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('NETWORK_ERROR', 'Could not reach the Kids Church server.', requestId: id);
    }

    Map<String, dynamic> envelope;
    try {
      envelope = _map(jsonDecode(response.body));
    } catch (_) {
      throw ApiException('INVALID_RESPONSE', 'The server returned an unreadable response.', requestId: id);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('HTTP_${response.statusCode}', 'The server request failed.', requestId: id);
    }
    if (envelope['ok'] != true) {
      final error = _map(envelope['error']);
      throw ApiException(
        error['code']?.toString() ?? 'REQUEST_FAILED',
        error['message']?.toString() ?? 'The request could not be completed.',
        requestId: envelope['requestId']?.toString() ?? id,
      );
    }
    return _map(envelope['data']);
  }

  Future<http.Response> _postFollowingAppsScriptRedirect(
    Uri uri,
    String body,
    String requestId,
  ) async {
    var currentUri = uri;
    var method = 'POST';

    for (var redirectCount = 0; redirectCount <= 3; redirectCount++) {
      final request = http.Request(method, currentUri)..followRedirects = false;
      if (method == 'POST') {
        request.headers['Content-Type'] = 'application/json';
        request.body = body;
      }

      final response = await http.Response.fromStream(await _client.send(request));
      if (!_isRedirect(response.statusCode)) return response;

      final location = response.headers['location'];
      if (location == null || location.isEmpty || redirectCount == 3) {
        throw ApiException(
          'INVALID_REDIRECT',
          'The server returned an invalid redirect.',
          requestId: requestId,
        );
      }

      final nextUri = currentUri.resolve(location);
      if (!_isTrustedGoogleRedirect(nextUri)) {
        throw ApiException(
          'INVALID_REDIRECT',
          'The server redirected to an unexpected address.',
          requestId: requestId,
        );
      }

      // Apps Script ContentService executes the POST first, then serves its
      // result from a one-time googleusercontent URL using GET. Never resend
      // the token-bearing POST body to the redirected host.
      currentUri = nextUri;
      method = 'GET';
    }

    throw ApiException(
      'INVALID_REDIRECT',
      'The server returned too many redirects.',
      requestId: requestId,
    );
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 || statusCode == 302 || statusCode == 303 || statusCode == 307 || statusCode == 308;

  bool _isTrustedGoogleRedirect(Uri uri) {
    final host = uri.host.toLowerCase();
    return uri.scheme == 'https' &&
        (host == 'script.googleusercontent.com' || host.endsWith('.googleusercontent.com'));
  }

  String _requestId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'mobile-${DateTime.now().toUtc().microsecondsSinceEpoch}-$random';
  }

  void close() => _client.close();
}

Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value as Map? ?? const {});
