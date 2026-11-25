import 'dart:convert';

class VerseHighlight {
  final String id;
  final String book;
  final int chapter;
  final int startVerse;
  final int endVerse;
  final String color;
  final DateTime createdAt;

  VerseHighlight({
    required this.id,
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
    required this.color,
    required this.createdAt,
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

  factory VerseHighlight.create({
    required String book,
    required int chapter,
    required int startVerse,
    required int endVerse,
    required String color,
  }) {
    return VerseHighlight(
      id: '${book}_${chapter}_${startVerse}_${DateTime.now().millisecondsSinceEpoch}',
      book: book,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      color: color,
      createdAt: DateTime.now(),
    );
  }

  factory VerseHighlight.fromJson(Map<String, dynamic> json) {
    return VerseHighlight(
      id: json['id'],
      book: json['book'],
      chapter: json['chapter'],
      startVerse: json['startVerse'],
      endVerse: json['endVerse'],
      color: json['color'] ?? 'yellow',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book': book,
      'chapter': chapter,
      'startVerse': startVerse,
      'endVerse': endVerse,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static List<VerseHighlight> fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => VerseHighlight.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static String toJsonString(List<VerseHighlight> highlights) {
    return jsonEncode(highlights.map((h) => h.toJson()).toList());
  }
}

const List<String> highlightColors = [
  'yellow',
  'green',
  'blue',
  'pink',
  'orange',
];
