import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:module_tracker/models/note.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/repositories/firestore_repository.dart';
import 'package:uuid/uuid.dart';

/// Notes notifier
class NotesNotifier extends StateNotifier<List<Note>> {
  static const String _notesKey = 'notes';
  Box? _settingsBox;
  final String? _userId;
  final FirestoreRepository _repository;

  NotesNotifier({String? userId, required FirestoreRepository repository})
      : _userId = userId,
        _repository = repository,
        super([]) {
    _loadNotes();
  }

  String _getUserKey(String baseKey) {
    if (_userId != null && _userId!.isNotEmpty) {
      return 'user_${_userId}_$baseKey';
    }
    return baseKey;
  }

  /// Load notes from storage
  Future<void> _loadNotes() async {
    try {
      _settingsBox = await Hive.openBox('settings');

      // Try to load from Firestore first if user is logged in
      if (_userId != null && _userId!.isNotEmpty) {
        try {
          final firestoreNotes = await _repository.getNotes(_userId!);
          if (firestoreNotes != null && firestoreNotes.isNotEmpty) {
            final notes = firestoreNotes
                .map((noteMap) => Note.fromMap(noteMap))
                .toList();
            // Maintain order as stored
            state = notes;
            // Cache in Hive
            await _settingsBox?.put(_getUserKey(_notesKey),
                notes.map((n) => n.toMap()).toList());
            return;
          }
        } catch (e) {
          print('Error loading notes from Firestore: $e');
        }
      }

      // Fall back to Hive
      final savedNotes = _settingsBox?.get(_getUserKey(_notesKey));
      if (savedNotes != null && savedNotes is List) {
        final notes = savedNotes
            .map((noteMap) =>
                Note.fromMap(Map<String, dynamic>.from(noteMap as Map)))
            .toList();
        // Maintain order as stored
        state = notes;
      }
    } catch (e) {
      print('Error loading notes: $e');
    }
  }

  /// Save notes to storage
  Future<void> _saveNotes() async {
    try {
      final notesMaps = state.map((n) => n.toMap()).toList();
      await _settingsBox?.put(_getUserKey(_notesKey), notesMaps);

      // Sync to Firestore if user is logged in
      if (_userId != null && _userId!.isNotEmpty) {
        try {
          await _repository.saveNotes(_userId!, notesMaps);
        } catch (e) {
          print('Error syncing notes to Firestore: $e');
        }
      }
    } catch (e) {
      print('Error saving notes: $e');
    }
  }

  /// Add a new note
  Future<void> addNote(String title, String content) async {
    if (content.trim().isEmpty) return;

    final note = Note(
      id: const Uuid().v4(),
      title: title.trim(),
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    // Add to top of list
    state = [note, ...state];
    await _saveNotes();
  }

  /// Update an existing note
  Future<void> updateNote(String id, String title, String content) async {
    if (content.trim().isEmpty) {
      // If content is empty, delete the note
      await deleteNote(id);
      return;
    }

    state = state.map((note) {
      if (note.id == id) {
        return note.copyWith(
          title: title.trim(),
          content: content.trim(),
          updatedAt: DateTime.now(),
        );
      }
      return note;
    }).toList();

    await _saveNotes();
  }

  /// Delete a note
  Future<void> deleteNote(String id) async {
    state = state.where((note) => note.id != id).toList();
    await _saveNotes();
  }

  /// Reorder notes (drag and drop)
  Future<void> reorderNotes(int oldIndex, int newIndex) async {
    // Adjust newIndex if dragging down
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final newState = List<Note>.from(state);
    final note = newState.removeAt(oldIndex);
    newState.insert(newIndex, note);
    state = newState;
    await _saveNotes();
  }
}

/// Provider for notes
final notesProvider =
    StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final userId = currentUser?.uid;
  final repository = ref.watch(firestoreRepositoryProvider);
  return NotesNotifier(userId: userId, repository: repository);
});
