import 'dart:convert';

class VerseNote {
  final String id;
  final String book;
  final int chapter;
  final int startVerse;
  final int endVerse;
  final String content;
  final List<String> verseTexts;
  final DateTime createdAt;
  final DateTime updatedAt;

  VerseNote({
    required this.id,
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
    required this.content,
    this.verseTexts = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String get reference {
    if (startVerse == endVerse) {
      return '$book $chapter:$startVerse';
    }
    return '$book $chapter:$startVerse-$endVerse';
  }

  String get verseKey => '${book}_${chapter}_$startVerse';

  bool containsVerse(int verse) {
    return verse >= startVerse && verse <= endVerse;
  }

  factory VerseNote.create({
    required String book,
    required int chapter,
    required int startVerse,
    required int endVerse,
    required String content,
    List<String> verseTexts = const [],
  }) {
    final now = DateTime.now();
    return VerseNote(
      id: '${book}_${chapter}_${startVerse}_${now.millisecondsSinceEpoch}',
      book: book,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      content: content,
      verseTexts: verseTexts,
      createdAt: now,
      updatedAt: now,
    );
  }

  VerseNote copyWith({String? content, List<String>? verseTexts}) {
    return VerseNote(
      id: id,
      book: book,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      content: content ?? this.content,
      verseTexts: verseTexts ?? this.verseTexts,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory VerseNote.fromJson(Map<String, dynamic> json) {
    return VerseNote(
      id: json['id'],
      book: json['book'],
      chapter: json['chapter'],
      startVerse: json['startVerse'] ?? json['verse'] ?? 1,
      endVerse: json['endVerse'] ?? json['verse'] ?? 1,
      content: json['content'],
      verseTexts: List<String>.from(json['verseTexts'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book': book,
      'chapter': chapter,
      'startVerse': startVerse,
      'endVerse': endVerse,
      'content': content,
      'verseTexts': verseTexts,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static String generateKey(String book, int chapter, int verse) {
    return '${book}_${chapter}_$verse';
  }

  static List<VerseNote> fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => VerseNote.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static String toJsonString(List<VerseNote> notes) {
    return jsonEncode(notes.map((n) => n.toJson()).toList());
  }
}
