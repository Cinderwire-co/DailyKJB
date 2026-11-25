import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../utils/constants.dart';
import 'bible_screen.dart' show readingStyleSheet;
import 'focus_screen.dart';
import 'home_screen.dart' show choosePlanSheet;

const appVersion = '1.1.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Leaf(
      title: 'Settings',
      back: false,
      body: Consumer<AppProvider>(
        builder: (context, prov, _) {
          final u = prov.userData!;
          Widget section(String label, List<Widget> children) => Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Label(label),
                ),
                Panel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  child: Column(children: children),
                ),
              ],
            ),
          );
          final time = TimeOfDay(
            hour: u.notificationHour,
            minute: u.notificationMinute,
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              MediaQuery.paddingOf(context).bottom + 40,
            ),
            children: [
              section('You', [
                RowLink(
                  icon: CupertinoIcons.person,
                  title: u.name.isEmpty ? 'Your name' : u.name,
                  subtitle: 'How the app greets you',
                  onTap: () => _rename(context, prov),
                ),
              ]),
              section('Reading plan', [
                RowLink(
                  icon: CupertinoIcons.book,
                  title: prov.currentPlan.name,
                  subtitle:
                      '${durationLabel(u.targetDays)} · ${prov.currentPlan.description}',
                  onTap: () => choosePlanSheet(context),
                ),
                const Hairline(),
                SwitchLine(
                  icon: CupertinoIcons.music_note_2,
                  title: 'A Psalm each day',
                  subtitle: 'Read alongside the plan',
                  value: u.addDailyPsalm,
                  onChanged: prov.toggleDailyPsalm,
                ),
                const Hairline(),
                SwitchLine(
                  icon: CupertinoIcons.lightbulb,
                  title: 'A Proverb each day',
                  subtitle: 'Through the 31 chapters, a month at a time',
                  value: u.addDailyProverb,
                  onChanged: prov.toggleDailyProverb,
                ),
                const Hairline(),
                RowLink(
                  icon: CupertinoIcons.arrow_counterclockwise,
                  title: 'Start over',
                  subtitle: 'Day 1 today, nothing read',
                  danger: true,
                  onTap: () async {
                    if (await sure(
                      context,
                      'Start the plan over?',
                      ok: 'Start over',
                      text: 'Every day of this plan will be marked unread, and day 1 will be today. Notes and highlights stay.',
                    )) {
                      await prov.startFresh();
                    }
                  },
                ),
              ]),
              section('Reminders', [
                SwitchLine(
                  icon: CupertinoIcons.bell,
                  title: 'A daily reminder',
                  subtitle: 'And a gentle one at 8 in the evening if the day isn\'t read',
                  value: u.notificationsEnabled,
                  onChanged: prov.toggleNotifications,
                ),
                if (u.notificationsEnabled) ...[
                  const Hairline(),
                  RowLink(
                    icon: CupertinoIcons.clock,
                    title: 'At',
                    trailing: time.format(context),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (t != null) {
                        await prov.setNotificationTime(t.hour, t.minute);
                      }
                    },
                  ),
                ],
              ]),
              section('How it looks', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      for (final (k, l, icon) in const [
                        ('light', 'Parchment', CupertinoIcons.sun_max),
                        ('dark', 'Lamplight', CupertinoIcons.moon_stars),
                        (
                          'system',
                          'As phone',
                          CupertinoIcons.device_phone_portrait,
                        ),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Tap(
                              onTap: () => prov.setThemeMode(k),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: u.themeMode == k
                                      ? p.accentSoft
                                      : p.page,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: u.themeMode == k ? p.accent : p.rule,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      icon,
                                      color: u.themeMode == k
                                          ? p.accent
                                          : p.faded,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l,
                                      style: p.small.copyWith(
                                        color: p.inkStrong,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Hairline(),
                RowLink(
                  icon: CupertinoIcons.textformat_size,
                  title: 'Type, size and layout',
                  subtitle:
                      '${switch (prov.readingFont) {
                        'georgia' => 'Georgia',
                        'sans' => 'Clean',
                        _ => 'Garamond',
                      }} · ${(prov.fontScale * 100).round()}% · ${prov.verseLayout == 'paragraph' ? 'Paragraph' : 'Verse by verse'}',
                  onTap: () => readingStyleSheet(context),
                ),
              ]),
              ListenableBuilder(
                listenable: AiService.i,
                builder: (context, _) {
                  final ai = AiService.i;
                  final can = ai.state == AiState.available;
                  return section('Apple Intelligence', [
                    if (can)
                      SwitchLine(
                        icon: CupertinoIcons.sparkles,
                        title: 'Study help on this iPhone',
                        subtitle: 'Notes on verses, words in plain English, and quizzes. Written on the phone; nothing leaves it.',
                        value: prov.aiEnabled,
                        onChanged: prov.setAiEnabled,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              CupertinoIcons.sparkles,
                              size: 21,
                              color: p.faded,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                ai.statusText,
                                style: p.small.copyWith(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]);
                },
              ),
              section('Focus Mode', [
                RowLink(
                  icon: CupertinoIcons.lock_shield,
                  title: 'Read before other apps',
                  subtitle: u.appBlockingEnabled ? 'On' : 'Off',
                  onTap: () => push(context, const FocusScreen()),
                ),
              ]),
              section('About', [
                RowLink(
                  icon: CupertinoIcons.info,
                  title: 'Daily KJB',
                  trailing: 'Version $appVersion',
                  onTap: () => _about(context),
                ),
              ]),
              const SizedBox(height: 6),
              const Ornament(width: 100),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '"Thy word is a lamp unto my feet,\nand a light unto my path."',
                  textAlign: TextAlign.center,
                  style: p.small.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _rename(BuildContext context, AppProvider prov) async {
    final c = TextEditingController(text: prov.userData?.name ?? '');
    final name = await sheet<String>(
      context,
      title: 'Your name',
      body: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: ctx.parch.body,
          ),
          const SizedBox(height: 12),
          ParchButton(
            'Save',
            kind: Btn.solid,
            expand: true,
            onTap: () => Navigator.pop(ctx, c.text.trim()),
          ),
        ],
      ),
    );
    if (name != null) await prov.setName(name);
  }

  void _about(BuildContext context) {
    sheet(
      context,
      title: 'Daily KJB',
      body: (ctx) {
        final p = ctx.parch;
        Widget credit(String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: p.strong.copyWith(fontSize: 16)),
              Text(text, style: p.small),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The King James Bible, a little every day. Everything in the app works without a connection: the Bible, Strong\'s, Webster\'s 1828, cross references, your notes and highlights. Nothing you write leaves your phone.',
              style: p.body,
            ),
            const SizedBox(height: 18),
            const Label('With thanks'),
            const SizedBox(height: 8),
            credit(
              'The King James Bible',
              'Text in the public domain; the edition used is by Arul John (MIT).',
            ),
            credit(
              "Strong's Exhaustive Concordance",
              'James Strong, 1894. Public domain, via Open Scriptures.',
            ),
            credit(
              'Strong\'s numbers for each word',
              'CrossWire Bible Society, KJV module.',
            ),
            credit(
              "Webster's 1828 Dictionary",
              'Noah Webster, An American Dictionary of the English Language. Public domain; the edition used is by DataWar (MIT).',
            ),
            credit(
              'Cross references',
              'Cross references from OpenBible.info (CC BY), from the Treasury of Scripture Knowledge.',
            ),
            credit(
              'Type',
              'Cinzel by Natanael Gama and EB Garamond by Georg Duffner and Octavio Pardo (SIL Open Font License).',
            ),
          ],
        );
      },
    );
  }
}
