import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../bible/kjb.dart';
import '../bible/study_data.dart';
import '../screenshots.dart';
import '../services/ai_service.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'reader.dart' show openInBible;

typedef OpenAt = void Function(int book, int chapter, [int? verse]);

/// A verse to study: each word underlined to tap for the Hebrew or Greek
/// behind it (Strong's) and what it meant in 1828 (Webster's), together; its
/// cross references; and, on an iPhone with Apple Intelligence, study notes
/// written on the phone. All of it works with no connection.
class VerseStudyScreen extends StatefulWidget {
  const VerseStudyScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
    this.onOpen,
  });

  final int book, chapter, verse;
  final OpenAt? onOpen;

  @override
  State<VerseStudyScreen> createState() => _VerseStudyScreenState();
}

class _VerseStudyScreenState extends State<VerseStudyScreen> {
  VerseStudy? _s;
  late int _verse = widget.verse;
  int? _pick; // the word whose sheet is open, by its place in the verse
  bool _allRefs = false;
  VerseInsight? _insight;
  bool _writing = false;
  String _error = '';
  final _taps = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _s = null;
      _insight = null;
      _error = '';
      _allRefs = false;
    });
    final s = await StudyData.verse(widget.book, widget.chapter, _verse);
    if (!mounted) return;
    setState(() => _s = s);
    final w = Screenshots.openWord;
    if (w != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _word(w));
    }
    // Notes written before come back at once
    if (AiService.i.ready) {
      Screenshots.scene == 'notes' ? _explain() : _explain(cachedOnly: true);
    }
  }

  Future<void> _explain({bool cachedOnly = false, bool fresh = false}) async {
    final s = _s;
    if (s == null) return;
    if (!cachedOnly) {
      setState(() {
        _writing = true;
        _error = '';
      });
    }
    try {
      if (cachedOnly) {
        // Only what's kept: explainVerse would write them otherwise
        final kept = await AiService.i.explainVerseCached(s);
        if (mounted && kept != null) setState(() => _insight = kept);
        return;
      }
      final r = await AiService.i.explainVerse(s, fresh: fresh);
      if (mounted) setState(() => _insight = r);
    } catch (e) {
      if (mounted && !cachedOnly) {
        setState(
          () => _error = "Apple Intelligence couldn't write notes just now. Try again in a moment.",
        );
      }
    } finally {
      if (mounted && !cachedOnly) setState(() => _writing = false);
    }
  }

  void _step(int by) {
    final n = Kjb.verses(widget.book, widget.chapter).length;
    final v = (_verse + by).clamp(1, n);
    if (v == _verse) return;
    HapticFeedback.selectionClick();
    _verse = v;
    _load();
  }

  int _part(int i) {
    final at = _s?.at ?? const [];
    return i >= 0 && i < at.length ? at[i] : -1;
  }

  List<int> _group(int i, int n) => _part(i) < 0
      ? [i]
      : [
          for (var j = 0; j < n; j++)
            if (_part(j) == _part(i)) j,
        ];

  TapGestureRecognizer _tap(int i) {
    while (_taps.length <= i) {
      final k = _taps.length;
      _taps.add(TapGestureRecognizer()..onTap = () => _word(k));
    }
    return _taps[i];
  }

  // To a verse in the Bible: back to the page this came from, which opens it;
  // or, from elsewhere, to the Bible tab
  void _open(int b, int c, [int? v]) {
    final go = widget.onOpen;
    if (go == null) {
      openInBible(context, b, c, v);
      return;
    }
    Navigator.of(context).pop();
    go(b, c, v);
  }

  Future<void> _word(int i) async {
    final s = _s;
    if (s == null) return;
    final words = s.text.split(' ');
    if (i >= words.length) return;
    final look = i < s.look.length && s.look[i].isNotEmpty
        ? s.look[i]
        : words[i].replaceAll(RegExp(r"[^A-Za-z'-]"), '');
    if (look.isEmpty) return;
    HapticFeedback.selectionClick();
    final p = _part(i);
    final strong = p >= 0 && p < s.words.length ? s.words[p] : null;
    final phrase = _group(
      i,
      words.length,
    ).map((j) => words[j].replaceAll(RegExp(r"[^A-Za-z'’-]"), '')).join(' ');
    setState(() => _pick = i);
    await sheet(
      context,
      title: phrase,
      body: (ctx) => WordSheet(
        word: look,
        phrase: phrase,
        strong: strong,
        study: s,
        onRef: (b, c, v) {
          Navigator.pop(ctx);
          _open(b, c, v);
        },
      ),
    );
    if (mounted) setState(() => _pick = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final s = _s;
    final ref =
        '${Kjb.bookOf(widget.book)?.singular ?? ''} ${widget.chapter}:$_verse';
    final count = Kjb.verses(widget.book, widget.chapter).length;
    return Leaf(
      title: ref,
      actions: [
        Tap(
          onTap: _verse > 1 ? () => _step(-1) : null,
          padding: const EdgeInsets.all(10),
          semantics: 'Verse before',
          child: Icon(CupertinoIcons.chevron_up, size: 20, color: p.inkStrong),
        ),
        Tap(
          onTap: _verse < count ? () => _step(1) : null,
          padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
          semantics: 'Next verse',
          child: Icon(
            CupertinoIcons.chevron_down,
            size: 20,
            color: p.inkStrong,
          ),
        ),
      ],
      body: s == null
          ? const Waiting()
          : ListenableBuilder(
              listenable: AiService.i,
              builder: (context, _) => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  MediaQuery.paddingOf(context).bottom + 40,
                ),
                children: [
                  _verseText(s),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: p.accentSoft.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: p.accent.withValues(alpha: .4)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.hand_point_right,
                          color: p.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap any word for the Hebrew or Greek behind it, and what it meant in 1828',
                            style: p.small.copyWith(color: p.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._notesSection(s),
                  if (s.words.isNotEmpty)
                    _section('Words in the original', _originals(s)),
                  if (s.xrefs.isNotEmpty)
                    _section('Cross references', _xrefs(s)),
                  const SizedBox(height: 26),
                  Text(
                    "Strong's Exhaustive Concordance (1894). Noah Webster, An American Dictionary of the English Language (1828). Cross references from OpenBible.info.",
                    style: p.small.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Label(label), const SizedBox(height: 10), child],
    ),
  );

  // Each word underlined to tap; the words of one Strong's word underline and
  // light as one, the space between them too
  Widget _verseText(VerseStudy s) {
    final p = context.parch;
    final words = s.text.split(' ');
    final lit = _pick == null ? const <int>[] : _group(_pick!, words.length);
    final style = TextStyle(
      fontFamily: Parchment.serif,
      fontSize: 23,
      height: 1.6,
      color: p.inkStrong,
    );
    final line = TextStyle(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: p.accent.withValues(alpha: .8),
      decorationThickness: 1.6,
    );
    final on = line.copyWith(
      decorationStyle: TextDecorationStyle.solid,
      decorationColor: p.accent,
      backgroundColor: p.accent.withValues(alpha: .2),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.rubric, width: 2)),
      ),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            for (final (i, w) in words.indexed) ...[
              TextSpan(
                text: w,
                style: lit.contains(i) ? on : line,
                recognizer: _tap(i),
              ),
              if (i < words.length - 1)
                TextSpan(
                  text: ' ',
                  style: _part(i) >= 0 && _part(i) == _part(i + 1)
                      ? (lit.contains(i) ? on : line)
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _notesSection(VerseStudy s) {
    final p = context.parch;
    final ai = AiService.i;
    // Too old a phone, or not an iPhone: nothing here at all
    if (ai.state == AiState.notEligible ||
        ai.state == AiState.unsupported ||
        ai.state == AiState.checking) {
      return const [];
    }
    if (!ai.enabled) return const [];
    if (ai.state != AiState.available) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            children: [
              Icon(CupertinoIcons.sparkles, size: 18, color: p.faded),
              const SizedBox(width: 10),
              Expanded(child: Text(ai.statusText, style: p.small)),
            ],
          ),
        ),
      ];
    }
    final n = _insight;
    return [
      _section(
        'Notes on this verse',
        n == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_writing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Waiting(
                        text: 'Writing study notes on this device…',
                      ),
                    )
                  else
                    ParchButton(
                      'Explain this verse',
                      icon: CupertinoIcons.sparkles,
                      kind: Btn.solid,
                      expand: true,
                      onTap: () => _explain(),
                    ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error,
                        style: p.small.copyWith(color: p.danger),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Written by Apple Intelligence on this device, from the King James text and Strong\'s. Nothing leaves it.',
                    style: p.small.copyWith(fontSize: 13),
                  ),
                ],
              )
            : _insightView(n),
      ),
    ];
  }

  Widget _insightView(VerseInsight n) {
    final p = context.parch;
    Widget part(String label, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: p.small.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: p.body),
              ],
            ),
          );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          part('The setting', n.setting),
          part('What it says', n.summary),
          if (n.words.isNotEmpty) ...[
            Text(
              'Words to know',
              style: p.small.copyWith(
                color: p.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final w in n.words)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${w.word}: ',
                        style: p.strong.copyWith(fontSize: 16),
                      ),
                      TextSpan(
                        text: w.meaning,
                        style: p.body.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          if (n.truths.isNotEmpty) ...[
            Text(
              'Truths',
              style: p.small.copyWith(
                color: p.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final t in n.truths)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.truth, style: p.body.copyWith(fontSize: 16)),
                    if (t.refs.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        children: [
                          for (final r in t.refs)
                            Tap(
                              onTap: () {
                                final x = Kjb.ref(r);
                                if (x != null) _open(x.$1, x.$2, x.$3);
                              },
                              child: Text(
                                r,
                                style: p.small.copyWith(color: p.accent),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
          part('For today', n.application),
          part('The Gospel in it', n.gospel),
          const Hairline(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(CupertinoIcons.sparkles, size: 14, color: p.faded),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Written on this device by Apple Intelligence. Weigh it against the Bible.',
                  style: p.small.copyWith(fontSize: 12.5),
                ),
              ),
              Tap(
                onTap: _writing ? null : () => _explain(fresh: true),
                padding: const EdgeInsets.all(4),
                child: Label('Again', color: p.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _originals(VerseStudy s) {
    final p = context.parch;
    final words = s.text.split(' ');
    return Column(
      children: [
        for (final (k, w) in s.words.indexed)
          if (w.ids.any((id) => s.dict[id] != null))
            Tap(
              onTap: () {
                final i = s.at.indexOf(k);
                if (i >= 0 && i < words.length) _word(i);
              },
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(w.text, style: p.strong.copyWith(fontSize: 16)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final id in w.ids)
                          if (s.dict[id] != null)
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${s.dict[id]!.translit}  ',
                                    style: p.body.copyWith(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 16,
                                      color: p.inkStrong,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _short(s.dict[id]!.definition),
                                    style: p.small,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, size: 13, color: p.faded),
                ],
              ),
            ),
      ],
    );
  }

  static String _short(String d) {
    final t = d.replaceAll(RegExp(r'[{}]'), '');
    return t.length > 120 ? '${t.substring(0, 120)}…' : t;
  }

  Widget _xrefs(VerseStudy s) {
    final p = context.parch;
    final list = _allRefs ? s.xrefs : s.xrefs.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final x in list)
          Tap(
            onTap: () => _open(x.book, x.chapter, x.verse),
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  x.reference,
                  style: p.small.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(x.text, style: p.body.copyWith(fontSize: 16.5)),
              ],
            ),
          ),
        if (s.xrefs.length > 6 && !_allRefs)
          Tap(
            onTap: () => setState(() => _allRefs = true),
            padding: const EdgeInsets.all(6),
            child: Label('All ${s.xrefs.length}', color: p.accent),
          ),
      ],
    );
  }
}

/// A word of a verse: the Hebrew or Greek behind it (Strong's), what the
/// English meant in 1828 (Webster's), and on an iPhone with Apple
/// Intelligence, its meaning here in plain words.
class WordSheet extends StatefulWidget {
  const WordSheet({
    super.key,
    required this.word,
    required this.phrase,
    required this.strong,
    required this.study,
    this.onRef,
  });

  final String word; // to find in Webster's
  final String phrase; // as the verse has it
  final StrongsWord? strong;
  final VerseStudy study;
  final void Function(int book, int chapter, int verse)? onRef;

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  WebsterResult? _w;
  String? _plain;
  bool _plainBusy = false;

  @override
  void initState() {
    super.initState();
    StudyData.webster(widget.word).then((r) {
      if (!mounted) return;
      setState(() => _w = r);
      if (AiService.i.ready) _meaning();
    });
  }

  Future<void> _meaning() async {
    setState(() => _plainBusy = true);
    final strong = widget.strong;
    final dict = widget.study.dict;
    final strongs = strong == null
        ? ''
        : strong.ids
              .where((id) => dict[id] != null)
              .map(
                (id) =>
                    '${dict[id]!.translit}: ${dict[id]!.definition} (in the King James: ${dict[id]!.kjv})',
              )
              .join('\n');
    final webster = (_w?.entries ?? const [])
        .take(2)
        .map((e) => StudyData.plainText(e.html))
        .join('\n');
    try {
      final r = await AiService.i.wordMeaning(
        word: widget.phrase,
        reference: widget.study.reference,
        verse: widget.study.text,
        strongs: strongs,
        webster: webster,
      );
      if (mounted) setState(() => _plain = r);
    } catch (_) {
      if (mounted) setState(() => _plain = '');
    } finally {
      if (mounted) setState(() => _plainBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final w = _w, strong = widget.strong, dict = widget.study.dict;
    Widget head(String label, String source) => Row(
      children: [
        Label(label),
        const Spacer(),
        Text(source, style: p.small.copyWith(fontSize: 13)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (AiService.i.ready && (_plainBusy || (_plain ?? '').isNotEmpty)) ...[
          head('In plain words', 'Apple Intelligence'),
          const SizedBox(height: 6),
          if (_plainBusy)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Thinking it through on this device…', style: p.small),
              ],
            )
          else
            Text(_plain!, style: p.body.copyWith(color: p.inkStrong)),
          Container(
            height: 1,
            color: p.rule,
            margin: const EdgeInsets.symmetric(vertical: 14),
          ),
        ],
        if (strong != null)
          for (final id in strong.ids)
            if (dict[id] != null) ...[
              head(
                dict[id]!.hebrew ? 'The Hebrew' : 'The Greek',
                "Strong's $id",
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: dict[id]!.word,
                      style: p
                          .title(24)
                          .copyWith(fontFamily: null, letterSpacing: 0),
                    ),
                    TextSpan(
                      text: '   ${dict[id]!.translit}',
                      style: p.body.copyWith(
                        fontStyle: FontStyle.italic,
                        color: p.inkStrong,
                      ),
                    ),
                    TextSpan(text: '   ${dict[id]!.pronounce}', style: p.small),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dict[id]!.definition.replaceAll(RegExp(r'[{}]'), ''),
                style: p.body,
              ),
              if (dict[id]!.kjv.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'In the King James: ${dict[id]!.kjv}',
                    style: p.small,
                  ),
                ),
              Container(
                height: 1,
                color: p.rule,
                margin: const EdgeInsets.symmetric(vertical: 14),
              ),
            ],
        head(
          'In 1828',
          w != null && w.as != null && w.as != widget.word
              ? "Webster's: ${w.as}"
              : "Webster's",
        ),
        const SizedBox(height: 6),
        if (w == null)
          const Padding(padding: EdgeInsets.all(20), child: Waiting())
        else if (w.entries.isEmpty)
          Text(
            "This word isn't in Webster's 1828 as it's spelled here.",
            style: p.small,
          )
        else
          for (final e in w.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WebsterText(html: e.html, onRef: widget.onRef),
            ),
        const SizedBox(height: 6),
        Text(
          "Strong's Exhaustive Concordance (1894). Noah Webster, An American Dictionary of the English Language (1828).",
          style: p.small.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

/// A Webster's entry: its light HTML (paragraphs, bold, italic, Bible links)
/// as text, the Bible references a tap away.
class WebsterText extends StatefulWidget {
  const WebsterText({super.key, required this.html, this.onRef});
  final String html;
  final void Function(int book, int chapter, int verse)? onRef;

  @override
  State<WebsterText> createState() => _WebsterTextState();
}

class _WebsterTextState extends State<WebsterText> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final base = p.body.copyWith(fontSize: 16, height: 1.5);
    final paragraphs = widget.html
        .replaceAll('<br>', '\n')
        .split(RegExp(r'</p>\s*'))
        .map((x) => x.replaceAll('<p>', '').trim())
        .where((x) => x.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final para in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text.rich(TextSpan(style: base, children: _spans(para, p))),
          ),
      ],
    );
  }

  List<InlineSpan> _spans(String html, Parchment p) {
    final out = <InlineSpan>[];
    var bold = false, italic = false;
    String? href;
    final tag = RegExp(r'<(/?)(b|i|a)(?:\s+href="([^"]*)")?\s*>');
    var at = 0;
    void text(String t) {
      if (t.isEmpty) return;
      t = t
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
      TapGestureRecognizer? rec;
      final link = href;
      if (link != null && widget.onRef != null) {
        final ref = Uri.decodeComponent(
          Uri.tryParse(link)?.queryParameters['ref'] ?? '',
        );
        final r = Kjb.ref(ref);
        if (r != null) {
          rec = TapGestureRecognizer()
            ..onTap = () => widget.onRef!(r.$1, r.$2, r.$3 ?? 1);
          _taps.add(rec);
        }
      }
      out.add(
        TextSpan(
          text: t,
          recognizer: rec,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : null,
            fontStyle: italic ? FontStyle.italic : null,
            color: link != null ? p.accent : null,
          ),
        ),
      );
    }

    for (final m in tag.allMatches(html)) {
      text(html.substring(at, m.start));
      final close = m.group(1) == '/';
      switch (m.group(2)) {
        case 'b':
          bold = !close;
        case 'i':
          italic = !close;
        case 'a':
          href = close ? null : m.group(3);
      }
      at = m.end;
    }
    text(html.substring(at).replaceAll(RegExp('<[^>]+>'), ''));
    return out;
  }
}
