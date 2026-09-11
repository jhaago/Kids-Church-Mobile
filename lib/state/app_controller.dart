import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kids_church_mobile/api/kids_church_api.dart';
import 'package:kids_church_mobile/models/models.dart';
import 'package:kids_church_mobile/storage/mobile_storage.dart';

class AppController extends ChangeNotifier {
  AppController({required KidsChurchApi api, required MobileStorage storage})
      : _api = api,
        _storage = storage;

  final KidsChurchApi _api;
  final MobileStorage _storage;

  bool initializing = true;
  bool busy = false;
  bool syncing = false;
  String apiUrl = '';
  String token = '';
  Volunteer? volunteer;
  List<ServiceSession> sessions = const [];
  ServiceSession? selectedSession;
  List<ChildSummary> children = const [];
  Map<String, bool> presentByChildId = {};
  Map<String, String> nightNoteByChildId = {};
  Map<String, bool> pendingPickupByChildId = {};
  List<PendingAttendanceWrite> pendingWrites = const [];
  String searchQuery = '';
  String errorMessage = '';

  bool get isConfigured => apiUrl.isNotEmpty;
  bool get isAuthenticated => volunteer != null && token.isNotEmpty;

  List<ChildSummary> get visibleChildren {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return children;
    return children.where((child) {
      return '${child.fullName} ${child.firstName} ${child.surname}'.toLowerCase().contains(query);
    }).toList(growable: false);
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
      if (token.isEmpty) return;
      volunteer = await _api.me(token);
      await _loadSessions(restoreSelection: true);
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
      selectedSession = null;
      children = const [];
      presentByChildId = {};
      await _loadSessions();
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
      await _loadAttendance();
      unawaited(flushPending());
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
    } on ApiException catch (error) {
      errorMessage = error.message;
      if (error.isAuthentication) {
        await _clearAuthentication(keepError: true);
      }
      notifyListeners();
    }
  }

  Future<ChildDetails?> loadChildDetails(String childId) async {
    try {
      errorMessage = '';
      return await _api.childDetails(token, childId);
    } on ApiException catch (error) {
      errorMessage = error.message;
      if (error.isAuthentication) {
        await _clearAuthentication(keepError: true);
      }
      notifyListeners();
      return null;
    }
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
    if (match != null) await _loadAttendance();
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
    token = '';
    volunteer = null;
    sessions = const [];
    selectedSession = null;
    children = const [];
    presentByChildId = {};
    await _storage.saveToken('');
    if (!keepError) errorMessage = '';
  }

  String _newRequestId() => 'attendance-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}
