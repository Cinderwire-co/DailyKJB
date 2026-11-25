import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/plan_history.dart';
import '../providers/app_provider.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../utils/constants.dart';
import 'home_screen.dart' show choosePlanSheet;
import 'reading_screen.dart';

/// How far through the plan: the share read, the days in a row, every day of
/// the plan on its calendar, and plans finished before.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int? _month; // months from the plan's first; first shown: this month

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Leaf(
      title: 'Progress',
      back: false,
      body: Consumer<AppProvider>(
        builder: (context, prov, _) {
          final progress = prov.getProgress();
          final u = prov.userData!;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              20,
              18,
              MediaQuery.paddingOf(context).bottom + 36,
            ),
            children: [
              Center(
                child: Ring(
                  value: progress.percentage / 100,
                  size: 168,
                  stroke: 9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${progress.percentage.toStringAsFixed(progress.percentage < 10 && progress.percentage > 0 ? 1 : 0)}%',
                        style: p.title(36),
                      ),
                      Text('of ${prov.currentPlan.name}', style: p.small),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  progress.isComplete
                      ? 'Finished'
                      : 'Day ${prov.getCurrentPlanDay()} of ${progress.total} · ${durationLabel(progress.total)}',
                  style: p.strong,
                ),
              ),
              const SizedBox(height: 22),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.15,
                children: [
                  _stat(
                    CupertinoIcons.checkmark_seal,
                    '${progress.completed}',
                    'days read',
                  ),
                  _stat(CupertinoIcons.flame, '${prov.streak}', 'in a row'),
                  _stat(
                    CupertinoIcons.book,
                    '${(prov.chapterShare * prov.units.length).round()}',
                    'chapters',
                  ),
                  _stat(
                    CupertinoIcons.compass,
                    '${u.extraChaptersRead}',
                    'chapters beyond',
                  ),
                  _stat(
                    CupertinoIcons.question_circle,
                    '${u.quizzesTaken}',
                    'quizzes',
                  ),
                  _stat(
                    CupertinoIcons.star,
                    u.quizzesTaken == 0 ? '–' : '${u.bestQuizScore}%',
                    'best quiz',
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _calendar(prov),
              const SizedBox(height: 26),
              FutureBuilder<List<CompletedPlan>>(
                future: prov.getPlanHistory(),
                builder: (context, snap) {
                  final h = snap.data ?? const [];
                  if (h.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Label('Plans finished'),
                      const SizedBox(height: 6),
                      for (final c in h.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.rosette, color: p.gold),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.planName, style: p.strong),
                                    Text(
                                      '${DateFormat('MMM d, y').format(c.startDate)} – ${DateFormat('MMM d, y').format(c.completedDate)} · ${c.actualDays} days',
                                      style: p.small,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (progress.isComplete) ...[
                const SizedBox(height: 18),
                ParchButton(
                  'Begin a new plan',
                  kind: Btn.solid,
                  expand: true,
                  onTap: () => choosePlanSheet(context, fresh: true),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    final p = context.parch;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: p.accent),
          const SizedBox(height: 4),
          Text(value, style: p.title(21)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: p.small.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  // The plan's days on a calendar, a month at a time
  Widget _calendar(AppProvider prov) {
    final p = context.parch;
    final start = prov.userData!.startDate;
    final last = prov.getDateForPlanDay(prov.totalPlanDays);
    final months = (last.year - start.year) * 12 + last.month - start.month + 1;
    final now = DateTime.now();
    final at =
        (_month ?? (now.year - start.year) * 12 + now.month - start.month)
            .clamp(0, months - 1);
    final month = DateTime(start.year, start.month + at);
    final first = DateTime(month.year, month.month, 1);
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    final today = DateTime.now();
    int planDayOf(DateTime d) =>
        DateTime.utc(
          d.year,
          d.month,
          d.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
        1;

    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              Tap(
                onTap: at > 0 ? () => setState(() => _month = at - 1) : null,
                padding: const EdgeInsets.all(6),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 18,
                  color: p.inkStrong,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM y').format(month),
                    style: p.title(16),
                  ),
                ),
              ),
              Tap(
                onTap: at < months - 1
                    ? () => setState(() => _month = at + 1)
                    : null,
                padding: const EdgeInsets.all(6),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: p.inkStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(d, style: p.label.copyWith(fontSize: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (var d = 1; d <= daysIn; d++)
                Builder(
                  builder: (context) {
                    final date = DateTime(month.year, month.month, d);
                    final pd = planDayOf(date);
                    final inPlan = pd >= 1 && pd <= prov.totalPlanDays;
                    final done = inPlan && prov.isDayComplete(pd);
                    final isToday =
                        date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;
                    final missed =
                        inPlan && !done && pd < prov.getCurrentPlanDay();
                    final read = prov.didReadOnDate(date);
                    return Tap(
                      onTap: inPlan
                          ? () async {
                              final r = prov.getReadingForDay(pd);
                              await push(context, ReadingScreen(reading: r));
                            }
                          : null,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done
                              ? p.accent
                              : missed
                              ? p.warning.withValues(alpha: .16)
                              : inPlan
                              ? p.deep.withValues(alpha: .6)
                              : null,
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(color: p.rubric, width: 2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$d',
                              style: TextStyle(
                                fontFamily: Parchment.serif,
                                fontSize: 15,
                                fontWeight: done || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: done
                                    ? p.onAccent
                                    : inPlan
                                    ? p.ink
                                    : p.faded.withValues(alpha: .5),
                              ),
                            ),
                            if (read && !done)
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: p.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _key(p.accent, 'Read'),
              _key(p.warning.withValues(alpha: .4), 'To catch up'),
              _key(p.deep, 'Ahead'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(Color c, String label) {
    final p = context.parch;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: p.small.copyWith(fontSize: 13)),
      ],
    );
  }
}
