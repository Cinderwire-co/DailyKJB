import 'package:confetti/confetti.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../bible/kjb.dart';
import '../models/reading.dart';
import '../providers/app_provider.dart';
import '../services/verse_of_day_service.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../utils/constants.dart';
import 'bible_screen.dart';
import 'journal_screen.dart';
import 'progress_screen.dart';
import 'reader.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import 'verse_share_screen.dart';
import 'verse_study_screen.dart';

/// The app: Today, the Bible, the Journal, Progress, Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BibleNav.target.addListener(_toBible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BibleNav.target.removeListener(_toBible);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppProvider>().onResume();
    }
  }

  void _toBible() {
    if (BibleNav.target.value != null && _tab != 1) setState(() => _tab = 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    const tabs = [
      (CupertinoIcons.sun_max, CupertinoIcons.sun_max_fill, 'Today'),
      (CupertinoIcons.book, CupertinoIcons.book_fill, 'Bible'),
      (CupertinoIcons.bookmark, CupertinoIcons.bookmark_fill, 'Journal'),
      (CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_fill, 'Progress'),
      (CupertinoIcons.gear, CupertinoIcons.gear_solid, 'Settings'),
    ];
    return Scaffold(
      backgroundColor: p.page,
      body: IndexedStack(
        index: _tab,
        children: [
          TodayTab(onTab: (i) => setState(() => _tab = i)),
          const BibleScreen(),
          JournalScreen(visible: _tab == 2),
          const ProgressScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.leaf,
          border: Border(top: BorderSide(color: p.rule)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                for (final (i, t) in tabs.indexed)
                  Expanded(
                    child: Tap(
                      semantics: t.$3,
                      onTap: () {
                        if (i != _tab) HapticFeedback.selectionClick();
                        setState(() => _tab = i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == _tab ? t.$2 : t.$1,
                            size: 23,
                            color: i == _tab ? p.accent : p.faded,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.$3.toUpperCase(),
                            style: TextStyle(
                              fontFamily: Parchment.caps,
                              fontSize: 9.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: i == _tab ? p.accent : p.faded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TodayTab extends StatefulWidget {
  const TodayTab({super.key, required this.onTab});
  final ValueChanged<int> onTab;

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 3));
  ({String verse, String reference})? _votd;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    VerseOfDayService().getVerseOfDay().then((v) {
      if (mounted) setState(() => _votd = v);
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _read(DayReading r) async {
    final done = await push<bool>(context, ReadingScreen(reading: r));
    if (done == true && mounted) {
      HapticFeedback.mediumImpact();
      toast(context, 'Day ${r.planDay} read. Well done.');
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Consumer<AppProvider>(
      builder: (context, prov, _) {
        final user = prov.userData!;
        final progress = prov.getProgress();
        if (progress.isComplete && !_celebrated) {
          _celebrated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
        }
        final streak = prov.streak;
        return Paper(
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Measure(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Label(
                                  DateFormat('EEEE, MMMM d')
                                      .format(DateTime.now()),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user.name.isEmpty
                                      ? _greeting
                                      : '$_greeting,\n${user.name}',
                                  style: p.title(27),
                                ),
                              ],
                            ),
                          ),
                          if (streak > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: p.accentSoft,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: p.accent.withValues(alpha: .4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.flame_fill,
                                    size: 15,
                                    color: p.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$streak ${streak == 1 ? 'day' : 'days'}',
                                    style: p.small.copyWith(
                                      color: p.inkStrong,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (progress.isComplete)
                        _complete(prov)
                      else ...[
                        if (prov.getDaysBehind() > 1) _behind(prov),
                        if (prov.isTodayComplete())
                          _done(prov)
                        else
                          _today(prov),
                      ],
                      const SizedBox(height: 18),
                      if (_votd != null) _verseOfDay(_votd!),
                      const SizedBox(height: 18),
                      _progress(prov, progress),
                      if (!progress.isComplete) ...[
                        const SizedBox(height: 26),
                        _upcoming(prov),
                      ],
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 30,
                  colors: [
                    p.accent,
                    p.gold,
                    p.rubric,
                    Parchment.highlights['yellow']!,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _today(AppProvider prov) {
    final p = context.parch;
    final r = prov.getTodaysReading();
    final catchUp = r.planDay < prov.getCurrentPlanDay();
    final focus = prov.userData?.appBlockingEnabled ?? false;
    return Panel(
      accent: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Label(
                catchUp
                    ? 'Catch up · ${DateFormat('MMM d').format(prov.getDateForPlanDay(r.planDay))}'
                    : 'Today\'s reading',
                color: catchUp ? p.warning : p.accent,
              ),
              const Spacer(),
              Text('Day ${r.planDay} of ${r.totalDays}', style: p.small),
            ],
          ),
          const SizedBox(height: 12),
          Text(r.title, style: p.title(25).copyWith(height: 1.2)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(CupertinoIcons.time, size: 15, color: p.faded),
              const SizedBox(width: 5),
              Text(
                'About ${r.minutes} ${r.minutes == 1 ? 'minute' : 'minutes'}',
                style: p.small,
              ),
              if (focus) ...[
                const SizedBox(width: 14),
                Icon(CupertinoIcons.lock_fill, size: 14, color: p.faded),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Apps open once read',
                    style: p.small,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          ParchButton(
            'Begin reading',
            kind: Btn.solid,
            expand: true,
            icon: CupertinoIcons.book_fill,
            onTap: () => _read(r),
          ),
        ],
      ),
    );
  }

  Widget _done(AppProvider prov) {
    final p = context.parch;
    final next = prov.getNextUncompletedDay();
    final r = prov.getReadingForDay(next);
    final more = !prov.isDayComplete(next);
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.checkmark_seal_fill,
                color: p.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today is read', style: p.title(20)),
                    Text(
                      prov.getDaysAhead() > 0
                          ? 'You\'re ${prov.getDaysAhead()} ${prov.getDaysAhead() == 1 ? 'day' : 'days'} ahead.'
                          : '"Thy word is a lamp unto my feet." Psalm 119:105',
                      style: p.small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (more) ...[
            const SizedBox(height: 16),
            ParchButton(
              'Read ahead · ${r.shortTitle}',
              expand: true,
              icon: CupertinoIcons.forward,
              onTap: () => _read(r),
            ),
          ],
        ],
      ),
    );
  }

  Widget _behind(AppProvider prov) {
    final p = context.parch;
    final n = prov.getDaysBehind();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.warning.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: p.warning.withValues(alpha: .45)),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.hourglass, color: p.warning, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$n days to catch up. Take them one at a time, or pick up from today.',
                style: p.body.copyWith(fontSize: 15.5),
              ),
            ),
            Tap(
              onTap: () => _restart(prov),
              padding: const EdgeInsets.only(left: 8),
              child: Label('Pick up', color: p.accent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restart(AppProvider prov) async {
    final next = prov.getNextUncompletedDay();
    final ok = await sure(
      context,
      'Pick up from today?',
      ok: 'Make today day $next',
      text:
          'The days you missed move forward so that today is day $next, where you left off. What you\'ve read stays read, and the plan ends a little later.',
    );
    if (!ok) return;
    await prov.pickUpFromToday();
    if (mounted) toast(context, 'Today is day $next');
  }

  Widget _complete(AppProvider prov) {
    final p = context.parch;
    return Panel(
      accent: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(CupertinoIcons.rosette, color: p.gold, size: 46),
          const SizedBox(height: 10),
          Text(
            'The plan is finished',
            textAlign: TextAlign.center,
            style: p.title(22),
          ),
          const SizedBox(height: 6),
          Text(
            '${prov.currentPlan.name}, every day of it. "I have fought a good fight, I have finished my course, I have kept the faith."',
            textAlign: TextAlign.center,
            style: p.body.copyWith(color: p.faded),
          ),
          const SizedBox(height: 18),
          ParchButton(
            'Begin a new plan',
            kind: Btn.solid,
            expand: true,
            onTap: () => choosePlanSheet(context, fresh: true),
          ),
        ],
      ),
    );
  }

  Widget _verseOfDay(({String verse, String reference}) v) {
    final p = context.parch;
    void study() {
      final r = Kjb.ref(v.reference);
      if (r != null) {
        push(
          context,
          VerseStudyScreen(book: r.$1, chapter: r.$2, verse: r.$3 ?? 1),
        );
      }
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Label('The verse for today')),
          const SizedBox(height: 10),
          const Ornament(width: 80),
          const SizedBox(height: 14),
          Text(
            v.verse,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Parchment.serif,
              fontSize: 21,
              height: 1.45,
              color: p.inkStrong,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            v.reference.toUpperCase(),
            textAlign: TextAlign.center,
            style: p.label.copyWith(color: p.accent, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (icon, label, go) in [
                (
                  CupertinoIcons.square_arrow_up,
                  'Share',
                  () => push(
                    context,
                    VerseShareScreen(reference: v.reference, text: v.verse),
                  ),
                ),
                (CupertinoIcons.book, 'Study', study),
                (
                  CupertinoIcons.arrow_right_circle,
                  'In context',
                  () {
                    final r = Kjb.ref(v.reference);
                    if (r != null) openInBible(context, r.$1, r.$2, r.$3);
                  },
                ),
              ])
                Tap(
                  onTap: go,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: p.accent),
                      const SizedBox(width: 5),
                      Label(label, color: p.ink, size: 10),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progress(AppProvider prov, Progress progress) {
    final p = context.parch;
    return Panel(
      onTap: () => widget.onTab(3),
      child: Row(
        children: [
          Ring(
            value: progress.percentage / 100,
            size: 74,
            stroke: 6,
            child: Text(
              '${progress.percentage.round()}%',
              style: p.strong.copyWith(fontSize: 16),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(prov.currentPlan.name),
                const SizedBox(height: 4),
                Text(
                  '${progress.completed} of ${progress.total} days read',
                  style: p.strong,
                ),
                Text(
                  '${durationLabel(progress.total)} · began ${DateFormat('MMMM d').format(prov.userData!.startDate)}',
                  style: p.small,
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 14, color: p.faded),
        ],
      ),
    );
  }

  Widget _upcoming(AppProvider prov) {
    final p = context.parch;
    final from =
        prov.getNextUncompletedDay() + (prov.isTodayComplete() ? 1 : 0);
    final days = [
      for (var d = from + 1; d <= from + 3 && d <= prov.totalPlanDays; d++) d,
    ].where((d) => !prov.isDayComplete(d)).toList();
    if (days.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Label('Coming up'),
        const SizedBox(height: 4),
        for (final d in days)
          Tap(
            onTap: () => _read(prov.getReadingForDay(d)),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    'Day $d',
                    style: p.small.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(prov.getReadingForDay(d).title, style: p.body),
                ),
                Text(
                  DateFormat('EEE').format(prov.getDateForPlanDay(d)),
                  style: p.small,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Choose a plan and how long to take over it. [fresh]: a new plan from today
/// (the finished one kept in history).
Future<void> choosePlanSheet(BuildContext context, {bool fresh = false}) async {
  final prov = context.read<AppProvider>();
  var planId = prov.userData?.planId ?? availablePlans.first.id;
  var days = prov.userData?.targetDays ?? 365;
  var durations = prov.durationsFor(await prov.unitsFor(planId));
  if (!context.mounted) return;
  final go = await sheet<bool>(
    context,
    title: fresh ? 'A new plan' : 'Your plan',
    body: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final p = ctx.parch;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Label('Read'),
            const SizedBox(height: 6),
            for (final plan in availablePlans)
              Tap(
                onTap: () async {
                  final d = prov.durationsFor(await prov.unitsFor(plan.id));
                  set(() {
                    planId = plan.id;
                    durations = d;
                    if (!durations.contains(days)) days = 365;
                  });
                },
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Icon(
                      planId == plan.id
                          ? CupertinoIcons.largecircle_fill_circle
                          : CupertinoIcons.circle,
                      color: planId == plan.id ? p.accent : p.faded,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.name, style: p.strong),
                          Text(plan.description, style: p.small),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            const Label('Over'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in durations)
                  Pill(
                    durationLabel(d),
                    on: days == d,
                    onTap: () => set(() => days = d),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (!fresh &&
                (planId != prov.userData?.planId ||
                    days != prov.userData?.targetDays))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  planId != prov.userData?.planId
                      ? 'A different plan begins today, from day 1.'
                      : 'Your progress stays; the days ahead are spread over the new length.',
                  style: p.small,
                ),
              ),
            ParchButton(
              fresh ? 'Begin' : 'Save',
              kind: Btn.solid,
              expand: true,
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    ),
  );
  if (go != true) return;
  if (fresh) {
    await prov.startNewPlan(planId: planId, targetDays: days);
  } else if (planId != prov.userData?.planId) {
    await prov.changePlan(planId, targetDays: days);
  } else if (days != prov.userData?.targetDays) {
    await prov.updateTargetDays(days);
  }
}
