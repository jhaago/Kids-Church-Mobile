class Volunteer {
  const Volunteer({
    required this.volunteerId,
    required this.name,
    required this.email,
    required this.role,
  });

  final String volunteerId;
  final String name;
  final String email;
  final String role;

  factory Volunteer.fromJson(Map<String, dynamic> json) => Volunteer(
        volunteerId: json['volunteerId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
      );
}

class ServiceSession {
  const ServiceSession({
    required this.sessionId,
    required this.date,
    required this.slot,
    required this.track,
    required this.name,
    required this.isActive,
    required this.label,
  });

  final String sessionId;
  final String date;
  final String slot;
  final String track;
  final String name;
  final bool isActive;
  final String label;

  factory ServiceSession.fromJson(Map<String, dynamic> json) => ServiceSession(
        sessionId: json['sessionId']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        slot: json['slot']?.toString() ?? '',
        track: json['track']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        isActive: json['isActive'] == true,
        label: json['label']?.toString() ?? '',
      );
}

class ChildSummary {
  const ChildSummary({
    required this.childId,
    required this.firstName,
    required this.surname,
    required this.fullName,
    required this.age,
    required this.photoUrl,
    required this.hasMedicalInfo,
    required this.hasOtherInfo,
  });

  final String childId;
  final String firstName;
  final String surname;
  final String fullName;
  final String age;
  final String photoUrl;
  final bool hasMedicalInfo;
  final bool hasOtherInfo;

  factory ChildSummary.fromJson(Map<String, dynamic> json) => ChildSummary(
        childId: json['childId']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        surname: json['surname']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        age: json['age']?.toString() ?? '',
        photoUrl: json['photoUrl']?.toString() ?? '',
        hasMedicalInfo: json['hasMedicalInfo'] == true,
        hasOtherInfo: json['hasOtherInfo'] == true,
      );
}

class GuardianContact {
  const GuardianContact({required this.name, required this.phone});

  final String name;
  final String phone;

  factory GuardianContact.fromJson(Map<String, dynamic>? json) => GuardianContact(
        name: json?['name']?.toString() ?? '',
        phone: json?['phone']?.toString() ?? '',
      );
}

class ChildDetails {
  const ChildDetails({
    required this.childId,
    required this.fullName,
    required this.age,
    required this.medicalInfo,
    required this.otherInfo,
    required this.parentA,
    required this.parentB,
    required this.additionalGuardians,
  });

  final String childId;
  final String fullName;
  final String age;
  final String medicalInfo;
  final String otherInfo;
  final GuardianContact parentA;
  final GuardianContact parentB;
  final List<GuardianContact> additionalGuardians;

  factory ChildDetails.fromJson(Map<String, dynamic> json) => ChildDetails(
        childId: json['childId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        age: json['age']?.toString() ?? '',
        medicalInfo: json['medicalInfo']?.toString() ?? '',
        otherInfo: json['otherInfo']?.toString() ?? '',
        parentA: GuardianContact.fromJson(_mapOrNull(json['parentA'])),
        parentB: GuardianContact.fromJson(_mapOrNull(json['parentB'])),
        additionalGuardians: (json['additionalGuardians'] as List<dynamic>? ?? const [])
            .map((item) => GuardianContact.fromJson(_mapOrNull(item)))
            .toList(growable: false),
      );
}

class AttendanceBootstrap {
  const AttendanceBootstrap({
    required this.children,
    required this.presentByChildId,
    required this.nightNoteByChildId,
    required this.pendingPickupByChildId,
  });

  final List<ChildSummary> children;
  final Map<String, bool> presentByChildId;
  final Map<String, String> nightNoteByChildId;
  final Map<String, bool> pendingPickupByChildId;

  factory AttendanceBootstrap.fromJson(Map<String, dynamic> json) => AttendanceBootstrap(
        children: (json['children'] as List<dynamic>? ?? const [])
            .map((item) => ChildSummary.fromJson(_map(item)))
            .toList(growable: false),
        presentByChildId: _boolMap(json['presentByChildId']),
        nightNoteByChildId: _stringMap(json['nightNoteByChildId']),
        pendingPickupByChildId: _boolMap(json['pendingPickupByChildId']),
      );
}

class PendingAttendanceWrite {
  const PendingAttendanceWrite({
    required this.requestId,
    required this.actorId,
    required this.sessionId,
    required this.date,
    required this.childId,
    required this.present,
    required this.createdAt,
  });

  final String requestId;
  final String actorId;
  final String sessionId;
  final String date;
  final String childId;
  final bool present;
  final DateTime createdAt;

  String get logicalKey => '$actorId|$date|$sessionId|$childId';

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'actorId': actorId,
        'sessionId': sessionId,
        'date': date,
        'childId': childId,
        'present': present,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory PendingAttendanceWrite.fromJson(Map<String, dynamic> json) => PendingAttendanceWrite(
        requestId: json['requestId']?.toString() ?? '',
        actorId: json['actorId']?.toString() ?? '',
        sessionId: json['sessionId']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        childId: json['childId']?.toString() ?? '',
        present: json['present'] == true,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
      );
}

class AttendanceQueue {
  static List<PendingAttendanceWrite> upsert(
    List<PendingAttendanceWrite> current,
    PendingAttendanceWrite next,
  ) {
    return [
      for (final item in current)
        if (item.logicalKey != next.logicalKey) item,
      next,
    ];
  }

  static List<PendingAttendanceWrite> removeRequest(
    List<PendingAttendanceWrite> current,
    String requestId,
  ) =>
      current.where((item) => item.requestId != requestId).toList(growable: false);
}

Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value as Map? ?? const {});
Map<String, dynamic>? _mapOrNull(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

Map<String, bool> _boolMap(Object? value) {
  if (value is! Map) return {};
  return value.map((key, item) => MapEntry(key.toString(), item == true));
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return {};
  return value.map((key, item) => MapEntry(key.toString(), item?.toString() ?? ''));
}

