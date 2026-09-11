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
      response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'version': 'v1',
              'operation': operation,
              'requestId': id,
              if (token.isNotEmpty) 'token': token,
              'data': data,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw ApiException('NETWORK_TIMEOUT', 'The server took too long to respond.', requestId: id);
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

  String _requestId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'mobile-${DateTime.now().toUtc().microsecondsSinceEpoch}-$random';
  }

  void close() => _client.close();
}

Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value as Map? ?? const {});
