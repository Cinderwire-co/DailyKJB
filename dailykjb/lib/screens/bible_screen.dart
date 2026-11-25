import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bible/kjb.dart';
import '../providers/app_provider.dart';
import '../screenshots.dart';
import '../services/marks.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'reader.dart';
import 'search_screen.dart';

/// The King James Bible, a chapter to a page: swipe to the next, the pages
/// turning with a tap of haptics; tap verses to choose them, then highlight,
/// note, copy, share, or study them.
class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => BibleScreenState();
}

class BibleScreenState extends State<BibleScreen> with VerseActions {
  PageController? _pages;
  int _book = 43, _chap = 1;
  int? _focus;
  (int, int)? _focusAt; // the chapter _focus is a verse of

  @override
  int get pickBook => _book;
  @override
  int get pickChapter => _chap;

  @override
  void initState() {
    super.initState();
    _start();
    BibleNav.target.addListener(_navigate);
  }

  @override
  void dispose() {
    BibleNav.target.removeListener(_navigate);
    _pages?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await Kjb.load();
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString('bible_at') ?? '').split(':');
    var b = int.tryParse(saved.first) ?? 43;
    var c = int.tryParse(saved.length > 1 ? saved[1] : '') ?? 1;
    // Where the earlier app kept the place: the book by name
    final old = prefs.getString('bible_reader_book');
    if (saved.length < 2 && old != null && Kjb.named(old) != null) {
      b = Kjb.named(old)!.id;
      c = prefs.getInt('bible_reader_chapter') ?? 1;
    }
    if (Kjb.bookOf(b) == null) {
      b = 43;
      c = 1;
    }
    final t = BibleNav.target.value;
    if (t != null) {
      b = t.$1;
      c = t.$2;
      _focus = t.$3;
      _focusAt = (b, c);
      BibleNav.target.value = null;
    }
    if (!mounted) return;
    setState(() {
      _book = b;
      _chap = c.clamp(1, Kjb.bookOf(b)!.chapters);
      _pages = PageController(initialPage: Kjb.index(_book, _chap));
    });
    if (Screenshots.chosen.isNotEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => pick.verses.addAll(Screenshots.chosen));
      });
    }
  }

  void _navigate() {
    final t = BibleNav.target.value;
    if (t == null || _pages == null) return;
    BibleNav.target.value = null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => openAt(t.$1, t.$2, t.$3),
    );
  }

  /// To a chapter: the pages slide there (a neighbour) or jump (far off).
  @override
  void openAt(int b, int c, [int? verse]) {
    final i = Kjb.index(b, c), p = _pages;
    if (p == null || !p.hasClients) return;
    setState(() {
      _focus = verse;
      _focusAt = (b, c);
      pick.clear();
    });
    final at = p.page?.round() ?? i;
    if ((at - i).abs() == 1) {
      p.animateToPage(
        i,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      p.jumpToPage(i);
      _turned(i);
    }
  }

  void _turned(int i) {
    final (b, c) = Kjb.at(i);
    if (b == _book && c == _chap) return;
    HapticFeedback.selectionClick();
    setState(() {
      _book = b;
      _chap = c;
      if (_focusAt != (b, c)) _focus = null;
      pick.clear();
    });
    SharedPreferences.getInstance().then(
      (p) => p.setString('bible_at', '$b:$c'),
    );
    context.read<AppProvider>().trackExtraChapterRead();
  }

  void _step(int by) {
    final i = (Kjb.index(_book, _chap) + by).clamp(0, Kjb.total - 1);
    final (b, c) = Kjb.at(i);
    openAt(b, c);
  }

  Future<void> _pickBook() async {
    final b = await sheet<BibleBook>(
      context,
      title: 'The Books',
      body: (ctx) {
        final p = ctx.parch;
        Widget group(String t, bool old) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Label(t),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in Kjb.books.where((x) => x.oldTestament == old))
                  Tap(
                    onTap: () => Navigator.pop(ctx, b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: b.id == _book ? p.accentSoft : p.page,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: b.id == _book ? p.accent : p.rule,
                        ),
                      ),
                      child: Text(
                        b.name,
                        style: p.body.copyWith(
                          fontSize: 16,
                          color: p.inkStrong,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
        return Column(
          children: [
            group('The Old Testament', true),
            group('The New Testament', false),
          ],
        );
      },
    );
    if (b == null || !mounted) return;
    if (b.chapters == 1) {
      openAt(b.id, 1);
      return;
    }
    final c = await sheet<int>(
      context,
      title: b.name,
      body: (ctx) {
        final p = ctx.parch;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 1; i <= b.chapters; i++)
              Tap(
                onTap: () => Navigator.pop(ctx, i),
                child: Container(
                  width: 50,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: b.id == _book && i == _chap ? p.accentSoft : p.page,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: b.id == _book && i == _chap ? p.accent : p.rule,
                    ),
                  ),
                  child: Text(
                    '$i',
                    style: p.strong.copyWith(
                      fontFamily: Parchment.caps,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (c != null) openAt(b.id, c);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch, pages = _pages, sel = pick.isNotEmpty;
    return Scaffold(
      backgroundColor: p.page,
      body: Paper(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Tap(
                      onTap: () => push(context, SearchScreen(onOpen: openAt)),
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                      semantics: 'Search the Bible',
                      child: Icon(
                        CupertinoIcons.search,
                        color: p.inkStrong,
                        size: 21,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Tap(
                          onTap: pages == null ? null : _pickBook,
                          semantics: 'Choose a book and chapter',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: Text(
                                    pages == null
                                        ? ''
                                        : '${Kjb.name(_book)} $_chap',
                                    key: ValueKey('$_book:$_chap'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: p.title(17),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                CupertinoIcons.chevron_down,
                                size: 13,
                                color: p.faded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Tap(
                      onTap: () => readingStyleSheet(context),
                      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                      semantics: 'Type and size',
                      child: Icon(
                        CupertinoIcons.textformat_size,
                        color: p.inkStrong,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Hairline(color: p.rule.withValues(alpha: .7)),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: pages == null
                          ? const Waiting()
                          : ListenableBuilder(
                              listenable: Marks.i,
                              builder: (context, _) => PageView.builder(
                                controller: pages,
                                itemCount: Kjb.total,
                                onPageChanged: _turned,
                                itemBuilder: (context, i) {
                                  final (b, c) = Kjb.at(i);
                                  final here = b == _book && c == _chap;
                                  return _Turn(
                                    controller: pages,
                                    index: i,
                                    child: ChapterView(
                                      span: ChapterSpan(b, c),
                                      selected: here ? pick.verses : const {},
                                      focus: here ? _focus : null,
                                      onTapVerse: here ? tapVerse : (_) {},
                                      onOpenNote: openNote,
                                      bottomRoom: sel ? 190 : 40,
                                      footer: _footer(i),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    SelectionPanel(
                      visible: sel,
                      reference: sel ? pickReference : '',
                      onHighlight: highlightPick,
                      onStudy: studyPick,
                      onNote: notePick,
                      onCopy: copyPick,
                      onShare: sharePick,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(int i) {
    final p = context.parch;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Row(
        children: [
          Expanded(
            child: i == 0
                ? const SizedBox()
                : Tap(
                    onTap: () => _step(-1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.chevron_left,
                          size: 15,
                          color: p.accent,
                        ),
                        const SizedBox(width: 4),
                        Label('Before', color: p.accent),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: i >= Kjb.total - 1
                ? const SizedBox()
                : Tap(
                    onTap: () => _step(1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Label('Next', color: p.accent),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 15,
                          color: p.accent,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A page as it turns: the one going away dims a little and a soft shadow
/// falls along its edge, as a leaf does.
class _Turn extends StatelessWidget {
  const _Turn({
    required this.controller,
    required this.index,
    required this.child,
  });
  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        double d = 0;
        if (controller.hasClients && controller.position.haveDimensions) {
          d = (controller.page ?? index.toDouble()) - index;
        }
        if (d.abs() < .01) return child!;
        final t = d.abs().clamp(0.0, 1.0);
        return Stack(
          children: [
            Opacity(opacity: 1 - t * .35, child: child),
            Positioned(
              top: 0,
              bottom: 0,
              left: d < 0 ? 0 : null,
              right: d > 0 ? 0 : null,
              width: 26,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: d > 0
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: d > 0 ? Alignment.centerLeft : Alignment.centerRight,
                      colors: [
                        (p.dark ? Colors.black : const Color(0xFF5A3A1E))
                            .withValues(alpha: .22 * (1 - t)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Type, size, layout, and light or dark: everything about how the Bible
/// looks, changed as you watch.
Future<void> readingStyleSheet(BuildContext context) {
  return sheet(
    context,
    title: 'Reading',
    body: (ctx) => Consumer<AppProvider>(
      builder: (ctx, prov, _) {
        final p = ctx.parch;
        Widget row(
          List<(String, String)> options,
          String current,
          ValueChanged<String> set,
        ) => Row(
          children: [
            for (final o in options)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ParchButton(
                    o.$2,
                    small: true,
                    kind: current == o.$1 ? Btn.solid : Btn.outline,
                    onTap: () => set(o.$1),
                  ),
                ),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Label('Light or dark'),
            const SizedBox(height: 8),
            row(
              const [
                ('light', 'Parchment'),
                ('dark', 'Lamplight'),
                ('system', 'As phone'),
              ],
              prov.userData?.themeMode ?? 'system',
              prov.setThemeMode,
            ),
            const SizedBox(height: 18),
            const Label('Type'),
            const SizedBox(height: 8),
            row(
              const [
                ('garamond', 'Garamond'),
                ('georgia', 'Georgia'),
                ('sans', 'Clean'),
              ],
              prov.readingFont,
              prov.setReadingFont,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Label('Size'),
                const Spacer(),
                Text('${(prov.fontScale * 100).round()}%', style: p.small),
              ],
            ),
            Row(
              children: [
                Text(
                  'A',
                  style: TextStyle(
                    fontFamily: Parchment.serif,
                    fontSize: 15,
                    color: p.faded,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: prov.fontScale,
                    min: .8,
                    max: 1.6,
                    divisions: 8,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      prov.setFontScale(v);
                    },
                  ),
                ),
                Text(
                  'A',
                  style: TextStyle(
                    fontFamily: Parchment.serif,
                    fontSize: 26,
                    color: p.faded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Label('Layout'),
            const SizedBox(height: 8),
            row(
              const [('lines', 'Verse by verse'), ('paragraph', 'Paragraph')],
              prov.verseLayout,
              prov.setVerseLayout,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.page,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: p.rule),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'I',
                      style: TextStyle(
                        fontFamily: Parchment.caps,
                        color: p.rubric,
                        fontSize: 26 * prov.fontScale,
                      ),
                    ),
                    TextSpan(
                      text: 'n the beginning God created the heaven and the earth.',
                      style: TextStyle(
                        fontFamily: switch (prov.readingFont) {
                          'georgia' => 'Georgia',
                          'sans' => null,
                          _ => Parchment.serif,
                        },
                        fontSize:
                            (prov.readingFont == 'garamond' ? 21 : 19) *
                            prov.fontScale,
                        height: 1.5,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
