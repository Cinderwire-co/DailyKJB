import 'dart:io' show Platform;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../bible/kjb.dart';
import '../models/verse_note.dart';
import '../providers/app_provider.dart';
import '../services/marks.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'verse_share_screen.dart';
import 'verse_study_screen.dart';

/// Where the Bible tab should open next: set from anywhere (a search, a
/// cross reference, a note), and the app's shell takes the reader there.
class BibleNav {
  static final target = ValueNotifier<(int, int, int?)?>(null);
}

void openInBible(BuildContext context, int book, int chapter, [int? verse]) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  BibleNav.target.value = (book, chapter, verse);
}

/// How the reader likes the Bible set: the type, its size, a verse to a line
/// or as a paragraph.
class ReaderStyle {
  final String family;
  final double size;
  final bool lines;
  const ReaderStyle(this.family, this.size, this.lines);

  /// The reader's three typefaces. Georgia is Apple's; Android has its own serif in its place. Clean is the
  /// phone's own sans: SF Pro, or Roboto (named, or it would take the theme's Garamond).
  static String familyOf(String font) => switch (font) {
    'georgia' => Platform.isAndroid ? 'serif' : 'Georgia',
    'sans' => Platform.isAndroid ? 'sans-serif' : 'CupertinoSystemText',
    _ => Parchment.serif,
  };

  static String nameOf(String font) => switch (font) {
    'georgia' => Platform.isAndroid ? 'Serif' : 'Georgia',
    'sans' => 'Clean',
    _ => 'Garamond',
  };

  static ReaderStyle of(BuildContext context) {
    final p = context.watch<AppProvider>();
    final family = familyOf(p.readingFont);
    // EB Garamond sets small for its size; the others a little larger
    final base = family == Parchment.serif ? 21.0 : 19.0;
    return ReaderStyle(
      family,
      base * p.fontScale,
      p.verseLayout != 'paragraph',
    );
  }
}

/// The verses chosen, each on its own: 4 and 6 is just 4 and 6.
class VersePick {
  final Set<int> verses = {};

  bool get isEmpty => verses.isEmpty;
  bool get isNotEmpty => verses.isNotEmpty;

  void toggle(int v) {
    if (!verses.remove(v)) verses.add(v);
  }

  void clear() => verses.clear();

  List<(int, int)> get runs {
    final v = verses.toList()..sort();
    final out = <(int, int)>[];
    for (final n in v) {
      if (out.isNotEmpty && out.last.$2 == n - 1) {
        out[out.length - 1] = (out.last.$1, n);
      } else {
        out.add((n, n));
      }
    }
    return out;
  }

  String reference(int book, int chapter) {
    final name = Kjb.bookOf(book)?.singular ?? '';
    if (verses.isEmpty) return '$name $chapter';
    return '$name $chapter:${runs.map((r) => r.$1 == r.$2 ? '${r.$1}' : '${r.$1}–${r.$2}').join(', ')}';
  }

  /// The words of the chosen verses, runs apart joined with an ellipsis.
  String text(int book, int chapter, {bool numbers = false}) {
    final v = Kjb.verses(book, chapter);
    return runs
        .map(
          (r) => [
            for (var n = r.$1; n <= r.$2 && n <= v.length; n++)
              numbers ? '$n ${v[n - 1]}' : v[n - 1],
          ].join(' '),
        )
        .join(' … ');
  }
}

/// One chapter (or the part of it a plan gives): its book and number, then
/// its verses. A chosen verse is lit and underlined; a highlight colours only
/// the words.
class ChapterView extends StatefulWidget {
  const ChapterView({
    super.key,
    required this.span,
    required this.selected,
    required this.onTapVerse,
    required this.onOpenNote,
    this.focus,
    this.footer,
    this.bottomRoom = 40,
    this.heading,
  });

  final ChapterSpan span;
  final Set<int> selected;
  final int? focus;
  final ValueChanged<int> onTapVerse;
  final ValueChanged<VerseNote> onOpenNote;
  final Widget? footer;
  final double bottomRoom;
  final String? heading; // over the book's name: "Day 12 · 2 of 3"

  @override
  State<ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends State<ChapterView> {
  final _keys = <int, GlobalKey>{};
  final _taps = <int, TapGestureRecognizer>{};
  int? _flash;

  @override
  void initState() {
    super.initState();
    _toFocus();
  }

  @override
  void didUpdateWidget(ChapterView old) {
    super.didUpdateWidget(old);
    if (widget.focus != null && widget.focus != old.focus) _toFocus();
  }

  @override
  void dispose() {
    for (final t in _taps.values) {
      t.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(int v) => _taps.putIfAbsent(
    v,
    () => TapGestureRecognizer()..onTap = () => widget.onTapVerse(v),
  );

  // Opened at a verse (a search, a cross reference, a note): there, and lit
  // for a moment
  void _toFocus() {
    final v = widget.focus;
    if (v == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _keys[v]?.currentContext ?? _keys[0]?.currentContext;
      if (v > 1 && ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: .25,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      if (mounted) setState(() => _flash = v);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _flash = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final style = ReaderStyle.of(context);
    final s = widget.span, b = s.book, c = s.chapter;
    final verses = s.verses();
    final notes = Marks.i.notesIn(b, c);
    final fs = style.size;
    final verseStyle = TextStyle(
      fontFamily: style.family,
      fontFamilyFallback: const [Parchment.serif],
      fontSize: fs,
      height: 1.55,
      color: p.ink,
    );
    final selColor = p.accent.withValues(alpha: p.dark ? .32 : .22);
    final book = Kjb.bookOf(b);
    final partial = !s.whole;

    Color? bg(int n) {
      if (widget.selected.contains(n) || _flash == n) return selColor;
      return Marks.i.colorOf(b, c, n)?.withValues(alpha: p.dark ? .38 : .6);
    }

    bool on(int n) => widget.selected.contains(n) || _flash == n;

    // The first verse of a chapter opens with a red initial, as the old Bibles do
    List<InlineSpan> words(int n, String text, TextStyle st) {
      if (n != 1 || text.isEmpty) return [TextSpan(text: text, style: st)];
      return [
        TextSpan(
          text: text[0],
          style: st.copyWith(
            fontFamily: Parchment.caps,
            fontSize: fs * 1.75,
            height: 1.0,
            color: p.rubric,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(text: text.substring(1), style: st),
      ];
    }

    VerseNote? noteEndingAt(int n) =>
        notes.where((x) => x.endVerse == n).firstOrNull;

    Widget noteMark(VerseNote note) => GestureDetector(
      onTap: () => widget.onOpenNote(note),
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(
          CupertinoIcons.pencil_circle_fill,
          size: fs * .85,
          color: p.accent,
        ),
      ),
    );

    final body = <Widget>[];
    if (style.lines) {
      for (final (n, text) in verses) {
        final st = verseStyle.copyWith(
          backgroundColor: bg(n),
          decoration: on(n) ? TextDecoration.underline : null,
          decorationColor: p.accent,
          decorationThickness: 1.6,
        );
        final note = noteEndingAt(n);
        body.add(
          GestureDetector(
            key: _keys.putIfAbsent(n, () => GlobalKey()),
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onTapVerse(n),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fs * 1.45,
                    child: Padding(
                      padding: EdgeInsets.only(top: fs * .42, right: 7),
                      child: Text(
                        '$n',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: Parchment.caps,
                          fontSize: fs * .5,
                          fontWeight: FontWeight.w700,
                          color: p.accent,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          ...words(n, text, st),
                          if (note != null)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: noteMark(note),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } else {
      // As a paragraph: the verse numbers small and raised in the run of text
      body.add(
        Text.rich(
          key: _keys.putIfAbsent(0, () => GlobalKey()),
          TextSpan(
            children: [
              for (final (n, text) in verses) ...[
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: GestureDetector(
                    key: _keys.putIfAbsent(n, () => GlobalKey()),
                    onTap: () => widget.onTapVerse(n),
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 3,
                        left: n == verses.first.$1 ? 0 : 4,
                        top: fs * .1,
                      ),
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontFamily: Parchment.caps,
                          fontSize: fs * .52,
                          fontWeight: FontWeight.w700,
                          color: p.accent,
                        ),
                      ),
                    ),
                  ),
                ),
                ...words(
                  n,
                  text,
                  verseStyle.copyWith(
                    backgroundColor: bg(n),
                    decoration: on(n) ? TextDecoration.underline : null,
                    decorationColor: p.accent,
                    decorationThickness: 1.6,
                  ),
                ).map(
                  (sp) => sp is TextSpan
                      ? TextSpan(
                          text: sp.text,
                          style: sp.style,
                          recognizer: _tap(n),
                        )
                      : sp,
                ),
                if (noteEndingAt(n) != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: noteMark(noteEndingAt(n)!),
                  ),
                const TextSpan(text: ' '),
              ],
            ],
          ),
          style: verseStyle,
        ),
      );
    }

    return Measure(
      width: 680,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          style.lines ? 10 : 22,
          18,
          20,
          MediaQuery.paddingOf(context).bottom + widget.bottomRoom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.heading != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Label(widget.heading!, color: p.accent),
                ),
              ),
            Center(
              child: Text(
                (book?.name ?? '').toUpperCase(),
                textAlign: TextAlign.center,
                style: p.label.copyWith(letterSpacing: 4, fontSize: 12),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                '$c',
                style: TextStyle(
                  fontFamily: Parchment.caps,
                  fontSize: 60,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  color: p.rubric,
                ),
              ),
            ),
            if (partial)
              Center(
                child: Text(
                  'Verses ${s.firstVerse()}–${s.lastVerse()}',
                  style: p.small.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 6),
            const Ornament(width: 96),
            const SizedBox(height: 18),
            ...body,
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 26),
              Padding(
                padding: EdgeInsets.only(left: style.lines ? fs * 1.45 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Label('Your notes'),
                    const SizedBox(height: 6),
                    for (final n in notes)
                      Tap(
                        onTap: () => widget.onOpenNote(n),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 2, height: 40, color: p.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.startVerse == n.endVerse
                                        ? 'Verse ${n.startVerse}'
                                        : 'Verses ${n.startVerse}–${n.endVerse}',
                                    style: p.small.copyWith(
                                      color: p.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    n.content,
                                    style: p.body.copyWith(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            ?widget.footer,
          ],
        ),
      ),
    );
  }
}

/// What can be done with the verses chosen, floating over the reading.
class SelectionPanel extends StatelessWidget {
  const SelectionPanel({
    super.key,
    required this.visible,
    required this.reference,
    required this.onHighlight,
    required this.onStudy,
    required this.onNote,
    required this.onCopy,
    required this.onShare,
    this.bottom = 12,
  });

  final bool visible;
  final String reference;
  final ValueChanged<String> onHighlight;
  final VoidCallback onStudy, onNote, onCopy, onShare;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final w = MediaQuery.sizeOf(context).width;
    final side = w > 640 ? (w - 620) / 2 : 10.0;
    return Positioned(
      left: side,
      right: side,
      bottom: MediaQuery.paddingOf(context).bottom + bottom,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.6),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !visible,
            child: Glass(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reference,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: p.strong.copyWith(fontSize: 16),
                        ),
                      ),
                      for (final c in Parchment.highlights.entries)
                        Tap(
                          onTap: () => onHighlight(c.key),
                          semantics: 'Highlight ${c.key}',
                          child: Container(
                            margin: const EdgeInsets.only(left: 7),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c.value,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.rule),
                            ),
                          ),
                        ),
                      Tap(
                        onTap: () => onHighlight('none'),
                        semantics: 'Remove highlight',
                        child: Container(
                          margin: const EdgeInsets.only(left: 7),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: p.rule),
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 12,
                            color: p.faded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final x in [
                        (CupertinoIcons.book, 'Study', onStudy),
                        (CupertinoIcons.pencil, 'Note', onNote),
                        (CupertinoIcons.doc_on_doc, 'Copy', onCopy),
                        (CupertinoIcons.square_arrow_up, 'Share', onShare),
                      ])
                        Expanded(
                          child: Tap(
                            onTap: x.$3,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                Icon(x.$1, color: p.inkStrong, size: 21),
                                const SizedBox(height: 3),
                                Label(x.$2, size: 9.5, color: p.ink),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The actions behind the panel, shared by the Bible and the day's reading.
mixin VerseActions<T extends StatefulWidget> on State<T> {
  final pick = VersePick();
  int get pickBook;
  int get pickChapter;
  void openAt(int book, int chapter, [int? verse]);

  void tapVerse(int v) {
    HapticFeedback.selectionClick();
    setState(() => pick.toggle(v));
  }

  String get pickReference => pick.reference(pickBook, pickChapter);

  Future<void> highlightPick(String color) async {
    final runs = pick.runs, b = pickBook, c = pickChapter;
    HapticFeedback.lightImpact();
    setState(pick.clear);
    await Marks.i.highlight(b, c, runs, color);
  }

  Future<void> notePick() async {
    final runs = pick.runs, b = pickBook, c = pickChapter, ref = pickReference;
    final text = pick.text(b, c);
    final content = await writeNote(
      context,
      title: 'A note on $ref',
      verse: text,
    );
    if (content == null || content.trim().isEmpty) return;
    await Marks.i.addNote(b, c, runs, content.trim());
    if (mounted) setState(pick.clear);
  }

  Future<void> openNote(VerseNote note) async {
    final r = await writeNote(
      context,
      title: note.reference,
      verse: note.verseTexts.join(' '),
      initial: note.content,
      canDelete: true,
    );
    if (r == null) return;
    if (r == noteDeleted) {
      await Marks.i.deleteNote(note);
    } else if (r.trim().isNotEmpty) {
      await Marks.i.updateNote(note, r.trim());
    }
  }

  Future<void> copyPick() async {
    final ref = pickReference, text = pick.text(pickBook, pickChapter);
    await Clipboard.setData(ClipboardData(text: '$text — $ref (KJB)'));
    if (!mounted) return;
    toast(context, 'Copied');
    setState(pick.clear);
  }

  void sharePick() {
    final ref = pickReference, text = pick.text(pickBook, pickChapter);
    setState(pick.clear);
    push(context, VerseShareScreen(reference: ref, text: text));
  }

  void studyPick() {
    if (pick.isEmpty) return;
    final v = pick.runs.first.$1;
    push(
      context,
      VerseStudyScreen(
        book: pickBook,
        chapter: pickChapter,
        verse: v,
        onOpen: openAt,
      ),
    );
  }
}

/// What [writeNote] returns when the note is to be deleted.
const noteDeleted = '\u0000delete';

/// A note's words: written new, or changed, or (with [canDelete]) deleted.
Future<String?> writeNote(
  BuildContext context, {
  required String title,
  String verse = '',
  String initial = '',
  bool canDelete = false,
}) {
  final c = TextEditingController(text: initial);
  return sheet<String>(
    context,
    title: title,
    body: (ctx) {
      final p = ctx.parch;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (verse.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: p.accent, width: 2)),
              ),
              child: Text(
                verse,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: p.body.copyWith(
                  fontStyle: FontStyle.italic,
                  color: p.faded,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: c,
            autofocus: initial.isEmpty,
            minLines: 4,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            style: p.body,
            decoration: const InputDecoration(
              hintText: 'What God showed you here',
            ),
          ),
          const SizedBox(height: 14),
          ParchButton(
            'Save',
            kind: Btn.solid,
            expand: true,
            onTap: () => Navigator.pop(ctx, c.text),
          ),
          if (canDelete) ...[
            const SizedBox(height: 8),
            ParchButton(
              'Delete this note',
              kind: Btn.quiet,
              expand: true,
              onTap: () => Navigator.pop(ctx, noteDeleted),
            ),
          ],
        ],
      );
    },
  );
}
