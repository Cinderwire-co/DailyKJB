import 'dart:io' show File, Platform;

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible/kjb.dart';
import 'models/highlight.dart';
import 'models/user_data.dart';
import 'models/verse_note.dart';
import 'providers/app_provider.dart';
import 'screens/focus_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reader.dart' show BibleNav;
import 'screens/reading_screen.dart';
import 'screens/verse_share_screen.dart';
import 'screens/verse_study_screen.dart';
import 'services/bible_service.dart';

import 'package:provider/provider.dart';

/// App Store screenshots: started with DKJB_SHOT set to a scene in the launch
/// environment (the simulator: SIMCTL_CHILD_DKJB_SHOT), the app fills itself
/// with a reader's few weeks and opens at that scene. Never set otherwise.
class Screenshots {
  static String? _scene;
  static bool _aimed = false;
  static String _theme = 'light';

  static String? get scene => _scene;
  static String get theme => _theme;

  /// The scene and theme: from the launch environment, or from
  /// Documents/screenshot.txt ("scene theme"), which a screenshot script puts
  /// in the simulator's copy of the app.
  static Future<void> _find() async {
    try {
      final s = Platform.environment['DKJB_SHOT'];
      if (s != null && s.isNotEmpty) {
        _scene = s;
        _theme = Platform.environment['DKJB_THEME'] ?? 'light';
        return;
      }
      final f = File(
        '${(await getApplicationDocumentsDirectory()).path}/screenshot.txt',
      );
      if (await f.exists()) {
        final x = (await f.readAsString()).trim().split(RegExp(r'\s+'));
        _scene = x.first.isEmpty ? null : x.first;
        if (x.length > 1) _theme = x[1];
      }
    } catch (_) {}
  }

  /// Verses to show chosen in the Bible scene.
  static Set<int> get chosen => scene == 'bible' ? {16, 17} : const {};

  /// The word whose sheet the study scene opens (by its place in the verse).
  static int? get openWord => scene == 'word' ? 3 : null;

  /// Before the app starts: a reader forty days into the Bible in a year.
  static Future<void> seed() async {
    await _find();
    final s = scene;
    if (s == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (s == 'onboarding') return;
    await Kjb.load();
    final units = await BibleService().loadUnits('whole_bible');
    final days = BibleService.spread(units, 365);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const behind = 40;
    final done = <int>[
      for (var d = 0; d < behind; d++)
        if (d != 17) ...days[d].map((u) => u.index),
      ...days[17].map((u) => u.index),
    ];
    final user = UserData(
      name: 'Grace',
      planId: 'whole_bible',
      targetDays: 365,
      startDate: today.subtract(const Duration(days: behind)),
      completedReadings: [],
      completedUnits: done,
      lastReadDate: today.subtract(const Duration(days: 1)),
      notificationHour: 7,
      addDailyPsalm: true,
      themeMode: theme,
      readDates: [
        for (var d = 1; d <= 23; d++) _day(today.subtract(Duration(days: d))),
        for (var d = 25; d <= behind; d++)
          _day(today.subtract(Duration(days: d))),
      ],
      extraChaptersRead: 37,
      quizzesTaken: 14,
      totalQuizScore: 610,
      bestQuizScore: 100,
      appBlockingEnabled: s == 'focus',
    );
    await prefs.setString('user_data', user.toJsonString());

    final marks = [
      ('John', 3, 16, 16, 'yellow', DateTime(now.year, now.month, now.day - 2)),
      ('Psalms', 23, 1, 3, 'green', DateTime(now.year, now.month, now.day - 4)),
      (
        'Romans',
        8,
        28,
        28,
        'orange',
        DateTime(now.year, now.month, now.day - 6),
      ),
      (
        'Isaiah',
        40,
        31,
        31,
        'blue',
        DateTime(now.year, now.month, now.day - 9),
      ),
      (
        'Proverbs',
        3,
        5,
        6,
        'pink',
        DateTime(now.year, now.month, now.day - 12),
      ),
      (
        'Genesis',
        1,
        1,
        1,
        'yellow',
        DateTime(now.year, now.month, now.day - 40),
      ),
      (
        'Genesis',
        22,
        8,
        8,
        'orange',
        DateTime(now.year, now.month, now.day - 25),
      ),
      (
        'Exodus',
        14,
        13,
        14,
        'green',
        DateTime(now.year, now.month, now.day - 20),
      ),
    ];
    await prefs.setString(
      'verse_highlights',
      VerseHighlight.toJsonString([
        for (final m in marks)
          VerseHighlight(
            id: '${m.$1}_${m.$2}_${m.$3}',
            book: m.$1,
            chapter: m.$2,
            startVerse: m.$3,
            endVerse: m.$4,
            color: m.$5,
            createdAt: m.$6,
          ),
      ]),
    );
    VerseNote note(String book, int c, int v1, int v2, String text, int ago) {
      final b = Kjb.named(book)!.id;
      final vs = Kjb.verses(b, c);
      final at = DateTime(now.year, now.month, now.day - ago, 7, 20);
      return VerseNote(
        id: '${book}_${c}_$v1',
        book: book,
        chapter: c,
        startVerse: v1,
        endVerse: v2,
        content: text,
        verseTexts: [for (var n = v1; n <= v2; n++) vs[n - 1]],
        createdAt: at,
        updatedAt: at,
      );
    }

    await prefs.setString(
      'verse_notes',
      VerseNote.toJsonString([
        note(
          'Genesis',
          22,
          8,
          8,
          'God will provide himself a lamb. Abraham saw it from afar; we see it fulfilled in Christ.',
          25,
        ),
        note(
          'Exodus',
          14,
          13,
          14,
          'Stand still. The battle is the Lord\'s, not mine.',
          20,
        ),
        note(
          'Psalms',
          23,
          1,
          3,
          'He leadeth me. Not drives, leads. I only have to follow.',
          4,
        ),
        note(
          'Romans',
          8,
          28,
          28,
          'All things, not some things. Read this the morning of Dad\'s surgery.',
          6,
        ),
        note('John', 3, 16, 16, 'Whosoever. That includes me.', 2),
      ]),
    );
    await prefs.setString('bible_at', s == 'bible' ? '43:3' : '19:23');
    await prefs.setString(
      'bible_search_history',
      '["grace","lamp unto my feet","Psalm 91"]',
    );
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Widget build(BuildContext context, String scene) {
    final prov = context.read<AppProvider>();
    if (scene == 'bible' && !_aimed) {
      _aimed = true;
      BibleNav.target.value = (43, 3, 14);
    }
    return switch (scene) {
      'onboarding' => const OnboardingScreen(),
      'bible' => const HomeScreen(initialTab: 1),
      'journal' => const HomeScreen(initialTab: 2),
      'progress' => const HomeScreen(initialTab: 3),
      'settings' => const HomeScreen(initialTab: 4),
      'reading' => ReadingScreen(reading: prov.getTodaysReading()),
      'study' ||
      'word' ||
      'notes' => const VerseStudyScreen(book: 43, chapter: 3, verse: 16),
      'share' => const VerseShareScreen(
        reference: 'Lamentations 3:22–23',
        text: 'It is of the LORD\'s mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.',
      ),
      'focus' => const FocusScreen(),
      _ => const HomeScreen(),
    };
  }
}
