import 'dart:async';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bible/kjb.dart';
import '../providers/app_provider.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

class _Hit {
  final int book, chapter, verse;
  final String text;
  const _Hit(this.book, this.chapter, this.verse, this.text);
}

/// Search the whole Bible, on the phone: words (all of them, anywhere in the
/// verse), "a phrase in quotes", or a reference to go straight to.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onOpen});
  final void Function(int book, int chapter, [int? verse]) onOpen;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _historyKey = 'bible_search_history';
  final _q = TextEditingController();
  Timer? _wait;
  List<_Hit> _hits = [];
  int _total = 0;
  String _where = 'all'; // all, old, new
  List<String> _history = [];
  List<RegExp> _terms = [];
  (int, int, int?)? _goTo;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final j = p.getString(_historyKey);
      if (j != null && mounted) {
        setState(() => _history = List<String>.from(jsonDecode(j)));
      }
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _remember(String q) async {
    _history
      ..remove(q)
      ..insert(0, q);
    if (_history.length > 20) _history = _history.sublist(0, 20);
    final p = await SharedPreferences.getInstance();
    await p.setString(_historyKey, jsonEncode(_history));
  }

  void _changed(String _) {
    _wait?.cancel();
    _wait = Timer(
      const Duration(milliseconds: 280),
      () => _search(remember: false),
    );
  }

  void _search({bool remember = true}) {
    final q = _q.text.trim();
    if (q.isEmpty) {
      setState(() {
        _hits = [];
        _total = 0;
        _goTo = null;
        _searched = false;
      });
      return;
    }
    // A reference: "John 3:16", "ps 23"
    final r = Kjb.ref(q);
    // Words, and phrases in quotes, each matched as whole words
    final phrases = RegExp(r'"([^"]+)"')
        .allMatches(q)
        .map((m) => m.group(1)!)
        .toList();
    final rest = q.replaceAll(RegExp(r'"[^"]*"'), ' ');
    final words = rest
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r"[^A-Za-z'-]"), ''))
        .where((w) => w.length > 1)
        .toList();
    final terms = [
      for (final ph in phrases)
        RegExp('\\b${RegExp.escape(ph.trim())}\\b', caseSensitive: false),
      for (final w in words)
        RegExp('\\b${RegExp.escape(w)}\\b', caseSensitive: false),
    ];
    final hits = <_Hit>[];
    var total = 0;
    if (terms.isNotEmpty) {
      for (final b in Kjb.books) {
        if (_where == 'old' && !b.oldTestament ||
            _where == 'new' && b.oldTestament) {
          continue;
        }
        for (var c = 1; c <= b.chapters; c++) {
          final vs = Kjb.verses(b.id, c);
          for (var v = 0; v < vs.length; v++) {
            final t = vs[v];
            if (terms.every((re) => re.hasMatch(t))) {
              total++;
              if (hits.length < 400) hits.add(_Hit(b.id, c, v + 1, t));
            }
          }
        }
      }
    }
    setState(() {
      _hits = hits;
      _total = total;
      _terms = terms;
      _goTo = r;
      _searched = true;
    });
    if (remember && (total > 0 || r != null)) {
      _remember(q);
      context.read<AppProvider>().trackSearchPerformed();
    }
  }

  void _open(int b, int c, [int? v]) {
    final q = _q.text.trim();
    if (q.isNotEmpty) _remember(q);
    Navigator.pop(context);
    widget.onOpen(b, c, v);
  }

  // The words found, lit
  List<TextSpan> _lit(String text, Parchment p) {
    final ranges = <(int, int)>[];
    for (final re in _terms) {
      for (final m in re.allMatches(text)) {
        ranges.add((m.start, m.end));
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final out = <TextSpan>[];
    var at = 0;
    for (final r in ranges) {
      if (r.$1 < at) continue;
      if (r.$1 > at) out.add(TextSpan(text: text.substring(at, r.$1)));
      out.add(
        TextSpan(
          text: text.substring(r.$1, r.$2),
          style: TextStyle(
            backgroundColor: p.accent.withValues(alpha: .22),
            color: p.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      at = r.$2;
    }
    if (at < text.length) out.add(TextSpan(text: text.substring(at)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final go = _goTo;
    return Leaf(
      title: 'Search',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.paddingOf(context).bottom + 30,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            controller: _q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            onSubmitted: (_) => _search(),
            style: p.body,
            decoration: InputDecoration(
              hintText: 'Words, "a phrase", or John 3:16',
              prefixIcon: Icon(CupertinoIcons.search, color: p.faded, size: 20),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : Tap(
                      onTap: () {
                        _q.clear();
                        _search(remember: false);
                      },
                      child: Icon(
                        CupertinoIcons.clear_circled_solid,
                        color: p.faded,
                        size: 18,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final (k, l) in const [
                ('all', 'All'),
                ('old', 'Old Testament'),
                ('new', 'New Testament'),
              ])
                Pill(
                  l,
                  on: _where == k,
                  onTap: () {
                    setState(() => _where = k);
                    if (_q.text.trim().isNotEmpty) _search(remember: false);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (go != null)
            Panel(
              accent: true,
              onTap: () => _open(go.$1, go.$2, go.$3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(CupertinoIcons.book, color: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Go to ${Kjb.bookOf(go.$1)!.singular} ${go.$2}${go.$3 != null ? ':${go.$3}' : ''}',
                      style: p.strong,
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, size: 14, color: p.faded),
                ],
              ),
            ),
          if (!_searched && _history.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Label('Searched before'),
            const SizedBox(height: 4),
            for (final h in _history)
              Tap(
                onTap: () {
                  _q.text = h;
                  _search();
                },
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 16, color: p.faded),
                    const SizedBox(width: 12),
                    Expanded(child: Text(h, style: p.body)),
                    Tap(
                      onTap: () async {
                        setState(() => _history.remove(h));
                        final sp = await SharedPreferences.getInstance();
                        await sp.setString(_historyKey, jsonEncode(_history));
                      },
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 14,
                        color: p.faded,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_searched && _terms.isNotEmpty) ...[
            const SizedBox(height: 16),
            Label(
              _total == 0
                  ? 'No verses with those words'
                  : _total > _hits.length
                  ? '$_total verses · the first ${_hits.length}'
                  : '$_total ${_total == 1 ? 'verse' : 'verses'}',
            ),
            const SizedBox(height: 4),
            for (final h in _hits)
              Tap(
                onTap: () => _open(h.book, h.chapter, h.verse),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Kjb.bookOf(h.book)!.singular} ${h.chapter}:${h.verse}',
                      style: p.small.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: p.body.copyWith(fontSize: 16.5),
                        children: _lit(h.text, p),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
