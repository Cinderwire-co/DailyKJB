import 'package:shared_preferences/shared_preferences.dart';

import '../models/highlight.dart';

class HighlightService {
  static final HighlightService _instance = HighlightService._internal();
  factory HighlightService() => _instance;
  HighlightService._internal();

  static const String _storageKey = 'verse_highlights';
  List<VerseHighlight> _highlights = [];

  List<VerseHighlight> get allHighlights => List.unmodifiable(_highlights);

  Future<void> loadHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    _highlights = VerseHighlight.fromJsonString(jsonString);
  }

  Future<void> _saveHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      VerseHighlight.toJsonString(_highlights),
    );
  }

  bool hasHighlight(String book, int chapter, int verse) {
    return _highlights.any(
      (h) => h.book == book && h.chapter == chapter && h.containsVerse(verse),
    );
  }

  VerseHighlight? getHighlight(String book, int chapter, int verse) {
    try {
      return _highlights.firstWhere(
        (h) => h.book == book && h.chapter == chapter && h.containsVerse(verse),
      );
    } catch (e) {
      return null;
    }
  }

  String? getHighlightColor(String book, int chapter, int verse) {
    final highlight = getHighlight(book, chapter, verse);
    return highlight?.color;
  }

  Future<VerseHighlight> saveHighlight({
    required String book,
    required int chapter,
    required int startVerse,
    required int endVerse,
    required String color,
  }) async {
    // Remove any existing highlights that overlap
    _highlights.removeWhere(
      (h) =>
          h.book == book &&
          h.chapter == chapter &&
          ((h.startVerse >= startVerse && h.startVerse <= endVerse) ||
              (h.endVerse >= startVerse && h.endVerse <= endVerse) ||
              (startVerse >= h.startVerse && startVerse <= h.endVerse)),
    );

    final highlight = VerseHighlight.create(
      book: book,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      color: color,
    );

    _highlights.add(highlight);
    await _saveHighlights();
    return highlight;
  }

  Future<void> deleteHighlight(String book, int chapter, int verse) async {
    _highlights.removeWhere(
      (h) => h.book == book && h.chapter == chapter && h.containsVerse(verse),
    );
    await _saveHighlights();
  }

  List<VerseHighlight> getHighlightsForChapter(String book, int chapter) {
    return _highlights
        .where((h) => h.book == book && h.chapter == chapter)
        .toList();
  }

  List<VerseHighlight> getRecentHighlights({int limit = 50}) {
    final sorted = List<VerseHighlight>.from(_highlights)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }
}
