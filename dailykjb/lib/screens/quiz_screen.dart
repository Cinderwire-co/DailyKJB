import 'package:confetti/confetti.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../bible/kjb.dart';
import '../models/reading.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/quiz_service.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// A quiz on the day's reading. With Apple Intelligence on the phone,
/// questions on what the passage says; otherwise (or if they don't come out
/// right) verses from it with words to fill in. Pass, and the day is read.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.reading});
  final DayReading reading;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _service = QuizService();
  final _confetti = ConfettiController(duration: const Duration(seconds: 4));
  bool _loading = true;

  // Questions on the passage (Apple Intelligence)
  List<AiQuestion>? _ai;
  final _picked = <int, int>{};

  // Words to fill in
  List<QuizQuestion> _words = [];
  late List<String?> _fills;
  late List<String> _options;
  int _wrong = 0;
  bool _solved = false;
  final _scores = <int>[];

  int _index = 0;
  QuizResult? _result;

  int get _count => _ai?.length ?? _words.length;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (AiService.i.ready) {
      try {
        final text = [
          for (final s in widget.reading.spans)
            '${s.label}\n${s.verses().map((v) => '${v.$1} ${v.$2}').join('\n')}',
        ].join('\n\n');
        final qs = await AiService.i.quiz(
          Kjb.describe(widget.reading.spans),
          text,
        );
        if (!mounted) return;
        setState(() {
          _ai = qs.take(5).toList();
          _loading = false;
        });
        return;
      } catch (_) {
        // The word quiz instead
      }
    }
    _words = _service.generateQuiz(widget.reading.spans);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _ai = null;
      if (_words.isNotEmpty) _initWords();
    });
  }

  void _initWords() {
    final q = _words[_index];
    _fills = List.filled(q.blankIndices.length, null);
    _options = List.of(q.options);
    _wrong = 0;
    _solved = false;
  }

  void _place(int blank, String word) {
    if (_solved) return;
    final q = _words[_index];
    setState(() {
      if (_fills[blank] != null) _options.add(_fills[blank]!);
      if (word == q.correctAnswers[blank]) {
        HapticFeedback.selectionClick();
        _fills[blank] = word;
        _options.remove(word);
        if (!_fills.contains(null)) {
          HapticFeedback.mediumImpact();
          final score =
              (QuizService.pointsPerCorrect -
                      _wrong * QuizService.penaltyPerWrong)
                  .clamp(0, QuizService.pointsPerCorrect);
          _scores.add(score);
          _solved = true;
        }
      } else {
        HapticFeedback.heavyImpact();
        _wrong++;
      }
    });
  }

  void _choose(int q, int c) {
    if (_picked.containsKey(q)) return;
    final right = _ai![q].answer == c;
    right ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    setState(() {
      _picked[q] = c;
      _scores.add(right ? QuizService.pointsPerCorrect : 0);
    });
  }

  void _next() {
    if (_index < _count - 1) {
      setState(() {
        _index++;
        if (_ai == null) _initWords();
      });
      return;
    }
    final r = _service.calculateResult(_scores);
    setState(() => _result = r);
    if (r.passed) _confetti.play();
  }

  Future<void> _finish() async {
    final prov = context.read<AppProvider>();
    final r = _result!;
    await prov.recordQuizResult(r.score, r.maxScore);
    if (r.passed) await prov.markReadingCompleteAndUnblock(widget.reading);
    if (mounted) Navigator.of(context).pop(r.passed);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Leaf(
      title: 'Quiz',
      body: Stack(
        children: [
          if (_loading)
            Waiting(
              text: AiService.i.ready
                  ? 'Writing questions on this device…'
                  : null,
            )
          else if (_count == 0)
            const Empty('There isn\'t enough here for a quiz.')
          else if (_result != null)
            _results()
          else
            ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.paddingOf(context).bottom + 30,
              ),
              children: [
                Row(
                  children: [
                    Label('Question ${_index + 1} of $_count'),
                    const Spacer(),
                    if (_ai != null)
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 13,
                            color: p.faded,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Apple Intelligence',
                            style: p.small.copyWith(fontSize: 12.5),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / _count,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 22),
                if (_ai != null) _aiQuestion() else _wordQuestion(),
              ],
            ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              colors: [
                p.accent,
                p.gold,
                p.rubric,
                Parchment.highlights['green']!,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiQuestion() {
    final p = context.parch;
    final q = _ai![_index];
    final picked = _picked[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          q.question,
          style: p
              .title(20)
              .copyWith(
                fontFamily: Parchment.serif,
                letterSpacing: 0,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 18),
        for (final (j, c) in q.choices.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tap(
              onTap: picked == null ? () => _choose(_index, j) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: picked == null
                      ? p.leaf
                      : j == q.answer
                      ? p.success.withValues(alpha: .16)
                      : picked == j
                      ? p.danger.withValues(alpha: .14)
                      : p.leaf,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: picked == null
                        ? p.rule
                        : j == q.answer
                        ? p.success
                        : picked == j
                        ? p.danger
                        : p.rule,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c,
                        style: p.body.copyWith(color: p.inkStrong),
                      ),
                    ),
                    if (picked != null && j == q.answer)
                      Icon(CupertinoIcons.checkmark_alt, color: p.success),
                    if (picked == j && j != q.answer)
                      Icon(CupertinoIcons.xmark, color: p.danger),
                  ],
                ),
              ),
            ),
          ),
        if (picked != null) ...[
          if (q.reference.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${q.reference}: "${Kjb.verse(q.reference)?.$2 ?? ''}"',
                style: p.small.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ParchButton(
            _index < _count - 1 ? 'Next question' : 'See how you did',
            kind: Btn.solid,
            expand: true,
            onTap: _next,
          ),
        ],
      ],
    );
  }

  Widget _wordQuestion() {
    final p = context.parch;
    final q = _words[_index];
    var blank = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          q.reference.toUpperCase(),
          style: p.label.copyWith(color: p.accent),
        ),
        const SizedBox(height: 10),
        Panel(
          child: Wrap(
            spacing: 5,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final w in q.displayWords)
                if (w.contains('___'))
                  Builder(
                    builder: (_) {
                      final b = blank++;
                      final filled = _fills[b];
                      final parts = w.split('___');
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (parts.first.isNotEmpty)
                            Text(
                              parts.first,
                              style: p.body.copyWith(fontSize: 19),
                            ),
                          Tap(
                            onTap: filled == null || _solved
                                ? null
                                : () => setState(() {
                                    _options.add(filled);
                                    _fills[b] = null;
                                  }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              constraints: const BoxConstraints(minWidth: 64),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: filled == null
                                    ? p.deep
                                    : p.success.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(4),
                                border: Border(
                                  bottom: BorderSide(
                                    color: filled == null
                                        ? p.accent
                                        : p.success,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                filled ?? ' ',
                                textAlign: TextAlign.center,
                                style: p.body.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: p.inkStrong,
                                ),
                              ),
                            ),
                          ),
                          if (parts.length > 1 && parts.last.isNotEmpty)
                            Text(
                              parts.last,
                              style: p.body.copyWith(fontSize: 19),
                            ),
                        ],
                      );
                    },
                  )
                else
                  Text(w, style: p.body.copyWith(fontSize: 19)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (!_solved) ...[
          Text(
            'Tap the words that belong in the blanks, in order.',
            style: p.small,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _options)
                Pill(
                  o,
                  onTap: () {
                    final empty = _fills.indexOf(null);
                    if (empty >= 0) _place(empty, o);
                  },
                ),
            ],
          ),
          if (_wrong > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _wrong == 1
                    ? 'Not that one. Try another.'
                    : 'Not that one. $_wrong tries so far.',
                style: p.small.copyWith(color: p.danger),
              ),
            ),
        ] else ...[
          Row(
            children: [
              Icon(CupertinoIcons.checkmark_seal_fill, color: p.success),
              const SizedBox(width: 8),
              Text(
                _wrong == 0 ? 'Right the first time' : 'Got it',
                style: p.strong,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ParchButton(
            _index < _count - 1 ? 'Next verse' : 'See how you did',
            kind: Btn.solid,
            expand: true,
            onTap: _next,
          ),
        ],
      ],
    );
  }

  Widget _results() {
    final p = context.parch;
    final r = _result!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      children: [
        Center(
          child: Ring(
            value: r.percentage,
            size: 150,
            stroke: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.grade,
                  style: p
                      .title(46)
                      .copyWith(color: r.passed ? p.accent : p.faded),
                ),
                Text('${(r.percentage * 100).round()}%', style: p.small),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(r.passed ? 'Well done' : 'Not quite', style: p.title(24)),
        ),
        const SizedBox(height: 8),
        Text(
          r.passed ? 'You know what you read. The day is marked read.' : 'Read it through once more and try again. It\'s about remembering it, not the score.',
          textAlign: TextAlign.center,
          style: p.body.copyWith(color: p.faded),
        ),
        const SizedBox(height: 28),
        ParchButton(
          r.passed ? 'Done' : 'Back to the reading',
          kind: Btn.solid,
          expand: true,
          onTap: _finish,
        ),
      ],
    );
  }
}
