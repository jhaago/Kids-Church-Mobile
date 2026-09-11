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
    required this.church,
    required this.status,
    required this.photoUrl,
    required this.hasMedicalInfo,
    required this.hasOtherInfo,
  });

  final String childId;
  final String firstName;
  final String surname;
  final String fullName;
  final String age;
  final String church;
  final String status;
  final String photoUrl;
  final bool hasMedicalInfo;
  final bool hasOtherInfo;

  factory ChildSummary.fromJson(Map<String, dynamic> json) => ChildSummary(
        childId: json['childId']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        surname: json['surname']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        age: json['age']?.toString() ?? '',
        church: json['church']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
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

class RosterItem {
  const RosterItem({required this.rosterId, required this.date, required this.role, required this.status, required this.notes});
  final String rosterId;
  final String date;
  final String role;
  final String status;
  final String notes;

  factory RosterItem.fromJson(Map<String, dynamic> json) => RosterItem(
        rosterId: json['rosterId']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
      );
}

class Blockout {
  const Blockout({required this.blockoutId, required this.startDate, required this.endDate, required this.reason});
  final String blockoutId;
  final String startDate;
  final String endDate;
  final String reason;

  factory Blockout.fromJson(Map<String, dynamic> json) => Blockout(
        blockoutId: json['blockoutId']?.toString() ?? '',
        startDate: json['startDate']?.toString() ?? '',
        endDate: json['endDate']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
      );
}

class RosterBundle {
  const RosterBundle({required this.roster, required this.blockouts});
  final List<RosterItem> roster;
  final List<Blockout> blockouts;

  factory RosterBundle.fromJson(Map<String, dynamic> json) => RosterBundle(
        roster: (json['roster'] as List<dynamic>? ?? const [])
            .map((item) => RosterItem.fromJson(_map(item)))
            .toList(growable: false),
        blockouts: (json['blockouts'] as List<dynamic>? ?? const [])
            .map((item) => Blockout.fromJson(_map(item)))
            .toList(growable: false),
      );
}

class ScheduleVolunteer {
  const ScheduleVolunteer({required this.name, required this.status, required this.notes});
  final String name;
  final String status;
  final String notes;
  factory ScheduleVolunteer.fromJson(Map<String, dynamic> json) => ScheduleVolunteer(
        name: json['volunteerName']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
      );
}

class ScheduleItem {
  const ScheduleItem({required this.time, required this.title, required this.series, required this.notes, required this.resourceName, required this.resourceLink});
  final String time;
  final String title;
  final String series;
  final String notes;
  final String resourceName;
  final String resourceLink;
  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        time: json['time']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        series: json['series']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        resourceName: json['resourceName']?.toString() ?? '',
        resourceLink: json['resourceLink']?.toString() ?? '',
      );
}

class ScheduleRole {
  const ScheduleRole({required this.role, required this.volunteers, required this.items});
  final String role;
  final List<ScheduleVolunteer> volunteers;
  final List<ScheduleItem> items;
  factory ScheduleRole.fromJson(Map<String, dynamic> json) => ScheduleRole(
        role: json['role']?.toString() ?? '',
        volunteers: (json['volunteers'] as List<dynamic>? ?? const [])
            .map((item) => ScheduleVolunteer.fromJson(_map(item)))
            .toList(growable: false),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => ScheduleItem.fromJson(_map(item)))
            .toList(growable: false),
      );
}

class ResourceItem {
  const ResourceItem({required this.id, required this.type, required this.name, required this.description, required this.link, required this.image});
  final String id;
  final String type;
  final String name;
  final String description;
  final String link;
  final String image;
  factory ResourceItem.fromJson(Map<String, dynamic> json) => ResourceItem(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        link: json['link']?.toString() ?? '',
        image: json['image']?.toString() ?? '',
      );
}

class ResourcesBundle {
  const ResourcesBundle({required this.topLinks, required this.itemsByType});
  final List<ResourceItem> topLinks;
  final Map<String, List<ResourceItem>> itemsByType;
  List<String> get types => itemsByType.keys.toList()..sort();

  factory ResourcesBundle.fromJson(Map<String, dynamic> json) {
    final groups = <String, List<ResourceItem>>{};
    final raw = json['itemsByType'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        groups[entry.key.toString()] = (entry.value as List<dynamic>? ?? const [])
            .map((item) => ResourceItem.fromJson(_map(item)))
            .toList(growable: false);
      }
    }
    return ResourcesBundle(
      topLinks: (json['topLinks'] as List<dynamic>? ?? const [])
          .map((item) => ResourceItem.fromJson(_map(item)))
          .toList(growable: false),
      itemsByType: groups,
    );
  }
}

class VolunteerProfile {
  const VolunteerProfile({required this.volunteer, required this.photoUrl});
  final Volunteer volunteer;
  final String photoUrl;
  factory VolunteerProfile.fromJson(Map<String, dynamic> json) => VolunteerProfile(
        volunteer: Volunteer.fromJson(_map(json['volunteer'])),
        photoUrl: json['photoUrl']?.toString() ?? '',
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

bool isBeechboroChildSummary(ChildSummary child) {
  final church = child.church.trim().toLowerCase();
  final status = child.status.trim().toLowerCase();
  return (church.isEmpty || church.contains('beechboro')) &&
      (status.isEmpty || !status.contains('visitor'));
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
