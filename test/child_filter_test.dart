import 'package:flutter_test/flutter_test.dart';
import 'package:kids_church_mobile/models/models.dart';

void main() {
  ChildSummary child({String church = '', String status = ''}) => ChildSummary.fromJson({
        'childId': 'K-1',
        'firstName': 'Test',
        'surname': 'Child',
        'fullName': 'Test Child',
        'church': church,
        'status': status,
      });

  test('default attendance list includes Beechboro and legacy blank church records', () {
    expect(isBeechboroChildSummary(child(church: 'Beechboro')), isTrue);
    expect(isBeechboroChildSummary(child()), isTrue);
  });

  test('default attendance list excludes visitors and other churches', () {
    expect(isBeechboroChildSummary(child(church: 'Geraldton')), isFalse);
    expect(isBeechboroChildSummary(child(church: 'Beechboro', status: 'Visitor')), isFalse);
  });
}
