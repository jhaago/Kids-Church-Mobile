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

  test('Apps Script POST redirect is followed with a body-free GET', () async {
    final methods = <String>[];
    final api = KidsChurchApi(
      client: MockClient((request) async {
        methods.add(request.method);
        if (methods.length == 1) {
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://script.googleusercontent.com/macros/echo?result=one-time',
            },
          );
        }
        expect(request.url.host, 'script.googleusercontent.com');
        expect(request.body, isEmpty);
        return http.Response(
          jsonEncode({
            'ok': true,
            'version': 'v1',
            'requestId': 'redirect-test',
            'data': {'status': 'ok'},
          }),
          200,
        );
      }),
    )..configure('https://script.google.com/macros/s/test/exec');

    await api.health();

    expect(methods, ['POST', 'GET']);
    api.close();
  });

  test('token-bearing POST is not followed to an untrusted host', () async {
    final api = KidsChurchApi(
      client: MockClient((_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://attacker.example/collect'},
          )),
    )..configure('https://script.google.com/macros/s/test/exec');

    await expectLater(
      api.health(),
      throwsA(isA<ApiException>().having((error) => error.code, 'code', 'INVALID_REDIRECT')),
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
