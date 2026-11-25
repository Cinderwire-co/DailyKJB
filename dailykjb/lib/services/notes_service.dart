import 'package:shared_preferences/shared_preferences.dart';

import '../models/verse_note.dart';

class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  static const String _storageKey = 'verse_notes';
  List<VerseNote> _notes = [];

  List<VerseNote> get allNotes => List.unmodifiable(_notes);

  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    _notes = VerseNote.fromJsonString(jsonString);
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, VerseNote.toJsonString(_notes));
  }

  bool hasNote(String book, int chapter, int verse) {
    return _notes.any(
      (n) => n.book == book && n.chapter == chapter && n.containsVerse(verse),
    );
  }

  VerseNote? getNote(String book, int chapter, int verse) {
    try {
      return _notes.firstWhere(
        (n) => n.book == book && n.chapter == chapter && n.containsVerse(verse),
      );
    } catch (e) {
      return null;
    }
  }

  Future<VerseNote> saveNote({
    required String book,
    required int chapter,
    required int startVerse,
    required int endVerse,
    required String content,
    List<String> verseTexts = const [],
  }) async {
    // Remove any existing notes that overlap
    _notes.removeWhere(
      (n) =>
          n.book == book &&
          n.chapter == chapter &&
          ((n.startVerse >= startVerse && n.startVerse <= endVerse) ||
              (n.endVerse >= startVerse && n.endVerse <= endVerse) ||
              (startVerse >= n.startVerse && startVerse <= n.endVerse)),
    );

    final note = VerseNote.create(
      book: book,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      content: content,
      verseTexts: verseTexts,
    );

    _notes.add(note);
    await _saveNotes();
    return note;
  }

  Future<void> updateNote(VerseNote note, String content) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = note.copyWith(content: content);
      await _saveNotes();
    }
  }

  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    await _saveNotes();
  }

  List<VerseNote> getNotesForChapter(String book, int chapter) {
    return _notes.where((n) => n.book == book && n.chapter == chapter).toList();
  }

  List<VerseNote> searchNotes(String query) {
    final lowerQuery = query.toLowerCase();
    return _notes
        .where(
          (n) =>
              n.content.toLowerCase().contains(lowerQuery) ||
              n.reference.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  List<VerseNote> getRecentNotes({int limit = 20}) {
    final sorted = List<VerseNote>.from(_notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(limit).toList();
  }
}
