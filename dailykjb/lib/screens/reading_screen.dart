import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../bible/kjb.dart';
import '../models/reading.dart';
import '../providers/app_provider.dart';
import '../screenshots.dart';
import '../services/marks.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'bible_screen.dart' show readingStyleSheet;
import 'quiz_screen.dart';
import 'reader.dart';

/// A day's reading: its chapters a page each, turned with a swipe; at the end,
/// marked read (after a little time, when Focus Mode is on), or a quiz.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.reading});
  final DayReading reading;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> with VerseActions {
  final _pages = PageController();
  final _endKey = GlobalKey();
  int _page = 0;
  int _remaining = 0;
  Timer? _timer;

  List<ChapterSpan> get _spans => widget.reading.spans;
  ChapterSpan get _span => _spans[_page.clamp(0, _spans.length - 1)];

  @override
  int get pickBook => _span.book;
  @override
  int get pickChapter => _span.chapter;

  @override
  void initState() {
    super.initState();
    if (Screenshots.scene == 'reading') _toEnd();
    final prov = context.read<AppProvider>();
    if ((prov.userData?.appBlockingEnabled ?? false) &&
        !prov.isDayComplete(widget.reading.planDay)) {
      _remaining = prov.minReadingSeconds(widget.reading);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _remaining--);
        if (_remaining <= 0) t.cancel();
      });
    }
  }

  // Screenshots: the end of the day's reading, where it's marked read
  Future<void> _toEnd() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _spans.length < 2) return;
    _pages.jumpToPage(_spans.length - 1);
    await Future.delayed(const Duration(milliseconds: 700));
    final ctx = _endKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx, alignment: .55);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  void openAt(int book, int chapter, [int? verse]) =>
      openInBible(context, book, chapter, verse);

  void _turned(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _page = i;
      pick.clear();
    });
  }

  void _step(int by) => _pages.animateToPage(
    (_page + by).clamp(0, _spans.length - 1),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    await context.read<AppProvider>().markReadingCompleteAndUnblock(
      widget.reading,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _quiz() async {
    final passed = await push<bool>(
      context,
      QuizScreen(reading: widget.reading),
    );
    if (passed == true && mounted) Navigator.pop(context, true);
  }

  String _time(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final prov = context.watch<AppProvider>();
    final day = widget.reading.planDay;
    final catchUp = day < prov.getCurrentPlanDay();
    final done = prov.isDayComplete(day);
    final sel = pick.isNotEmpty;
    return Leaf(
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('DAY $day', style: p.title(15).copyWith(letterSpacing: 2.4)),
          Text(
            catchUp
                ? 'Catching up · ${DateFormat('MMM d').format(prov.getDateForPlanDay(day))}'
                : DateFormat('EEEE, MMMM d')
                      .format(prov.getDateForPlanDay(day)),
            style: p.small.copyWith(
              fontSize: 12.5,
              color: catchUp ? p.warning : p.faded,
            ),
          ),
        ],
      ),
      title: 'Day $day',
      actions: [
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
      body: Column(
        children: [
          // Where in the day's reading: a segment for each chapter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < _spans.length; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _page ? p.accent : p.deep,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: Marks.i,
                    builder: (context, _) => PageView.builder(
                      controller: _pages,
                      itemCount: _spans.length,
                      onPageChanged: _turned,
                      itemBuilder: (context, i) {
                        final here = i == _page;
                        final last = i == _spans.length - 1;
                        final extra = i >= widget.reading.units.length;
                        return ChapterView(
                          span: _spans[i],
                          heading:
                              '${extra ? 'Also today' : 'Day $day'} · ${i + 1} of ${_spans.length}',
                          selected: here ? pick.verses : const {},
                          onTapVerse: here ? tapVerse : (_) {},
                          onOpenNote: openNote,
                          bottomRoom: sel ? 190 : 40,
                          footer: last ? _end(done) : _next(i),
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
    );
  }

  Widget _next(int i) {
    final p = context.parch;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Tap(
        onTap: () => _step(1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Label('Next · ${_spans[i + 1].label}', color: p.accent),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right, size: 15, color: p.accent),
          ],
        ),
      ),
    );
  }

  Widget _end(bool done) {
    final p = context.parch;
    final waiting = _remaining > 0;
    return Padding(
      key: _endKey,
      padding: const EdgeInsets.only(top: 34, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Ornament(width: 140),
          const SizedBox(height: 16),
          Center(
            child: Text(
              done ? 'Read' : 'The end of today\'s reading',
              style: p.title(17),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              Kjb.describe(widget.reading.spans),
              textAlign: TextAlign.center,
              style: p.small,
            ),
          ),
          const SizedBox(height: 18),
          if (!done) ...[
            ParchButton(
              waiting ? 'Keep reading · ${_time(_remaining)}' : 'Mark as read',
              kind: Btn.solid,
              expand: true,
              icon: waiting
                  ? CupertinoIcons.hourglass
                  : CupertinoIcons.checkmark_alt,
              onTap: waiting ? null : _complete,
            ),
            if (waiting)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Focus Mode asks for a little time with the reading first.',
                  textAlign: TextAlign.center,
                  style: p.small.copyWith(fontSize: 13),
                ),
              ),
            const SizedBox(height: 10),
            ParchButton(
              'Take the quiz',
              expand: true,
              icon: CupertinoIcons.question_circle,
              onTap: waiting ? null : _quiz,
            ),
            const SizedBox(height: 6),
            Text(
              'Pass it and the day is marked read.',
              textAlign: TextAlign.center,
              style: p.small.copyWith(fontSize: 13),
            ),
          ] else
            ParchButton(
              'Back',
              expand: true,
              onTap: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
