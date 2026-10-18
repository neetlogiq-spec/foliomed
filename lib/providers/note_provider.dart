import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/note_service.dart';

class NoteProvider extends ChangeNotifier {
  final NoteService _noteService;

  NoteProvider({NoteService? noteService})
      : _noteService = noteService ?? NoteService();

  List<Note> _notes = [];
  List<Note> _patientNotes = [];
  int _unacknowledgedCount = 0;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<Note>>? _wardNotesSubscription;
  StreamSubscription<List<Note>>? _patientNotesSubscription;
  StreamSubscription<int>? _unacknowledgedSubscription;

  List<Note> get notes => _notes;
  List<Note> get patientNotes => _patientNotes;
  int get unacknowledgedCount => _unacknowledgedCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Note> get urgentNotes =>
      _notes.where((n) => n.priority == 'Urgent').toList();

  void subscribeForWards(List<String> wardIds) {
    _wardNotesSubscription?.cancel();
    _unacknowledgedSubscription?.cancel();

    if (wardIds.isEmpty) {
      _notes = [];
      _unacknowledgedCount = 0;
      notifyListeners();
      return;
    }

    _wardNotesSubscription =
        _noteService.getNotesForWards(wardIds).listen((notes) {
      _notes = notes;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });

    _unacknowledgedSubscription =
        _noteService.getUnacknowledgedCountForWards(wardIds).listen((count) {
      _unacknowledgedCount = count;
      notifyListeners();
    });
  }

  void subscribeToWard(String wardId) {
    _wardNotesSubscription?.cancel();
    _unacknowledgedSubscription?.cancel();

    _wardNotesSubscription =
        _noteService.getNotesByWard(wardId).listen((notes) {
      _notes = notes;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });

    _unacknowledgedSubscription =
        _noteService.getUnacknowledgedCount(wardId).listen((count) {
      _unacknowledgedCount = count;
      notifyListeners();
    });
  }

  void subscribeToPatient(String patientId) {
    _patientNotesSubscription?.cancel();
    _patientNotesSubscription =
        _noteService.getNotesByPatient(patientId).listen((notes) {
      _patientNotes = notes;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  /// Cancels just the per-patient stream. PatientDetailScreen calls this
  /// in `dispose()` so the patient-notes listener doesn't keep ticking
  /// (and billing reads) after the user navigates away.
  void unsubscribeFromPatient() {
    _patientNotesSubscription?.cancel();
    _patientNotesSubscription = null;
    _patientNotes = const [];
  }

  Future<bool> addNote(Note note) async {
    try {
      await _noteService.addNote(note);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> acknowledgeNote(String noteId, String acknowledgedBy) async {
    try {
      await _noteService.acknowledgeNote(noteId, acknowledgedBy);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> acknowledgeAllNotes(
      List<String> noteIds, String acknowledgedBy) async {
    try {
      await _noteService.acknowledgeAllNotes(noteIds, acknowledgedBy);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unacknowledgeNote(String noteId) async {
    try {
      await _noteService.unacknowledgeNote(noteId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteNote(String noteId) async {
    try {
      await _noteService.deleteNote(noteId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Cancel all listeners but preserve currently-loaded data so the UI
  /// keeps showing it. Used when the app goes to the background.
  void pauseStreams() {
    _wardNotesSubscription?.cancel();
    _patientNotesSubscription?.cancel();
    _unacknowledgedSubscription?.cancel();
    _wardNotesSubscription = null;
    _patientNotesSubscription = null;
    _unacknowledgedSubscription = null;
  }

  void cancelSubscriptions() {
    _wardNotesSubscription?.cancel();
    _patientNotesSubscription?.cancel();
    _unacknowledgedSubscription?.cancel();
    _wardNotesSubscription = null;
    _patientNotesSubscription = null;
    _unacknowledgedSubscription = null;
  }

  @override
  void dispose() {
    cancelSubscriptions();
    super.dispose();
  }
}
