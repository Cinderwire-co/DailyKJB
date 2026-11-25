import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bible/kjb.dart';
import '../bible/study_data.dart';

/// Whether this phone can write with Apple Intelligence.
enum AiState {
  available, // ready to write, on the phone, with no connection
  notEligible, // the phone is too old (Apple Intelligence needs an iPhone 15 Pro or later)
  notEnabled, // Apple Intelligence is off in Settings
  notReady, // the model is still downloading
  unsupported, // an older iOS, or not an iPhone
  checking,
}

class WordNote {
  final String word, meaning;
  const WordNote(this.word, this.meaning);
}

class Truth {
  final String truth;
  final List<String> refs;
  const Truth(this.truth, this.refs);
}

/// Study notes on a verse, written on the phone.
class VerseInsight {
  final String setting, summary, application, gospel;
  final List<WordNote> words;
  final List<Truth> truths;

  const VerseInsight({
    required this.setting,
    required this.summary,
    required this.application,
    required this.gospel,
    required this.words,
    required this.truths,
  });

  Map<String, dynamic> toJson() => {
    'setting': setting,
    'summary': summary,
    'application': application,
    'gospel': gospel,
    'words': [
      for (final w in words) {'word': w.word, 'meaning': w.meaning},
    ],
    'truths': [
      for (final t in truths) {'truth': t.truth, 'refs': t.refs},
    ],
  };

  /// Only what's well formed, and only references that are in the Bible.
  static VerseInsight fromJson(Map<String, dynamic> j) {
    String s(Object? x, [int max = 700]) {
      final t = x is String ? x.trim() : '';
      return t.length > max ? t.substring(0, max) : t;
    }

    final words = <WordNote>[];
    for (final w in (j['words'] as List? ?? const [])) {
      if (w is! Map) continue;
      final word = s(w['word'], 80), meaning = s(w['meaning'], 300);
      if (word.isNotEmpty && meaning.isNotEmpty) {
        words.add(WordNote(word, meaning));
      }
    }
    final truths = <Truth>[];
    for (final t in (j['truths'] as List? ?? const [])) {
      if (t is! Map) continue;
      final truth = s(t['truth'], 300);
      if (truth.isEmpty) continue;
      final refs = <String>[
        for (final r in (t['refs'] as List? ?? const []))
          if (r is String && Kjb.verse(r) != null) Kjb.verse(r)!.$1,
      ];
      truths.add(Truth(truth, refs.take(3).toList()));
    }
    return VerseInsight(
      setting: s(j['setting']),
      summary: s(j['summary'], 900),
      application: s(j['application']),
      gospel: s(j['gospel']),
      words: words.take(5).toList(),
      truths: truths.take(4).toList(),
    );
  }
}

class AiQuestion {
  final String question;
  final List<String> choices;
  final int answer;
  final String reference;
  const AiQuestion(this.question, this.choices, this.answer, this.reference);
}

/// Apple Intelligence's on-device model (iOS 26 and later, on phones that
/// have it), for study notes, plain meanings of words, and quizzes. Nothing
/// leaves the phone. Where it isn't there, the app keeps to what it has in
/// itself: Strong's, Webster's 1828, cross references and the word quiz.
class AiService extends ChangeNotifier {
  AiService._();
  static final i = AiService._();

  static const _channel = MethodChannel('com.dailykjb/ai');

  AiState state = AiState.checking;
  bool enabled = true; // the reader's own choice, from settings

  bool get ready => enabled && state == AiState.available;

  String get statusText => switch (state) {
    AiState.available => 'Ready on this iPhone. Works offline.',
    AiState.notEligible => 'This device doesn\'t have Apple Intelligence (it needs an iPhone 15 Pro or later). The study tools below still work.',
    AiState.notEnabled =>
      'Turn on Apple Intelligence in Settings to use it here.',
    AiState.notReady => 'Apple Intelligence is still getting ready on this iPhone. Try again later.',
    AiState.unsupported => 'Needs iOS 26 or later on an iPhone with Apple Intelligence. The study tools below still work.',
    AiState.checking => 'Checking…',
  };

  Future<void> refresh() async {
    if (!Platform.isIOS) {
      state = AiState.unsupported;
      notifyListeners();
      return;
    }
    try {
      final r = await _channel.invokeMethod<String>('availability');
      state = switch (r) {
        'available' => AiState.available,
        'deviceNotEligible' => AiState.notEligible,
        'appleIntelligenceNotEnabled' => AiState.notEnabled,
        'modelNotReady' => AiState.notReady,
        _ => AiState.unsupported,
      };
    } catch (_) {
      state = AiState.unsupported;
    }
    notifyListeners();
  }

  Future<String?> _cached(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getString('ai:$key');
    } catch (_) {
      return null;
    }
  }

  Future<void> _keep(String key, String value) async {
    try {
      await (await SharedPreferences.getInstance()).setString('ai:$key', value);
    } catch (_) {}
  }

  Future<String> _call(String method, Map<String, dynamic> args) async {
    final r = await _channel
        .invokeMethod<String>(method, args)
        .timeout(const Duration(seconds: 120));
    if (r == null || r.trim().isEmpty) {
      throw Exception('Nothing came back. Try again.');
    }
    return r;
  }

  static String _json(String s) {
    final a = s.indexOf('{'), b = s.lastIndexOf('}');
    return a >= 0 && b > a ? s.substring(a, b + 1) : s;
  }

  /// Notes written before on this verse, if there are any.
  Future<VerseInsight?> explainVerseCached(VerseStudy v) async {
    final c = await _cached('verse:${v.book}:${v.chapter}:${v.verse}');
    if (c == null) return null;
    try {
      return VerseInsight.fromJson(jsonDecode(c) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Study notes on a verse. Written once, then kept.
  Future<VerseInsight> explainVerse(VerseStudy v, {bool fresh = false}) async {
    final key = 'verse:${v.book}:${v.chapter}:${v.verse}';
    if (!fresh) {
      final c = await _cached(key);
      if (c != null) {
        return VerseInsight.fromJson(jsonDecode(c) as Map<String, dynamic>);
      }
    }
    final around = Kjb.verses(v.book, v.chapter);
    final from = (v.verse - 3).clamp(1, around.length);
    final to = (v.verse + 2).clamp(1, around.length);
    final strongs = [
      for (final w in v.words.take(10))
        '"${w.text}": ${w.ids.map((id) {
          final d = v.dict[id];
          return d == null ? id : '${d.translit} (${_trim(d.definition, 110)})';
        }).join('; ')}',
    ];
    final r = await _call('explainVerse', {
      'reference': v.reference,
      'text': v.text,
      'context': [for (var n = from; n <= to; n++) '$n ${around[n - 1]}']
          .join('\n'),
      'strongs': strongs.join('\n'),
      'xrefs': [
        for (final x in v.xrefs.take(5))
          '${x.reference}: "${_trim(x.text, 160)}"',
      ].join('\n'),
    });
    final insight = VerseInsight.fromJson(
      jsonDecode(_json(r)) as Map<String, dynamic>,
    );
    await _keep(key, jsonEncode(insight.toJson()));
    return insight;
  }

  /// What a word means in this verse, in a sentence or two, from Strong's and
  /// Webster's 1828 together.
  Future<String> wordMeaning({
    required String word,
    required String reference,
    required String verse,
    required String strongs,
    required String webster,
  }) async {
    final key = 'word:$reference:${word.toLowerCase()}';
    final c = await _cached(key);
    if (c != null) return c;
    final r = (await _call('wordMeaning', {
      'word': word,
      'reference': reference,
      'verse': verse,
      'strongs': _trim(strongs, 600),
      'webster': _trim(webster, 900),
    })).trim();
    await _keep(key, r);
    return r;
  }

  /// A few questions on what was read, to check understanding.
  Future<List<AiQuestion>> quiz(String passage, String text) async {
    final r = await _call('quiz', {
      'passage': passage,
      'text': _trim(text, 6000),
    });
    final j = jsonDecode(_json(r)) as Map<String, dynamic>;
    final out = <AiQuestion>[];
    for (final q in (j['questions'] as List? ?? const [])) {
      if (q is! Map) continue;
      final choices = [
        for (final c in (q['choices'] as List? ?? const []))
          if (c is String && c.trim().isNotEmpty) c.trim(),
      ];
      final answer = (q['answer'] as num?)?.toInt() ?? -1;
      final question = (q['question'] as String? ?? '').trim();
      if (question.isEmpty || choices.length < 2) continue;
      if (answer < 0 || answer >= choices.length) continue;
      final ref = q['reference'] is String
          ? Kjb.verse(q['reference'])?.$1
          : null;
      out.add(AiQuestion(question, choices, answer, ref ?? ''));
    }
    if (out.isEmpty) throw Exception("The questions didn't come out right.");
    return out;
  }

  static String _trim(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  @visibleForTesting
  void debugSet(AiState s) {
    state = s;
    notifyListeners();
  }
}
