import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kids_church_mobile/api/kids_church_api.dart';

void main() {
  test('bulk child detail sync uses one authenticated children.sync request', () async {
    var requestCount = 0;
    late Map<String, dynamic> requestBody;
    final api = KidsChurchApi(
      client: MockClient((request) async {
        requestCount++;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'version': 'v1',
            'requestId': requestBody['requestId'],
            'data': {
              'children': [
                {
                  'childId': 'KID-1',
                  'fullName': 'Alex Example',
                  'age': 8,
                  'medicalInfo': 'Asthma',
                  'otherInfo': 'Important note',
                  'parentA': {'name': 'Parent One', 'phone': '0400000000'},
                  'parentB': {'name': '', 'phone': ''},
                  'additionalGuardians': <Object>[],
                },
              ],
            },
          }),
          200,
        );
      }),
    )..configure('https://example.test/exec');

    final children = await api.syncChildDetails('secure-token');

    expect(requestCount, 1);
    expect(requestBody['operation'], 'children.sync');
    expect(requestBody['token'], 'secure-token');
    expect(children, hasLength(1));
    expect(children.single.childId, 'KID-1');
    expect(children.single.medicalInfo, 'Asthma');
    expect(children.single.parentA.name, 'Parent One');
    api.close();
  });
}
