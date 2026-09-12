import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kids_church_mobile/api/kids_church_api.dart';
import 'package:kids_church_mobile/models/models.dart';
import 'package:kids_church_mobile/storage/mobile_storage.dart';

enum AppTab { attendance, roster, schedule, kids, resources }

enum ChildSort { firstName, surname }

class AppController extends ChangeNotifier {
  AppController({required KidsChurchApi api, required MobileStorage storage})
      : _api = api,
        _storage = storage;

  final KidsChurchApi _api;
  final MobileStorage _storage;

  bool initializing = true;
  bool busy = false;
  bool syncing = false;
  bool syncingChildDetails = false;
  String apiUrl = '';
  String token = '';
  Volunteer? volunteer;
  List<ServiceSession> sessions = const [];
  ServiceSession? selectedSession;
  List<ChildSummary> children = const [];
  Map<String, ChildDetails> childDetailsById = {};
  Map<String, String> childDetailVersions = {};
  DateTime? childDetailsSyncedAt;
  Map<String, bool> presentByChildId = {};
  Map<String, String> nightNoteByChildId = {};
  Map<String, bool> pendingPickupByChildId = {};
  List<PendingAttendanceWrite> pendingWrites = const [];
  String searchQuery = '';
  String errorMessage = '';
  AppTab selectedTab = AppTab.attendance;
  ChildSort childSort = ChildSort.firstName;
  RosterBundle? roster;
  List<ScheduleRole> scheduleRoles = const [];
  ResourcesBundle? resources;
  VolunteerProfile? profile;
  final Map<AppTab, DateTime> _loadedAt = {};
  final Set<AppTab> _refreshingTabs = {};
  Timer? _childSyncPollTimer;

  static const _attendanceFreshFor = Duration(seconds: 20);
  static const _rosterFreshFor = Duration(minutes: 2);
  static const _scheduleFreshFor = Duration(minutes: 1);
  static const _resourcesFreshFor = Duration(minutes: 5);
  static const _childDetailsFreshFor = Duration(minutes: 5);
  static const _childDetailsPollEvery = Duration(minutes: 5);

  bool get isConfigured => apiUrl.isNotEmpty;
  bool get isAuthenticated => volunteer != null && token.isNotEmpty;
  String get teamsUrl => apiUrl.isEmpty ? '' : '$apiUrl?page=teams';
  String get registerUrl => apiUrl.isEmpty ? '' : '$apiUrl?page=register';

  List<ChildSummary> get visibleChildren {
    final query = searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty ? [...children] : children.where((child) {
      return '${child.fullName} ${child.firstName} ${child.surname}'.toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) {
      final left = childSort == ChildSort.firstName ? a.firstName : a.surname;
      final right = childSort == ChildSort.firstName ? b.firstName : b.surname;
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    return filtered;
  }

  List<ChildSummary> get presentChildren =>
      visibleChildren.where((child) => presentByChildId[child.childId] == true).toList(growable: false);

  List<ChildSummary> get attendanceChildren {
    if (searchQuery.trim().isNotEmpty) return visibleChildren;
    return visibleChildren.where(isBeechboroChild).toList(growable: false);
  }

  List<ChildSummary> get presentVisitors => visibleChildren
      .where((child) => !isBeechboroChild(child) && presentByChildId[child.childId] == true)
      .toList(growable: false);

  List<ChildSummary> visitorCandidates(String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return const [];
    final matches = children.where((child) {
      if (isBeechboroChild(child)) return false;
      return '${child.fullName} ${child.firstName} ${child.surname} ${child.church}'
          .toLowerCase()
          .contains(value);
    }).toList();
    matches.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return matches;
  }

  bool isBeechboroChild(ChildSummary child) {
    return isBeechboroChildSummary(child);
  }

  int get presentCount => presentByChildId.values.where((value) => value).length;

  int get pendingCount {
    final actor = volunteer?.volunteerId ?? '';
    return pendingWrites.where((item) => item.actorId == actor).length;
  }

  bool childHasPending(String childId) {
    final actor = volunteer?.volunteerId ?? '';
    final sessionId = selectedSession?.sessionId ?? '';
    return pendingWrites.any(
      (item) => item.actorId == actor && item.sessionId == sessionId && item.childId == childId,
    );
  }

  Future<void> initialize() async {
    try {
      pendingWrites = await _storage.pendingWrites();
      final storedUrl = await _storage.apiUrl();
      if (storedUrl.isEmpty) return;
      _api.configure(storedUrl);
      apiUrl = storedUrl;

      token = await _storage.token();
      if (token.isEmpty) {
        childDetailsById = {};
        childDetailVersions = {};
        childDetailsSyncedAt = null;
        await _storage.clearChildDetails();
        return;
      }
      volunteer = await _api.me(token);
      childDetailsById = await _storage.childDetails();
      childDetailVersions = await _storage.childDetailVersions();
      childDetailsSyncedAt = await _storage.childDetailsSyncedAt();
      await _loadSessions(restoreSelection: true);
      if (childDetailsById.isEmpty || childDetailVersions.isEmpty) {
        await _syncChildDetails(force: true, surfaceError: true);
      } else {
        unawaited(_syncChildDetails());
      }
      _startChildDetailPolling();
    } on ApiException catch (error) {
      if (error.isAuthentication) {
        await _clearAuthentication();
      }
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'The app could not restore its previous state.';
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> configureServer(String value) async {
    return _runBusy(() async {
      _api.configure(value);
      await _api.health();
      apiUrl = _api.baseUrl;
      await _storage.saveApiUrl(apiUrl);
    });
  }

  Future<bool> login(String email, String password) async {
    return _runBusy(() async {
      final result = await _api.login(email, password);
      if (result.token.isEmpty || result.volunteer.volunteerId.isEmpty) {
        throw const ApiException('INVALID_RESPONSE', 'Login did not return a valid account.');
      }
      token = result.token;
      volunteer = result.volunteer;
      await _storage.saveToken(token);
      childDetailsById = {};
      childDetailVersions = {};
      childDetailsSyncedAt = null;
      await _storage.clearChildDetails();
      selectedSession = null;
      children = const [];
      presentByChildId = {};
      await _loadSessions();
      await _syncChildDetails(force: true, surfaceError: true);
      _startChildDetailPolling();
    });
  }

  Future<bool> logout() async {
    if (pendingCount > 0) {
      errorMessage = 'Sync pending attendance changes before signing out.';
      notifyListeners();
      return false;
    }
    return _runBusy(() async {
      try {
        await _api.logout(token);
      } catch (_) {
        // Local logout remains available when the network is unavailable.
      }
      await _clearAuthentication();
    });
  }

  Future<bool> disconnectServer() async {
    if (pendingCount > 0) {
      errorMessage = 'Sync pending attendance changes before changing servers.';
      notifyListeners();
      return false;
    }
    return _runBusy(() async {
      await _clearAuthentication();
      apiUrl = '';
      _api.clearConfiguration();
      await _storage.saveApiUrl('');
    });
  }

  Future<bool> refreshSessions() => _runBusy(() => _loadSessions(restoreSelection: false));

  Future<bool> selectSession(ServiceSession session) async {
    return _runBusy(() async {
      selectedSession = session;
      await _storage.saveSelectedSessionId(session.sessionId);
      scheduleRoles = const [];
      _loadedAt.remove(AppTab.schedule);
      await _loadAttendance();
      selectedTab = AppTab.attendance;
      unawaited(flushPending());
      unawaited(_prefetchVolunteerContent());
      unawaited(_syncChildDetails());
    });
  }

  void leaveAttendance() {
    selectedSession = null;
    children = const [];
    presentByChildId = {};
    searchQuery = '';
    errorMessage = '';
    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setChildSort(ChildSort value) {
    childSort = value;
    notifyListeners();
  }

  void selectTab(AppTab tab) {
    selectedTab = tab;
    searchQuery = '';
    notifyListeners();
    if (_isTabStale(tab)) {
      unawaited(_refreshTabSilently(tab));
    }
  }

  Future<void> refreshCurrentTab() async {
    switch (selectedTab) {
      case AppTab.attendance:
      case AppTab.kids:
        await _runBusy(() async {
          await _loadAttendance();
          await _syncChildDetails(force: true, surfaceError: true);
        });
        return;
      case AppTab.roster:
        await _runBusy(_loadRoster);
        return;
      case AppTab.schedule:
        await _runBusy(_loadSchedule);
        return;
      case AppTab.resources:
        await _runBusy(_loadResources);
        return;
    }
  }

  Future<void> respondToRoster(RosterItem item, String decision, {String notes = ''}) async {
    final ok = await _runBusy(() => _api.respondToRoster(token, item.rosterId, decision, notes: notes));
    if (ok) await refreshCurrentTab();
  }

  Future<VolunteerProfile?> loadProfile() async {
    VolunteerProfile? result;
    await _runBusy(() async {
      result = await _api.profile(token);
      profile = result;
    });
    return result;
  }

  Future<void> toggleAttendance(ChildSummary child, bool present) async {
    final session = selectedSession;
    final actor = volunteer;
    if (session == null || actor == null) return;

    presentByChildId = {...presentByChildId, child.childId: present};
    final write = PendingAttendanceWrite(
      requestId: _newRequestId(),
      actorId: actor.volunteerId,
      sessionId: session.sessionId,
      date: session.date,
      childId: child.childId,
      present: present,
      createdAt: DateTime.now().toUtc(),
    );
    pendingWrites = AttendanceQueue.upsert(pendingWrites, write);
    await _storage.savePendingWrites(pendingWrites);
    notifyListeners();
    unawaited(flushPending());
  }

  Future<void> flushPending() async {
    if (syncing || !isAuthenticated || pendingCount == 0) return;
    syncing = true;
    errorMessage = '';
    notifyListeners();
    var changedServer = false;

    try {
      final currentSessions = await _api.listSessions(token);
      sessions = currentSessions;
      final activeKeys = currentSessions.map((item) => '${item.date}|${item.sessionId}').toSet();
      final actorId = volunteer!.volunteerId;
      final work = pendingWrites.where((item) => item.actorId == actorId).toList();

      for (final write in work) {
        if (!activeKeys.contains('${write.date}|${write.sessionId}')) {
          errorMessage = 'A pending change belongs to a closed or unavailable service. Select that service before retrying.';
          break;
        }
        try {
          await _api.setAttendance(token, write);
          pendingWrites = AttendanceQueue.removeRequest(pendingWrites, write.requestId);
          await _storage.savePendingWrites(pendingWrites);
          changedServer = true;
          notifyListeners();
        } on ApiException catch (error) {
          errorMessage = error.message;
          if (error.isAuthentication) {
            await _clearAuthentication(keepError: true);
          }
          break;
        }
      }

      if (changedServer && selectedSession != null && isAuthenticated) {
        await _loadAttendance();
      }
    } on ApiException catch (error) {
      errorMessage = error.message;
      if (error.isAuthentication) {
        await _clearAuthentication(keepError: true);
      }
    } catch (_) {
      errorMessage = 'Pending attendance is saved on this device and will retry later.';
    } finally {
      syncing = false;
      notifyListeners();
      if (isAuthenticated && pendingCount > 0 && errorMessage.isEmpty) {
        unawaited(flushPending());
      }
    }
  }

  Future<void> onAppResumed() async {
    if (!isAuthenticated) return;
    try {
      await _loadSessions(restoreSelection: selectedSession != null);
      await flushPending();
      unawaited(_syncChildDetails(force: true));
    } on ApiException catch (error) {
      errorMessage = error.message;
      if (error.isAuthentication) {
        await _clearAuthentication(keepError: true);
      }
      notifyListeners();
    }
  }

  Future<ChildDetails?> loadChildDetails(String childId) async {
    return childDetailsById[childId];
  }

  void clearError() {
    errorMessage = '';
    notifyListeners();
  }

  Future<void> _loadSessions({bool restoreSelection = false}) async {
    sessions = await _api.listSessions(token);
    if (!restoreSelection) return;
    final storedId = selectedSession?.sessionId ?? await _storage.selectedSessionId();
    ServiceSession? match;
    for (final session in sessions) {
      if (session.sessionId == storedId) {
        match = session;
        break;
      }
    }
    selectedSession = match;
    if (match != null) {
      await _loadAttendance();
      unawaited(_prefetchVolunteerContent());
    }
  }

  Future<void> _loadAttendance() async {
    final session = selectedSession;
    if (session == null) return;
    final result = await _api.bootstrapAttendance(token, session);
    children = [...result.children]..sort((a, b) => a.fullName.compareTo(b.fullName));
    presentByChildId = {...result.presentByChildId};
    nightNoteByChildId = {...result.nightNoteByChildId};
    pendingPickupByChildId = {...result.pendingPickupByChildId};

    final actorId = volunteer?.volunteerId ?? '';
    for (final write in pendingWrites) {
      if (write.actorId == actorId && write.sessionId == session.sessionId && write.date == session.date) {
        presentByChildId[write.childId] = write.present;
      }
    }
    final now = DateTime.now();
    _loadedAt[AppTab.attendance] = now;
    _loadedAt[AppTab.kids] = now;
  }

  Future<void> _loadRoster() async {
    roster = await _api.myRoster(token);
    _loadedAt[AppTab.roster] = DateTime.now();
  }

  Future<void> _loadSchedule() async {
    final session = selectedSession;
    if (session == null) return;
    scheduleRoles = await _api.schedule(token, session);
    _loadedAt[AppTab.schedule] = DateTime.now();
  }

  Future<void> _loadResources() async {
    resources = await _api.resources(token);
    _loadedAt[AppTab.resources] = DateTime.now();
  }

  bool _isTabStale(AppTab tab) {
    final loaded = _loadedAt[tab];
    if (loaded == null) return true;
    final age = DateTime.now().difference(loaded);
    return age > switch (tab) {
      AppTab.attendance || AppTab.kids => _attendanceFreshFor,
      AppTab.roster => _rosterFreshFor,
      AppTab.schedule => _scheduleFreshFor,
      AppTab.resources => _resourcesFreshFor,
    };
  }

  bool _isChildDetailsStale() {
    final syncedAt = childDetailsSyncedAt;
    if (syncedAt == null || childDetailsById.isEmpty || childDetailVersions.isEmpty) return true;
    return DateTime.now().toUtc().difference(syncedAt.toUtc()) > _childDetailsFreshFor;
  }

  Future<bool> _syncChildDetails({bool force = false, bool surfaceError = false}) async {
    if (!isAuthenticated || syncingChildDetails) return false;
    if (!force && !_isChildDetailsStale()) return true;

    syncingChildDetails = true;
    notifyListeners();
    try {
      final result = await _api.syncChildDetails(token, childDetailVersions);
      final now = result.syncedAt?.toUtc() ?? DateTime.now().toUtc();

      if (result.fullSnapshot) {
        childDetailsById = {
          for (final child in result.changed)
            if (child.childId.isNotEmpty) child.childId: child,
        };
        childDetailVersions = {...result.changedVersions};
        await _storage.saveChildDetails(result.changed, now);
        await _storage.saveChildDetailVersions(childDetailVersions);
      } else {
        final updatedDetails = {...childDetailsById};
        final updatedVersions = {...childDetailVersions};

        for (final childId in result.removed) {
          updatedDetails.remove(childId);
          updatedVersions.remove(childId);
        }
        for (final child in result.changed) {
          if (child.childId.isEmpty) continue;
          updatedDetails[child.childId] = child;
          final version = result.changedVersions[child.childId] ?? '';
          if (version.isEmpty) {
            updatedVersions.remove(child.childId);
          } else {
            updatedVersions[child.childId] = version;
          }
        }

        childDetailsById = updatedDetails;
        childDetailVersions = updatedVersions;
        await _storage.applyChildDetailsDelta(
          changed: result.changed,
          removed: result.removed,
          versions: childDetailVersions,
          syncedAt: now,
        );
      }

      childDetailsSyncedAt = now;
      return true;
    } on ApiException catch (error) {
      if (error.isAuthentication) {
        errorMessage = error.message;
        await _clearAuthentication(keepError: true);
      } else if (surfaceError) {
        errorMessage = childDetailsById.isEmpty
            ? 'Child details could not be downloaded. Check the connection and refresh again.'
            : error.message;
      }
      return false;
    } catch (_) {
      if (surfaceError) {
        errorMessage = childDetailsById.isEmpty
            ? 'Child details could not be downloaded. Check the connection and refresh again.'
            : 'The saved child details could not be refreshed.';
      }
      return false;
    } finally {
      syncingChildDetails = false;
      notifyListeners();
    }
  }

  void _startChildDetailPolling() {
    _childSyncPollTimer?.cancel();
    if (!isAuthenticated) return;
    _childSyncPollTimer = Timer.periodic(_childDetailsPollEvery, (_) {
      if (isAuthenticated) {
        unawaited(_syncChildDetails(force: true));
      }
    });
  }

  Future<void> _refreshTabSilently(AppTab tab) async {
    if (_refreshingTabs.contains(tab) || !isAuthenticated || selectedSession == null) {
      return;
    }
    _refreshingTabs.add(tab);
    try {
      switch (tab) {
        case AppTab.attendance:
        case AppTab.kids:
          await _loadAttendance();
          break;
        case AppTab.roster:
          await _loadRoster();
          break;
        case AppTab.schedule:
          await _loadSchedule();
          break;
        case AppTab.resources:
          await _loadResources();
          break;
      }
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isAuthentication) {
        errorMessage = error.message;
        await _clearAuthentication(keepError: true);
        notifyListeners();
      }
      // Keep cached content visible for transient background-refresh failures.
    } catch (_) {
      // Keep cached content visible for transient background-refresh failures.
    } finally {
      _refreshingTabs.remove(tab);
    }
  }

  Future<void> _prefetchVolunteerContent() async {
    await Future.wait([
      _refreshTabSilently(AppTab.roster),
      _refreshTabSilently(AppTab.schedule),
      _refreshTabSilently(AppTab.resources),
    ]);
  }

  Future<bool> _runBusy(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    errorMessage = '';
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      if (error.isAuthentication) {
        await _clearAuthentication(keepError: true);
      }
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _clearAuthentication({bool keepError = false}) async {
    _childSyncPollTimer?.cancel();
    _childSyncPollTimer = null;
    token = '';
    volunteer = null;
    sessions = const [];
    selectedSession = null;
    children = const [];
    childDetailsById = {};
    childDetailVersions = {};
    childDetailsSyncedAt = null;
    presentByChildId = {};
    selectedTab = AppTab.attendance;
    roster = null;
    scheduleRoles = const [];
    resources = null;
    profile = null;
    _loadedAt.clear();
    _refreshingTabs.clear();
    await _storage.saveToken('');
    await _storage.clearChildDetails();
    if (!keepError) errorMessage = '';
  }

  String _newRequestId() => 'attendance-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _childSyncPollTimer?.cancel();
    _api.close();
    super.dispose();
  }
}
