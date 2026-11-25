import 'dart:convert';
import 'dart:io' show GZipCodec;

import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/services.dart' show rootBundle;

import 'kjb.dart';

/// A word of Strong's Hebrew or Greek dictionary.
class StrongsEntry {
  final String id; // H1254, G26
  final String word; // the Hebrew or Greek
  final String translit;
  final String pronounce;
  final String definition;
  final String kjv; // how the King James renders it

  const StrongsEntry(
    this.id,
    this.word,
    this.translit,
    this.pronounce,
    this.definition,
    this.kjv,
  );

  bool get hebrew => id.startsWith('H');
}

/// One of a verse's words (or phrases) and the Strong's numbers behind it.
class StrongsWord {
  final String text; // "the heaven"
  final List<String> ids; // ["H8064"]
  const StrongsWord(this.text, this.ids);
}

/// A Webster's 1828 entry, its body in the dictionary's light HTML.
class WebsterEntry {
  final String heading;
  final String html;
  const WebsterEntry(this.heading, this.html);
}

class WebsterResult {
  final String word; // as asked
  final String? as; // the form found ("say" for "saith")
  final List<WebsterEntry> entries;
  const WebsterResult(this.word, this.as, this.entries);
}

class CrossRef {
  final int book, chapter, verse, end;
  const CrossRef(this.book, this.chapter, this.verse, this.end);

  String get reference {
    final b = Kjb.bookOf(book)?.singular ?? '';
    return end > verse ? '$b $chapter:$verse–$end' : '$b $chapter:$verse';
  }

  String get text {
    final vs = Kjb.verses(book, chapter);
    return [for (var n = verse; n <= end && n <= vs.length; n++) vs[n - 1]]
        .join(' ');
  }
}

/// A verse ready to study: its words, which Strong's word each is part of,
/// and the word to look up in Webster's for each.
class VerseStudy {
  final int book, chapter, verse;
  final String text;
  final List<StrongsWord> words;
  final Map<String, StrongsEntry> dict;

  /// For each word of [text] split on spaces: the index in [words] it's part
  /// of, or -1.
  final List<int> at;

  /// For each word of [text]: the word to find in Webster's (for a little
  /// word, the plainer word beside it: "the" in "the heaven" looks up heaven).
  final List<String> look;
  final List<CrossRef> xrefs;

  const VerseStudy({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.words,
    required this.dict,
    required this.at,
    required this.look,
    required this.xrefs,
  });

  String get reference => '${Kjb.bookOf(book)?.singular ?? ''} $chapter:$verse';
}

/// Strong's, Webster's 1828 and cross references, all in the app (assets/study),
/// so word study works with no connection. Each is split into small files
/// (by book, by letter) so a lookup only opens the one it needs.
class StudyData {
  StudyData._();

  static Map<String, StrongsEntry>? _strongs;
  static Future<Map<String, StrongsEntry>>? _strongsLoading;
  static final _words = <int, Future<Map<int, List<StrongsWord>>>>{};
  static final _xrefs = <int, Future<Map<int, List<CrossRef>>>>{};
  static final _webster = <String, Future<Map<String, List<WebsterEntry>>>>{};

  // The Hebrew object marker and the Greek article: nothing to study alone
  static const _bare = {'H853', 'G3588'};

  static Future<String> _gunzip(String asset) async {
    final data = await rootBundle.load(asset);
    return compute(_decode, data.buffer.asUint8List());
  }

  static String _decode(Uint8List gz) => utf8.decode(GZipCodec().decode(gz));

  static Future<Map<String, StrongsEntry>> strongs() async {
    if (_strongs != null) return _strongs!;
    return _strongsLoading ??= () async {
      final text = await _gunzip('assets/study/strongs.tsv.gz');
      final out = <String, StrongsEntry>{};
      for (final l in text.split('\n').skip(1)) {
        final x = l.split('\t');
        if (x.length < 6) continue;
        out[x[0]] = StrongsEntry(x[0], x[1], x[2], x[3], x[4], x[5]);
      }
      return _strongs = out;
    }();
  }

  static int _key(int c, int v) => c * 1000 + v;

  static Future<Map<int, List<StrongsWord>>> _wordsOf(int book) =>
      _words[book] ??= () async {
        final text = await _gunzip('assets/study/words/$book.tsv.gz');
        final out = <int, List<StrongsWord>>{};
        for (final l in text.split('\n').skip(1)) {
          final x = l.split('\t');
          if (x.length < 3) continue;
          final list = (jsonDecode(x[2]) as List)
              .map((w) {
                final pair = w as List;
                return StrongsWord(
                  pair[0] as String,
                  (pair[1] as String)
                      .split(' ')
                      .where((i) => i.isNotEmpty && !_bare.contains(i))
                      .toList(),
                );
              })
              .where((w) => w.ids.isNotEmpty)
              .toList();
          out[_key(int.parse(x[0]), int.parse(x[1]))] = list;
        }
        return out;
      }();

  static Future<Map<int, List<CrossRef>>> _xrefsOf(int book) =>
      _xrefs[book] ??= () async {
        final text = await _gunzip('assets/study/xrefs/$book.tsv.gz');
        final out = <int, List<CrossRef>>{};
        for (final l in text.split('\n').skip(1)) {
          final x = l.split('\t');
          if (x.length < 7) continue;
          out
              .putIfAbsent(_key(int.parse(x[0]), int.parse(x[1])), () => [])
              .add(
                CrossRef(
                  int.parse(x[2]),
                  int.parse(x[3]),
                  int.parse(x[4]),
                  int.parse(x[5]),
                ),
              );
        }
        return out;
      }();

  /// Everything the study page shows for a verse, from the app alone.
  static Future<VerseStudy> verse(int book, int chapter, int verse) async {
    await Kjb.load();
    final vs = Kjb.verses(book, chapter);
    final text = verse >= 1 && verse <= vs.length ? vs[verse - 1] : '';
    final results = await Future.wait([
      _wordsOf(book).catchError((_) => <int, List<StrongsWord>>{}),
      _xrefsOf(book).catchError((_) => <int, List<CrossRef>>{}),
      strongs().catchError((_) => <String, StrongsEntry>{}),
    ]);
    final words =
        (results[0] as Map<int, List<StrongsWord>>)[_key(chapter, verse)] ??
        const <StrongsWord>[];
    final xrefs =
        (results[1] as Map<int, List<CrossRef>>)[_key(chapter, verse)] ??
        const <CrossRef>[];
    final all = results[2] as Map<String, StrongsEntry>;
    final dict = <String, StrongsEntry>{
      for (final w in words)
        for (final id in w.ids)
          if (all[id] != null) id: all[id]!,
    };
    final (at, look) = align(text, words);
    return VerseStudy(
      book: book,
      chapter: chapter,
      verse: verse,
      text: text,
      words: words,
      dict: dict,
      at: at,
      look: look,
      xrefs: xrefs,
    );
  }

  static const _little = {
    'a',
    'an',
    'the',
    'of',
    'in',
    'into',
    'to',
    'unto',
    'and',
    'for',
    'by',
    'with',
    'upon',
    'on',
    'at',
    'from',
    'his',
    'her',
    'my',
    'thy',
    'thine',
    'mine',
    'our',
    'their',
    'its',
    'your',
    'ye',
    'i',
    'he',
    'she',
    'it',
    'we',
    'they',
    'thou',
    'me',
    'him',
    'them',
    'us',
    'shall',
    'will',
    'not',
    'be',
    'is',
    'was',
    'are',
    'were',
    'that',
    'which',
    'who',
    'whom',
    'this',
    'these',
    'those',
    'as',
    'so',
    'but',
    'or',
    'nor',
    'then',
  };

  static String _plain(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[’']s$"), '')
      .replaceAll(RegExp('[^a-z]'), '');

  /// Each word of the verse (split on spaces) with the Strong's word it's part
  /// of, and the word to look up in Webster's for it. The Strong's words come
  /// in the verse's order, nearly always together; across the Bible 99.8% of
  /// them land (the rest are Psalm titles, which aren't in the verse).
  static (List<int>, List<String>) align(String text, List<StrongsWord> words) {
    final toks = text.split(' ').map(_plain).toList();
    final at = List<int>.filled(toks.length, -1);
    var from = 0;
    for (var k = 0; k < words.length; k++) {
      final p = words[k].text
          .split(RegExp(r'\s+'))
          .map(_plain)
          .where((x) => x.isNotEmpty)
          .toList();
      if (p.isEmpty) continue;
      bool free(int i) {
        for (var j = 0; j < p.length; j++) {
          if (toks[i + j] != p[j] || at[i + j] >= 0) return false;
        }
        return true;
      }

      var i = -1;
      for (var s = from; s + p.length <= toks.length && i < 0; s++) {
        if (free(s)) i = s;
      }
      for (var s = 0; s + p.length <= toks.length && i < 0; s++) {
        if (free(s)) i = s;
      }
      if (i >= 0) {
        for (var j = 0; j < p.length; j++) {
          at[i + j] = k;
        }
        from = i + p.length;
        continue;
      }
      var last = from;
      for (final x in p) {
        var f = -1;
        for (var s = last; s < toks.length && f < 0; s++) {
          if (toks[s] == x && at[s] < 0) f = s;
        }
        for (var s = 0; s < toks.length && f < 0; s++) {
          if (toks[s] == x && at[s] < 0) f = s;
        }
        if (f >= 0) {
          at[f] = k;
          last = f + 1;
        }
      }
      if (last > from) from = last;
    }
    final look = <String>[];
    for (var i = 0; i < toks.length; i++) {
      final t = toks[i];
      if (!_little.contains(t) || at[i] < 0) {
        look.add(t);
        continue;
      }
      String? main;
      for (var j = 0; j < toks.length; j++) {
        if (at[j] == at[i] && !_little.contains(toks[j])) main = toks[j];
      }
      look.add(main ?? t);
    }
    return (at, look);
  }

  static Future<Map<String, List<WebsterEntry>>> _websterOf(String letter) =>
      _webster[letter] ??= () async {
        final text = await _gunzip('assets/study/webster/$letter.tsv.gz');
        final out = <String, List<WebsterEntry>>{};
        for (final l in text.split('\n').skip(1)) {
          final t1 = l.indexOf('\t');
          if (t1 < 0) continue;
          final t2 = l.indexOf('\t', t1 + 1);
          if (t2 < 0) continue;
          out
              .putIfAbsent(l.substring(0, t1), () => [])
              .add(WebsterEntry(l.substring(t1 + 1, t2), l.substring(t2 + 1)));
        }
        return out;
      }();

  /// A word in Webster's 1828: as it stands, else as the King James forms it
  /// from a plainer word (goeth, knoweth, saith, loved, lovest, believing).
  static Future<WebsterResult> webster(String word) async {
    final w = word
        .toLowerCase()
        .replaceAll(RegExp(r"[’']s$"), '')
        .replaceAll(RegExp('[^a-z-]'), '');
    if (w.isEmpty) return WebsterResult(word, null, const []);
    final tries = <String>[w];
    void add(String x) {
      if (x.length > 1 && !tries.contains(x)) tries.add(x);
    }

    if (w == 'saith' || w == 'sayeth') add('say');
    if (w == 'doth' || w == 'doeth') add('do');
    if (w == 'hath') add('have');
    if (w == 'art' || w == 'wast' || w == 'wert') add('be');
    if (w == 'spake') add('speak');
    if (w == 'shew' || w == 'shewed' || w == 'sheweth') add('show');
    const endings = [
      ['eth', ''],
      ['eth', 'e'],
      ['est', ''],
      ['est', 'e'],
      ['edst', ''],
      ['edst', 'e'],
      ['ieth', 'y'],
      ['iest', 'y'],
      ['ied', 'y'],
      ['ies', 'y'],
      ['ed', ''],
      ['ed', 'e'],
      ['ing', ''],
      ['ing', 'e'],
      ['es', ''],
      ['s', ''],
      ['st', ''],
      ['th', ''],
    ];
    for (final e in endings) {
      if (w.endsWith(e[0]) && w.length - e[0].length >= 2) {
        add(w.substring(0, w.length - e[0].length) + e[1]);
      }
    }
    // A doubled last letter before the ending: sinned, beginneth
    for (final t in [...tries]) {
      if (t.length > 2 && t[t.length - 1] == t[t.length - 2]) {
        add(t.substring(0, t.length - 1));
      }
    }
    Future<List<WebsterEntry>> find(String t) async {
      final first = t[0];
      final letter = first.compareTo('a') >= 0 && first.compareTo('z') <= 0
          ? first
          : '_';
      final map = await _websterOf(letter)
          .catchError((_) => <String, List<WebsterEntry>>{});
      return (map[t] ?? const <WebsterEntry>[]).take(4).toList();
    }

    for (var i = 0; i < tries.length; i++) {
      final rows = await find(tries[i]);
      if (rows.isEmpty) continue;
      // A form with only a line of its own (LOVED) brings the plainer word with it
      if (rows.fold<int>(0, (n, r) => n + r.html.length) < 300) {
        for (final u in tries.skip(i + 1)) {
          final more = await find(u);
          if (more.isNotEmpty) {
            return WebsterResult(word, tries[i], [...rows, ...more.take(3)]);
          }
        }
      }
      return WebsterResult(word, tries[i], rows);
    }
    return WebsterResult(word, null, const []);
  }

  /// Plain text of an entry, for the on-device model.
  static String plainText(String html) => html
      .replaceAll(RegExp(r'</p>\s*<p>'), '\n')
      .replaceAll(RegExp('<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .trim();
}
