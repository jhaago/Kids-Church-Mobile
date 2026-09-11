import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kids_church_mobile/api/kids_church_api.dart';

void main() {
  test('health call sends the versioned request envelope', () async {
    late Map<String, dynamic> requestBody;
    final api = KidsChurchApi(
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'version': 'v1',
            'requestId': requestBody['requestId'],
            'data': {'status': 'ok'},
          }),
          200,
        );
      }),
    )..configure('https://example.test/exec');

    await api.health();

    expect(requestBody['version'], 'v1');
    expect(requestBody['operation'], 'api.health');
    expect(requestBody['token'], isNull);
    api.close();
  });

  test('application errors are surfaced even with HTTP 200', () async {
    final api = KidsChurchApi(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'ok': false,
              'requestId': 'request-1',
              'error': {'code': 'SESSION_CLOSED', 'message': 'The service session is closed.'},
            }),
            200,
          )),
    )..configure('https://example.test/exec');

    await expectLater(
      api.health(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'SESSION_CLOSED')
            .having((error) => error.isTerminalSession, 'terminal session', isTrue),
      ),
    );
    api.close();
  });

  test('plain HTTP production URLs are rejected', () {
    final api = KidsChurchApi();
    expect(
      () => api.configure('http://example.test/exec'),
      throwsA(isA<ApiException>().having((error) => error.code, 'code', 'INVALID_URL')),
    );
    api.close();
  });
}

