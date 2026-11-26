import 'dart:convert';
import 'dart:io' show GZipCodec;

import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/services.dart' show rootBundle;

/// A book of the Bible, numbered 1 (Genesis) to 66 (Revelation).
class BibleBook {
  final int id;
  final String name;
  final bool oldTestament;
  final int chapters;

  const BibleBook({
    required this.id,
    required this.name,
    required this.oldTestament,
    required this.chapters,
  });

  /// "Psalm 23", not "Psalms 23", when it names one chapter.
  String get singular => name == 'Psalms' ? 'Psalm' : name;
}

/// Part of one chapter: the whole of it, or verses [from]..[to].
class ChapterSpan {
  final int book;
  final int chapter;
  final int? from;
  final int? to;

  const ChapterSpan(this.book, this.chapter, [this.from, this.to]);

  bool get whole => from == null && to == null;

  int firstVerse() => from ?? 1;
  int lastVerse() => to ?? Kjb.verses(book, chapter).length;

  /// The verses as (number, text).
  List<(int, String)> verses() {
    final all = Kjb.verses(book, chapter);
    final a = firstVerse(), b = lastVerse().clamp(0, all.length);
    return [for (var n = a; n <= b; n++) (n, all[n - 1])];
  }

  String get label {
    final name = Kjb.bookOf(book)?.singular ?? '';
    if (whole) return '$name $chapter';
    final a = firstVerse(), b = lastVerse();
    return a == b ? '$name $chapter:$a' : '$name $chapter:$a–$b';
  }

  @override
  bool operator ==(Object other) =>
      other is ChapterSpan &&
      other.book == book &&
      other.chapter == chapter &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(book, chapter, from, to);
}

/// The King James Bible, in the app itself (assets/bible), so every chapter is
/// there the moment it's asked for, with or without a connection.
class Kjb {
  static List<BibleBook> books = [];
  static final _text = <int, List<List<String>>>{};
  static final _starts = <int>[];
  static Future<void>? _loading;

  static bool get loaded => _starts.isNotEmpty;

  /// Every chapter in the Bible, counted through (1,189).
  static int get total =>
      _starts.isEmpty ? 0 : _starts.last + books.last.chapters;

  static Future<void> load() => _loading ??= () async {
    final b = await rootBundle.loadString('assets/bible/books.tsv');
    books = b.trim().split('\n').skip(1).map((l) {
      final x = l.split('\t');
      return BibleBook(
        id: int.parse(x[0]),
        name: x[1],
        oldTestament: x[2] == 'old',
        chapters: int.parse(x[3]),
      );
    }).toList();
    final gz = await rootBundle.load('assets/bible/kjb.tsvz');
    _text.addAll(await compute(_parse, gz.buffer.asUint8List()));
    var n = 0;
    for (final bk in books) {
      _starts.add(n);
      n += bk.chapters;
    }
  }();

  static Map<int, List<List<String>>> _parse(Uint8List gz) {
    final out = <int, List<List<String>>>{};
    for (final l in utf8.decode(GZipCodec().decode(gz)).split('\n').skip(1)) {
      final x = l.split('\t');
      if (x.length < 4) continue;
      final b = int.parse(x[0]), c = int.parse(x[1]);
      final chapters = out.putIfAbsent(b, () => []);
      while (chapters.length < c) {
        chapters.add([]);
      }
      chapters[c - 1].add(x[3]);
    }
    return out;
  }

  static List<String> verses(int b, int c) =>
      (_text[b]?.length ?? 0) >= c && c > 0 ? _text[b]![c - 1] : const [];

  static BibleBook? bookOf(int b) =>
      b >= 1 && b <= books.length ? books[b - 1] : null;

  static String name(int b) => bookOf(b)?.name ?? '';

  /// A book by the name or abbreviation a reference gives it, any case:
  /// "Psalm", "Ps", "Psa.", "1 Co", "Song of Songs".
  static BibleBook? named(String raw) {
    final n = raw
        .trim()
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) return null;
    final alias = _aliases[n];
    if (alias != null) return books.where((x) => x.name == alias).firstOrNull;
    final want = n == 'psalm' ? 'psalms' : n;
    return books.where((x) => x.name.toLowerCase() == want).firstOrNull ??
        books.where((x) => x.name.toLowerCase().startsWith(want)).firstOrNull;
  }

  /// The abbreviations the reading plans use, and a few common others.
  static const _aliases = {
    'gen': 'Genesis',
    'ex': 'Exodus',
    'exod': 'Exodus',
    'lev': 'Leviticus',
    'num': 'Numbers',
    'deut': 'Deuteronomy',
    'josh': 'Joshua',
    'jdg': 'Judges',
    'judg': 'Judges',
    'rut': 'Ruth',
    '1 sa': '1 Samuel',
    '2 sa': '2 Samuel',
    '1 sam': '1 Samuel',
    '2 sam': '2 Samuel',
    '1 kgs': '1 Kings',
    '2 kgs': '2 Kings',
    '1 chr': '1 Chronicles',
    '2 chr': '2 Chronicles',
    'ezr': 'Ezra',
    'neh': 'Nehemiah',
    'est': 'Esther',
    'esth': 'Esther',
    'ps': 'Psalms',
    'psa': 'Psalms',
    'pro': 'Proverbs',
    'prov': 'Proverbs',
    'ecc': 'Ecclesiastes',
    'eccl': 'Ecclesiastes',
    'sos': 'Song of Solomon',
    'song': 'Song of Solomon',
    'song of songs': 'Song of Solomon',
    'canticles': 'Song of Solomon',
    'isa': 'Isaiah',
    'jer': 'Jeremiah',
    'lam': 'Lamentations',
    'eze': 'Ezekiel',
    'ezek': 'Ezekiel',
    'dan': 'Daniel',
    'hos': 'Hosea',
    'joe': 'Joel',
    'amo': 'Amos',
    'oba': 'Obadiah',
    'obad': 'Obadiah',
    'jon': 'Jonah',
    'mic': 'Micah',
    'nah': 'Nahum',
    'hab': 'Habakkuk',
    'zep': 'Zephaniah',
    'zeph': 'Zephaniah',
    'hag': 'Haggai',
    'zec': 'Zechariah',
    'zech': 'Zechariah',
    'mal': 'Malachi',
    'mat': 'Matthew',
    'matt': 'Matthew',
    'mk': 'Mark',
    'luk': 'Luke',
    'jn': 'John',
    'rom': 'Romans',
    '1 co': '1 Corinthians',
    '2 co': '2 Corinthians',
    '1 cor': '1 Corinthians',
    '2 cor': '2 Corinthians',
    'gal': 'Galatians',
    'eph': 'Ephesians',
    'phil': 'Philippians',
    'col': 'Colossians',
    '1 th': '1 Thessalonians',
    '2 th': '2 Thessalonians',
    '1 thess': '1 Thessalonians',
    '2 thess': '2 Thessalonians',
    '1 ti': '1 Timothy',
    '2 ti': '2 Timothy',
    '1 tim': '1 Timothy',
    '2 tim': '2 Timothy',
    'tit': 'Titus',
    'phlm': 'Philemon',
    'philem': 'Philemon',
    'heb': 'Hebrews',
    'jam': 'James',
    'jas': 'James',
    '1 pe': '1 Peter',
    '2 pe': '2 Peter',
    '1 pet': '1 Peter',
    '2 pet': '2 Peter',
    '1 jn': '1 John',
    '2 jn': '2 John',
    '3 jn': '3 John',
    'rev': 'Revelation',
  };

  /// "Psalm 112:7" or "John 3:16-18": book, chapter and first verse.
  static (int, int, int?)? ref(String r) {
    final m = RegExp(r'^\s*(.+?)\.?\s+(\d+)(?::(\d+))?').firstMatch(r);
    final b = m == null ? null : named(m.group(1)!);
    if (b == null) return null;
    final c = int.parse(m!.group(2)!);
    if (c < 1 || c > b.chapters) return null;
    return (b.id, c, int.tryParse(m.group(3) ?? ''));
  }

  /// A chapter's place counted through the whole Bible, from 0.
  static int index(int b, int c) =>
      _starts.isEmpty ? 0 : _starts[(b - 1).clamp(0, books.length - 1)] + c - 1;

  /// The book and chapter at a place counted through the whole Bible.
  static (int, int) at(int i) {
    var k = 0;
    while (k + 1 < _starts.length && _starts[k + 1] <= i) {
      k++;
    }
    return (books[k].id, i - _starts[k] + 1);
  }

  /// A plan's passage as the chapters it covers, any of them in part:
  /// "Gen 1-3", "Mat 2:19–3:17", "Heb 7:11–28", "2 Co 13:11–Gal 1:10", "Oba".
  static List<ChapterSpan> spans(String passage) {
    final out = <ChapterSpan>[];
    for (final raw in passage.split(';')) {
      final s = raw.trim().replaceAll(RegExp('[–—]'), '-');
      if (s.isEmpty) continue;
      final m = RegExp(r'^(\d?\s?[A-Za-z][A-Za-z ]*?\.?)\s*(\d.*)?$')
          .firstMatch(s);
      final book = m == null ? null : named(m.group(1)!);
      if (book == null) continue;
      final rest = (m!.group(2) ?? '').replaceAll(' ', '');
      if (rest.isEmpty) {
        for (var c = 1; c <= book.chapters; c++) {
          out.add(ChapterSpan(book.id, c));
        }
        continue;
      }
      final dash = rest.indexOf('-');
      final start = dash < 0 ? rest : rest.substring(0, dash);
      var end = dash < 0 ? '' : s.substring(s.indexOf('-') + 1).trim();
      final sp = start.split(':');
      final c1 = int.tryParse(sp[0]) ?? 1;
      final v1 = sp.length > 1 ? int.tryParse(sp[1]) : null;
      var endBook = book;
      int c2 = c1;
      int? v2;
      if (end.isNotEmpty) {
        final em = RegExp(r'^(?:(\d?\s?[A-Za-z]+\.?)\s+)?(\d+)(?::(\d+))?$')
            .firstMatch(end);
        if (em != null) {
          if (em.group(1) != null) endBook = named(em.group(1)!) ?? book;
          final a = int.parse(em.group(2)!);
          final b = int.tryParse(em.group(3) ?? '');
          if (b != null) {
            c2 = a;
            v2 = b;
          } else if (v1 != null && endBook.id == book.id) {
            v2 = a;
          } else {
            c2 = a;
          }
        }
      } else if (v1 != null) {
        v2 = v1;
      }
      // Through to another book: this one to its end, then any between, then the last
      for (var b = book.id; b <= endBook.id; b++) {
        final bk = bookOf(b)!;
        final from = b == book.id ? c1 : 1;
        final to = b == endBook.id ? c2 : bk.chapters;
        for (var c = from; c <= to && c <= bk.chapters; c++) {
          final fv = b == book.id && c == c1 ? v1 : null;
          final tv = b == endBook.id && c == c2 ? v2 : null;
          out.add(ChapterSpan(b, c, fv == 1 && tv == null ? null : fv, tv));
        }
      }
    }
    return out;
  }

  /// Spans in a readable line: neighbours in one book run together.
  /// [ChapterSpan(1,1), (1,2), (1,3)] is "Genesis 1–3".
  static String describe(List<ChapterSpan> spans, {bool short = false}) {
    if (spans.isEmpty) return '';
    final runs = <List<ChapterSpan>>[];
    for (final s in spans) {
      final last = runs.isEmpty ? null : runs.last.last;
      final joins =
          last != null &&
          last.book == s.book &&
          s.chapter == last.chapter + 1 &&
          last.to == null &&
          (s.from == null || s.from == 1);
      if (joins) {
        runs.last.add(s);
      } else {
        runs.add([s]);
      }
    }
    String nameOf(int b) {
      final n = bookOf(b)?.name ?? '';
      return short ? (_short[n] ?? n) : n;
    }

    return runs
        .map((r) {
          final a = r.first, z = r.last;
          final name = r.length == 1 && a.whole && nameOf(a.book) == 'Psalms'
              ? 'Psalm'
              : nameOf(a.book);
          final singleChapterBook = (bookOf(a.book)?.chapters ?? 0) == 1;
          if (a.from == null && z.to == null) {
            if (singleChapterBook) return name;
            return a.chapter == z.chapter
                ? '$name ${a.chapter}'
                : '$name ${a.chapter}–${z.chapter}';
          }
          final av = a.firstVerse(), zv = z.lastVerse();
          if (a.chapter == z.chapter) {
            return av == zv
                ? '$name ${a.chapter}:$av'
                : '$name ${a.chapter}:$av–$zv';
          }
          return '$name ${a.chapter}:$av–${z.chapter}:$zv';
        })
        .join('; ');
  }

  static const _short = {
    'Genesis': 'Gen.',
    'Exodus': 'Exod.',
    'Leviticus': 'Lev.',
    'Numbers': 'Num.',
    'Deuteronomy': 'Deut.',
    'Joshua': 'Josh.',
    'Judges': 'Judg.',
    '1 Samuel': '1 Sam.',
    '2 Samuel': '2 Sam.',
    '1 Chronicles': '1 Chron.',
    '2 Chronicles': '2 Chron.',
    'Nehemiah': 'Neh.',
    'Esther': 'Esth.',
    'Psalms': 'Psa.',
    'Proverbs': 'Prov.',
    'Ecclesiastes': 'Eccl.',
    'Song of Solomon': 'Song',
    'Isaiah': 'Isa.',
    'Jeremiah': 'Jer.',
    'Lamentations': 'Lam.',
    'Ezekiel': 'Ezek.',
    'Daniel': 'Dan.',
    'Obadiah': 'Obad.',
    'Habakkuk': 'Hab.',
    'Zephaniah': 'Zeph.',
    'Zechariah': 'Zech.',
    'Malachi': 'Mal.',
    'Matthew': 'Matt.',
    'Romans': 'Rom.',
    '1 Corinthians': '1 Cor.',
    '2 Corinthians': '2 Cor.',
    'Galatians': 'Gal.',
    'Ephesians': 'Eph.',
    'Philippians': 'Phil.',
    'Colossians': 'Col.',
    '1 Thessalonians': '1 Thess.',
    '2 Thessalonians': '2 Thess.',
    '1 Timothy': '1 Tim.',
    '2 Timothy': '2 Tim.',
    'Philemon': 'Philem.',
    'Hebrews': 'Heb.',
    '1 Peter': '1 Pet.',
    '2 Peter': '2 Pet.',
    'Revelation': 'Rev.',
  };

  /// A verse's words by its reference ("Psalm 112:7", "John 3:16-18"),
  /// with the reference as it's shown; null when it isn't one.
  static (String, String)? verse(String reference) {
    final r = ref(reference);
    if (r == null) return null;
    final vs = verses(r.$1, r.$2), from = r.$3 ?? 1;
    final to =
        int.tryParse(
          RegExp(r'[–-](\d+)\s*$').firstMatch(reference)?.group(1) ?? '',
        ) ??
        from;
    if (from > vs.length) return null;
    final text = [for (var n = from; n <= to && n <= vs.length; n++) vs[n - 1]]
        .join(' ');
    final book = bookOf(r.$1)!.singular;
    return ('$book ${r.$2}:$from${to > from ? '–$to' : ''}', text);
  }
}
