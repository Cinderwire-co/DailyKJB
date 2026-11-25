import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../utils/constants.dart';
import '../widgets/passcode_dialog.dart';
import 'focus_screen.dart' show chooseBlockedApps;

/// First open: a name, a plan, how long, a reminder, a Psalm or Proverb
/// alongside, light or dark, and Focus Mode if wanted.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _page = 0;
  String _plan = availablePlans.first.id;
  int _days = 365;
  List<int> _durations = planDurationOptions;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  bool _psalm = false, _proverb = false;
  String _theme = 'system';
  bool _focus = false;
  bool _busy = false;

  static const _count = 8;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int by) {
    FocusScope.of(context).unfocus();
    final to = (_page + by).clamp(0, _count - 1);
    HapticFeedback.selectionClick();
    _pages.animateToPage(
      to,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickPlan(String id) async {
    final units = await context.read<AppProvider>().unitsFor(id);
    if (!mounted) return;
    final d = context.read<AppProvider>().durationsFor(units);
    setState(() {
      _plan = id;
      _durations = d;
      if (!d.contains(_days)) _days = 365;
    });
  }

  Future<void> _setUpFocus() async {
    final s = context.read<AppProvider>().appBlockingService;
    if (!await s.isSupported()) {
      if (mounted) {
        toast(
          context,
          'Focus Mode isn\'t available on this device',
          error: true,
        );
      }
      return;
    }
    if (!await s.requestAuthorization()) {
      if (mounted) {
        toast(
          context,
          Platform.isIOS
              ? 'Screen Time access is needed for Focus Mode'
              : 'Allow the permissions, then try again',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    final n = await chooseBlockedApps(context);
    if (mounted) setState(() => _focus = n > 0);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final prov = context.read<AppProvider>();
    final name = _name.text.trim();
    await prov.createUser(
      name: name.isEmpty ? '' : name[0].toUpperCase() + name.substring(1),
      planId: _plan,
      targetDays: _days,
      addDailyPsalm: _psalm,
      addDailyProverb: _proverb,
      notificationHour: _time.hour,
      notificationMinute: _time.minute,
      themeMode: _theme,
    );
    if (_focus && mounted) {
      final code = await showPasscodeDialog(
        context: context,
        mode: PasscodeMode.setup,
      );
      if (code != null) await prov.setAccountabilityPasscode(code);
      await prov.toggleAppBlocking(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final last = _page == _count - 1;
    return Scaffold(
      backgroundColor: p.page,
      resizeToAvoidBottomInset: true,
      body: Paper(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < _count; i++)
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
                child: Measure(
                  width: 620,
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _welcome(),
                      _nameStep(),
                      _planStep(),
                      _lengthStep(),
                      _reminderStep(),
                      _extrasStep(),
                      _lookStep(),
                      _focusStep(),
                    ],
                  ),
                ),
              ),
              Measure(
                width: 620,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      if (_page > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ParchButton('Back', onTap: () => _go(-1)),
                        ),
                      Expanded(
                        child: ParchButton(
                          _page == 0
                              ? 'Begin'
                              : last
                              ? (_busy ? 'One moment…' : 'Start reading')
                              : 'Continue',
                          kind: Btn.solid,
                          expand: true,
                          onTap: _busy ? null : (last ? _finish : () => _go(1)),
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
    );
  }

  Widget _step({
    required String title,
    String? text,
    required List<Widget> children,
  }) {
    final p = context.parch;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
      children: [
        Text(title, style: p.title(27)),
        if (text != null) ...[
          const SizedBox(height: 8),
          Text(text, style: p.body.copyWith(color: p.faded)),
        ],
        const SizedBox(height: 26),
        ...children,
      ],
    );
  }

  Widget _welcome() {
    final p = context.parch;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.leaf,
              border: Border.all(color: p.rule),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: .2),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Icon(CupertinoIcons.book_fill, size: 46, color: p.accent),
          ),
          const SizedBox(height: 28),
          Text('DAILY KJB', style: p.title(34).copyWith(letterSpacing: 5)),
          const SizedBox(height: 10),
          Text(
            'The King James Bible, a little every day',
            textAlign: TextAlign.center,
            style: p.body.copyWith(color: p.faded, fontSize: 19),
          ),
          const SizedBox(height: 30),
          const Ornament(width: 150),
          const SizedBox(height: 26),
          Text(
            '"Thy word is a lamp unto my feet, and a light unto my path."',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Parchment.serif,
              fontStyle: FontStyle.italic,
              fontSize: 21,
              height: 1.45,
              color: p.inkStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text('PSALM 119:105', style: p.label.copyWith(color: p.accent)),
        ],
      ),
    );
  }

  Widget _nameStep() {
    final p = context.parch;
    return _step(
      title: 'What shall we call you?',
      text: 'For a word of encouragement now and then.',
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _go(1),
          style: p.body.copyWith(fontSize: 20),
          decoration: const InputDecoration(hintText: 'Your first name'),
        ),
      ],
    );
  }

  Widget _planStep() {
    final p = context.parch;
    return _step(
      title: 'What would you like to read?',
      children: [
        for (final plan in availablePlans)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              accent: _plan == plan.id,
              color: _plan == plan.id
                  ? p.accentSoft.withValues(alpha: .55)
                  : null,
              onTap: () => _pickPlan(plan.id),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _plan == plan.id
                        ? CupertinoIcons.largecircle_fill_circle
                        : CupertinoIcons.circle,
                    color: _plan == plan.id ? p.accent : p.faded,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name, style: p.strong.copyWith(fontSize: 18)),
                        Text(plan.description, style: p.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _lengthStep() {
    final p = context.parch;
    return _step(
      title: 'Over how long?',
      text: 'The chapters are shared out evenly. You can change this any time.',
      children: [
        for (final d in _durations)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              accent: _days == d,
              color: _days == d ? p.accentSoft.withValues(alpha: .55) : null,
              onTap: () => setState(() => _days = d),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      durationLabel(d),
                      style: p.strong.copyWith(fontSize: 18),
                    ),
                  ),
                  Text(switch (d) {
                    90 => 'A strong pace',
                    180 => 'Steady',
                    365 => 'The classic',
                    _ => 'Unhurried',
                  }, style: p.small),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _reminderStep() {
    final p = context.parch;
    return _step(
      title: 'When do you like to read?',
      text: 'A reminder then, and a gentle one in the evening if the day isn\'t read.',
      children: [
        Panel(
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: _time,
            );
            if (t != null) setState(() => _time = t);
          },
          child: Row(
            children: [
              Icon(CupertinoIcons.bell, color: p.accent),
              const SizedBox(width: 14),
              Expanded(child: Text('Remind me at', style: p.body)),
              Text(_time.format(context), style: p.title(22)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (h, l) in const [
              (6, 'Early'),
              (7, 'Morning'),
              (12, 'Noon'),
              (18, 'Evening'),
              (21, 'Night'),
            ])
              Pill(
                l,
                on: _time.hour == h && _time.minute == 0,
                onTap: () =>
                    setState(() => _time = TimeOfDay(hour: h, minute: 0)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _extrasStep() {
    return _step(
      title: 'Anything alongside?',
      text: 'Read with the plan each day; they don\'t count toward it.',
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SwitchLine(
                icon: CupertinoIcons.music_note_2,
                title: 'A Psalm each day',
                subtitle: 'Through all 150',
                value: _psalm,
                onChanged: (v) => setState(() => _psalm = v),
              ),
              const Hairline(),
              SwitchLine(
                icon: CupertinoIcons.lightbulb,
                title: 'A Proverb each day',
                subtitle: '31 chapters, about a month',
                value: _proverb,
                onChanged: (v) => setState(() => _proverb = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lookStep() {
    final p = context.parch;
    Widget swatch(String key, String label, Parchment t) => Expanded(
      child: Tap(
        onTap: () => setState(() => _theme = key),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.page,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _theme == key ? p.accent : p.rule,
                  width: _theme == key ? 2.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        fontFamily: Parchment.caps,
                        fontSize: 28,
                        color: t.rubric,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '1 ',
                          style: TextStyle(
                            fontFamily: Parchment.caps,
                            fontSize: 9,
                            color: t.accent,
                          ),
                        ),
                        TextSpan(
                          text: 'In the beginning God created the heaven and the earth.',
                          style: TextStyle(
                            fontFamily: Parchment.serif,
                            fontSize: 13,
                            color: t.ink,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: p.strong.copyWith(fontSize: 15)),
          ],
        ),
      ),
    );
    return _step(
      title: 'Light or dark?',
      text: 'Parchment by day, lamplight by night. Change it any time.',
      children: [
        Row(
          children: [
            swatch('light', 'Parchment', Parchment.light),
            const SizedBox(width: 12),
            swatch('dark', 'Lamplight', Parchment.lamplight),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Pill(
            'Follow my phone',
            icon: CupertinoIcons.device_phone_portrait,
            on: _theme == 'system',
            onTap: () => setState(() => _theme = 'system'),
          ),
        ),
      ],
    );
  }

  Widget _focusStep() {
    final p = context.parch;
    return _step(
      title: 'Read before anything else?',
      text: 'Focus Mode keeps the apps you choose closed each day until you\'ve read. Entirely optional; you can set it up later in Settings.',
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _focus
                        ? CupertinoIcons.checkmark_shield_fill
                        : CupertinoIcons.lock_shield,
                    color: p.accent,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _focus
                          ? 'Apps chosen. Focus Mode will be on.'
                          : 'Choose apps like social media or games.',
                      style: p.body,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ParchButton(
                _focus ? 'Change the apps' : 'Set up Focus Mode',
                icon: CupertinoIcons.square_grid_2x2,
                expand: true,
                onTap: _setUpFocus,
              ),
              if (_focus)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ParchButton(
                    'Not now',
                    kind: Btn.quiet,
                    expand: true,
                    onTap: () => setState(() => _focus = false),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          Platform.isIOS
              ? 'Uses Apple\'s Screen Time. DailyKJB never sees which apps you choose.'
              : 'Needs Usage Access and permission to display over other apps.',
          style: p.small,
        ),
      ],
    );
  }
}
