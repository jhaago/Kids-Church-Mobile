import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kids_church_mobile/api/kids_church_api.dart';

void main() {
  test('child detail delta sync sends versions and parses changes', () async {
    late Map<String, dynamic> requestBody;
    final api = KidsChurchApi(
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'version': 'v1',
            'requestId': requestBody['requestId'],
            'data': {
              'changed': [
                {
                  'childId': 'KID-1',
                  'fullName': 'Example Record',
                  'age': 8,
                  'medicalInfo': '',
                  'otherInfo': '',
                  'parentA': {'name': '', 'phone': ''},
                  'parentB': {'name': '', 'phone': ''},
                  'additionalGuardians': <Object>[],
                  'version': 'version-new',
                },
              ],
              'removed': ['KID-2'],
              'syncedAt': '2026-09-12T03:30:00.000Z',
            },
          }),
          200,
        );
      }),
    )..configure('https://example.test/exec');

    final result = await api.syncChildDetails(
      'secure-token',
      {'KID-1': 'version-old', 'KID-2': 'version-existing'},
    );

    expect(requestBody['operation'], 'children.sync');
    expect(requestBody['data']['knownVersions']['KID-1'], 'version-old');
    expect(result.fullSnapshot, false);
    expect(result.changed.single.childId, 'KID-1');
    expect(result.changedVersions['KID-1'], 'version-new');
    expect(result.removed, ['KID-2']);
    api.close();
  });
}
