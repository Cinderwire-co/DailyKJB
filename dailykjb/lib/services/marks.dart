import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show Color;

import '../bible/kjb.dart';
import '../models/highlight.dart';
import '../models/verse_note.dart';
import '../ui/theme.dart';
import 'highlight_service.dart';
import 'notes_service.dart';

/// The reader's highlights and notes, all of them, kept on the phone; every
/// screen that shows them is told when they change.
class Marks extends ChangeNotifier {
  Marks._();
  static final i = Marks._();

  final _highlights = HighlightService();
  final _notes = NotesService();
  bool loaded = false;

  Future<void> load() async {
    await Future.wait([_highlights.loadHighlights(), _notes.loadNotes()]);
    loaded = true;
    notifyListeners();
  }

  List<VerseHighlight> get highlights =>
      _highlights.getRecentHighlights(limit: 100000);
  List<VerseNote> get notes => _notes.getRecentNotes(limit: 100000);

  Color? colorOf(int book, int chapter, int verse) {
    final c = _highlights.getHighlightColor(Kjb.name(book), chapter, verse);
    return c == null ? null : Parchment.highlight(c);
  }

  List<VerseNote> notesIn(int book, int chapter) =>
      _notes.getNotesForChapter(Kjb.name(book), chapter)
        ..sort((a, b) => a.startVerse.compareTo(b.startVerse));

  /// [runs]: the verses chosen, as (first, last) runs. 'none' takes the
  /// highlight off.
  Future<void> highlight(
    int book,
    int chapter,
    List<(int, int)> runs,
    String color,
  ) async {
    final name = Kjb.name(book);
    for (final r in runs) {
      if (color == 'none') {
        for (var v = r.$1; v <= r.$2; v++) {
          await _highlights.deleteHighlight(name, chapter, v);
        }
      } else {
        await _highlights.saveHighlight(
          book: name,
          chapter: chapter,
          startVerse: r.$1,
          endVerse: r.$2,
          color: color,
        );
      }
    }
    notifyListeners();
  }

  Future<void> removeHighlight(VerseHighlight h) async {
    await _highlights.deleteHighlight(h.book, h.chapter, h.startVerse);
    notifyListeners();
  }

  Future<void> addNote(
    int book,
    int chapter,
    List<(int, int)> runs,
    String content,
  ) async {
    final vs = Kjb.verses(book, chapter);
    for (final r in runs) {
      await _notes.saveNote(
        book: Kjb.name(book),
        chapter: chapter,
        startVerse: r.$1,
        endVerse: r.$2,
        content: content,
        verseTexts: [
          for (var v = r.$1; v <= r.$2 && v <= vs.length; v++) vs[v - 1],
        ],
      );
    }
    notifyListeners();
  }

  Future<void> updateNote(VerseNote note, String content) async {
    await _notes.updateNote(note, content);
    notifyListeners();
  }

  Future<void> deleteNote(VerseNote note) async {
    await _notes.deleteNote(note.id);
    notifyListeners();
  }
}
