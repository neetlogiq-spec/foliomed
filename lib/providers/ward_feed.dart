import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/notes_repository.dart';
import '../utils/haptics.dart';

/// Live notes for the signed-in user: the feed across their wards, the
/// count still waiting for confirmation, and — while a patient page is
/// open — that patient's timeline.
class WardFeed extends ChangeNotifier {
  WardFeed({NotesRepository? repository}) : _repo = repository ?? NotesRepository();

  final NotesRepository _repo;

  List<Note> _feed = const [];
  List<Note> _timeline = const [];
  int _pending = 0;
  Object? lastError;

  StreamSubscription<List<Note>>? _feedSub;
  StreamSubscription<int>? _pendingSub;
  StreamSubscription<List<Note>>? _timelineSub;

  /// Newest first, capped at [NotesRepository.feedSize].
  List<Note> get feed => _feed;
  List<Note> get urgent => [for (final n in _feed) if (n.isUrgent) n];
  List<Note> get timeline => _timeline;
  int get pendingCount => _pending;

  void _fail(Object e) {
    lastError = e;
    debugPrint('WardFeed: $e');
    notifyListeners();
  }

  void watchWards(List<String> wardIds) {
    _feedSub?.cancel();
    _pendingSub?.cancel();
    if (wardIds.isEmpty) {
      _feed = const [];
      _pending = 0;
      notifyListeners();
      return;
    }
    _feedSub = _repo.wardsFeed(wardIds).listen((v) {
      _feed = v;
      notifyListeners();
    }, onError: _fail);
    _pendingSub = _repo.pendingCount(wardIds).listen((v) {
      _pending = v;
      notifyListeners();
    }, onError: _fail);
  }

  void watchPatient(String patientId) {
    _timelineSub?.cancel();
    _timeline = const [];
    _timelineSub = _repo.patientTimeline(patientId).listen((v) {
      _timeline = v;
      notifyListeners();
    }, onError: _fail);
  }

  void stopWatchingPatient() {
    _timelineSub?.cancel();
    _timelineSub = null;
    _timeline = const [];
  }

  /// App in the background: stop live reads (resume with [watchWards]).
  void pause() {
    _feedSub?.cancel();
    _pendingSub?.cancel();
    _timelineSub?.cancel();
    _feedSub = _pendingSub = null;
    _timelineSub = null;
  }

  Future<bool> _attempt(Future<void> Function() op, void Function() feedback) async {
    try {
      await op();
      feedback();
      return true;
    } catch (e) {
      Haptics.error();
      _fail(e);
      return false;
    }
  }

  Future<bool> post(Note note) => _attempt(() => _repo.post(note), Haptics.success);

  Future<bool> confirm(String noteId, String byName) =>
      _attempt(() => _repo.confirm(noteId, byName), Haptics.success);

  Future<bool> confirmMany(List<String> noteIds, String byName) =>
      _attempt(() => _repo.confirmMany(noteIds, byName), Haptics.success);

  Future<bool> undoConfirm(String noteId) =>
      _attempt(() => _repo.undoConfirm(noteId), Haptics.commit);

  Future<bool> remove(String noteId) =>
      _attempt(() => _repo.remove(noteId), Haptics.destructive);

  @override
  void dispose() {
    pause();
    super.dispose();
  }
}
