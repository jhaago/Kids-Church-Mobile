import 'package:flutter_test/flutter_test.dart';
import 'package:kids_church_mobile/models/models.dart';

PendingAttendanceWrite write({
  required String requestId,
  required String childId,
  required bool present,
  String actorId = 'VOL-1',
  String sessionId = 'SESSION-1',
  String date = '2026-09-13',
}) =>
    PendingAttendanceWrite(
      requestId: requestId,
      actorId: actorId,
      sessionId: sessionId,
      date: date,
      childId: childId,
      present: present,
      createdAt: DateTime.utc(2026, 9, 11),
    );

void main() {
  test('double taps retain only the latest final state', () {
    final first = AttendanceQueue.upsert([], write(requestId: 'one', childId: 'KID-1', present: true));
    final second = AttendanceQueue.upsert(first, write(requestId: 'two', childId: 'KID-1', present: false));

    expect(second, hasLength(1));
    expect(second.single.requestId, 'two');
    expect(second.single.present, isFalse);
  });

  test('same child in different sessions remains separate', () {
    final first = AttendanceQueue.upsert([], write(requestId: 'one', childId: 'KID-1', present: true));
    final second = AttendanceQueue.upsert(
      first,
      write(requestId: 'two', childId: 'KID-1', present: false, sessionId: 'SESSION-2'),
    );

    expect(second, hasLength(2));
  });

  test('a completed request cannot delete a newer queued action', () {
    final queue = [write(requestId: 'new', childId: 'KID-1', present: false)];
    final afterOldResponse = AttendanceQueue.removeRequest(queue, 'old');

    expect(afterOldResponse, hasLength(1));
    expect(afterOldResponse.single.requestId, 'new');
  });
}

