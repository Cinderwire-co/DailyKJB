import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../bible/kjb.dart';
import '../models/user_data.dart';
import '../models/reading.dart';
import '../models/plan_history.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/bible_service.dart';
import '../services/app_blocking_service.dart';
import '../services/notification_service.dart';
import '../services/notes_service.dart';
import '../services/widget_sync.dart';
import '../services/highlight_service.dart';
import '../utils/constants.dart';
import '../utils/notification_messages.dart';

typedef Progress = ({
  int completed,
  int total,
  double percentage,
  bool isComplete,
});

class AppProvider extends ChangeNotifier {
  UserData? _userData;
  List<Reading> _readings = [];
  List<PlanUnit> _units = [];
  List<List<PlanUnit>> _days = [];
  Set<int> _done = {};
  bool _isLoading = true;
  final BibleService _bibleService = BibleService();
  final NotificationService _notificationService = NotificationService();
  final NotesService _notesService = NotesService();
  final HighlightService _highlightService = HighlightService();
  final AppBlockingService _appBlockingService = AppBlockingService();

  AppBlockingService get appBlockingService => _appBlockingService;

  UserData? get userData => _userData;
  List<Reading> get readings => _readings;
  List<PlanUnit> get units => _units;
  bool get isLoading => _isLoading;
  bool get isFirstRun => _userData == null;
  int get totalPlanDays => _userData?.targetDays ?? 365;

  ReadingPlan get currentPlan {
    if (_userData == null) return availablePlans.first;
    return availablePlans.firstWhere(
      (p) => p.id == _userData!.planId,
      orElse: () => availablePlans.first,
    );
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // Each on its own: one failing (reminders on a phone that refuses them,
    // say) mustn't leave the app on a blank page
    Future<void> safely(Future<void> f, String what) =>
        f.catchError((Object e) => debugPrint('Could not load $what: $e'));
    await Future.wait([
      safely(Kjb.load(), 'the Bible'),
      safely(_notificationService.initialize(), 'reminders'),
      safely(_notesService.loadNotes(), 'notes'),
      safely(_highlightService.loadHighlights(), 'highlights'),
      safely(AiService.i.refresh(), 'Apple Intelligence'),
    ]);
    _userData = await StorageService.loadUserData();

    if (_userData != null) {
      await _loadPlan();
      await _migrate();
      AiService.i.enabled = _userData!.aiEnabled;
    }

    _isLoading = false;
    notifyListeners();

    if (_userData != null) {
      WidgetSync.push(this);
      await _scheduleNotification();
      await checkAppBlocking();
    }
  }

  /// Back in the app: a new day may have begun.
  Future<void> onResume() async {
    if (_userData == null) return;
    notifyListeners();
    WidgetSync.push(this);
    await _scheduleNotification();
    await checkAppBlocking();
    await AiService.i.refresh();
  }

  Future<void> _loadPlan() async {
    _readings = await _bibleService.loadReadingPlan(_userData!.planId);
    _units = await _bibleService.loadUnits(_userData!.planId);
    final most = BibleService.maxDays(_units);
    if (_userData!.targetDays > most) _userData!.targetDays = most;
    _days = BibleService.spread(_units, _userData!.targetDays);
    _done = _userData!.completedUnits.toSet();
  }

  /// Version 1 kept which plan rows were read; now each chapter is kept.
  Future<void> _migrate() async {
    final u = _userData!;
    if (u.version >= UserData.currentVersion) return;
    final rows = u.completedReadings.toSet();
    u.completedUnits = [
      for (final unit in _units)
        if (rows.contains(unit.row)) unit.index,
    ];
    _done = u.completedUnits.toSet();
    u.version = UserData.currentVersion;
    await StorageService.saveUserData(u);
  }

  Future<void> _save() async {
    _userData!.completedUnits = _done.toList()..sort();
    await StorageService.saveUserData(_userData!);
    WidgetSync.push(this);
  }

  /// Plan lengths this plan can be spread over (a chapter a day at the least).
  List<int> durationsFor(List<PlanUnit> units) => [
    for (final d in planDurationOptions)
      if (d <= BibleService.maxDays(units)) d,
  ];

  Future<List<PlanUnit>> unitsFor(String planId) =>
      _bibleService.loadUnits(planId);

  Future<void> createUser({
    required String name,
    required String planId,
    required int targetDays,
    bool addDailyPsalm = false,
    bool addDailyProverb = false,
    int notificationHour = 8,
    int notificationMinute = 0,
    String themeMode = 'system',
  }) async {
    _userData = UserData.create(
      name: name,
      planId: planId,
      targetDays: targetDays,
      addDailyPsalm: addDailyPsalm,
      addDailyProverb: addDailyProverb,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
      themeMode: themeMode,
    );
    await _loadPlan();
    await _save();
    await _notificationService.requestPermissions();
    await _scheduleNotification();
    notifyListeners();
  }

  Future<void> startNewPlan({
    required String planId,
    required int targetDays,
  }) async {
    if (_userData == null) return;

    // Save completed plan to history if current plan was complete
    if (getProgress().isComplete) {
      await StorageService.addCompletedPlan(
        CompletedPlan(
          planId: _userData!.planId,
          planName: currentPlan.name,
          startDate: _userData!.startDate,
          completedDate: DateTime.now(),
          targetDays: _userData!.targetDays,
          actualDays: _daysBetween(_userData!.startDate, DateTime.now()) + 1,
        ),
      );
    }

    _userData!
      ..planId = planId
      ..targetDays = targetDays
      ..startDate = UserData.dateOnly(DateTime.now())
      ..completedReadings = []
      ..lastReadDate = null;
    _done = {};
    await _loadPlan();
    await _save();
    await _scheduleNotification();
    notifyListeners();
  }

  Future<List<CompletedPlan>> getPlanHistory() async {
    return StorageService.loadPlanHistory();
  }

  // --- Days ---

  static int _daysBetween(DateTime a, DateTime b) {
    // By calendar date, in UTC so a change of clocks doesn't lose an hour
    final x = DateTime.utc(a.year, a.month, a.day);
    final y = DateTime.utc(b.year, b.month, b.day);
    return y.difference(x).inDays;
  }

  /// The plan day the calendar is on: day 1 is the day the plan began.
  int getCurrentPlanDay() {
    if (_userData == null) return 1;
    final d = _daysBetween(_userData!.startDate, DateTime.now()) + 1;
    return d.clamp(1, _userData!.targetDays);
  }

  int getCalendarDay() => getCurrentPlanDay();

  /// The first day not yet read.
  int getNextUncompletedDay() {
    if (_userData == null || _days.isEmpty) return 1;
    for (var day = 1; day <= _days.length; day++) {
      if (!isDayComplete(day)) return day;
    }
    return _days.length;
  }

  DayReading getTodaysReading() => getReadingForDay(getNextUncompletedDay());

  bool hasReadAhead() => getDaysAhead() > 0;

  int getDaysAhead() {
    if (_userData == null) return 0;
    return (getNextUncompletedDay() - 1 - getCurrentPlanDay()).clamp(0, 9999);
  }

  /// Days the calendar has passed that aren't read yet.
  int getDaysBehind() {
    if (_userData == null) return 0;
    var n = 0;
    for (var d = 1; d < getCurrentPlanDay(); d++) {
      if (!isDayComplete(d)) n++;
    }
    return n;
  }

  bool isCaughtUpForToday() {
    if (_userData == null) return false;
    for (var d = 1; d <= getCurrentPlanDay(); d++) {
      if (!isDayComplete(d)) return false;
    }
    return true;
  }

  int getLastCompletedDay() {
    if (_userData == null) return 0;
    var last = 0;
    for (var day = 1; day <= _days.length; day++) {
      if (!isDayComplete(day)) break;
      last = day;
    }
    return last;
  }

  DayReading getReadingForDay(int planDay) {
    if (_userData == null || _days.isEmpty) {
      return DayReading(planDay: planDay, totalDays: 365, units: []);
    }
    final day = planDay.clamp(1, _days.length);
    final extras = <ChapterSpan>[];
    if (_userData!.addDailyPsalm) {
      extras.add(ChapterSpan(19, ((day - 1) % totalPsalms) + 1));
    }
    if (_userData!.addDailyProverb) {
      extras.add(ChapterSpan(20, ((day - 1) % totalProverbs) + 1));
    }
    return DayReading(
      planDay: day,
      totalDays: _days.length,
      units: _days[day - 1],
      extras: extras,
    );
  }

  bool isDayComplete(int planDay) {
    if (_userData == null || planDay < 1 || planDay > _days.length) {
      return false;
    }
    final units = _days[planDay - 1];
    return units.isNotEmpty && units.every((u) => _done.contains(u.index));
  }

  /// Whether a plan row is read (for the plan's own calendar).
  bool isUnitDone(int unitIndex) => _done.contains(unitIndex);

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool get readToday =>
      _userData?.readDates.contains(_formatDate(DateTime.now())) ?? false;

  /// Today's part is done: read today, or read ahead past today.
  bool isTodayComplete() {
    if (_userData == null) return false;
    return readToday || isCaughtUpForToday();
  }

  bool didMissYesterday() => getDaysMissed() > 0;

  int getDaysMissed() {
    final lastRead = _userData?.lastReadDate;
    if (lastRead == null) return 0;
    final difference = _daysBetween(lastRead, DateTime.now());
    return difference > 1 ? difference - 1 : 0;
  }

  /// Days in a row with a reading, up to today (or yesterday, if today's
  /// isn't read yet).
  int get streak {
    final dates = _userData?.readDates.toSet() ?? {};
    if (dates.isEmpty) return 0;
    var day = DateTime.now();
    if (!dates.contains(_formatDate(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (dates.contains(_formatDate(day))) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  Future<void> markReadingComplete(DayReading reading) async {
    if (_userData == null) return;
    _done.addAll(reading.unitIndices);
    final now = DateTime.now();
    _userData!.lastReadDate = now;
    final todayStr = _formatDate(now);
    if (!_userData!.readDates.contains(todayStr)) {
      _userData!.readDates.add(todayStr);
    }
    await _save();
    notifyListeners();
    await _scheduleNotification();
  }

  /// Unmark a day (a mistaken tick).
  Future<void> markDayIncomplete(int planDay) async {
    if (_userData == null || planDay < 1 || planDay > _days.length) return;
    _done.removeAll(_days[planDay - 1].map((u) => u.index));
    await _save();
    notifyListeners();
  }

  Progress getProgress() {
    if (_userData == null || _days.isEmpty) {
      return (completed: 0, total: 365, percentage: 0.0, isComplete: false);
    }
    var daysCompleted = 0;
    for (var day = 1; day <= _days.length; day++) {
      if (isDayComplete(day)) daysCompleted++;
    }
    final total = _days.length;
    return (
      completed: daysCompleted,
      total: total,
      percentage: daysCompleted / total * 100,
      isComplete: daysCompleted >= total,
    );
  }

  /// Chapters read of the plan, as a share (finer than days).
  double get chapterShare => _units.isEmpty
      ? 0
      : _done.where((i) => i < _units.length).length / _units.length;

  bool isPlanComplete() => getProgress().isComplete;

  Future<void> changePlan(String planId, {int? targetDays}) async {
    if (_userData == null) return;
    _userData!
      ..planId = planId
      ..targetDays = targetDays ?? _userData!.targetDays
      ..startDate = UserData.dateOnly(DateTime.now());
    _done = {};
    await _loadPlan();
    await _save();
    await _scheduleNotification();
    notifyListeners();
  }

  Future<void> updateTargetDays(int targetDays) async {
    if (_userData == null) return;
    _userData!.targetDays = targetDays;
    await _loadPlan();
    await _save();
    notifyListeners();
  }

  Future<void> toggleDailyPsalm(bool enabled) async {
    if (_userData == null) return;
    _userData!.addDailyPsalm = enabled;
    await _save();
    notifyListeners();
  }

  Future<void> toggleDailyProverb(bool enabled) async {
    if (_userData == null) return;
    _userData!.addDailyProverb = enabled;
    await _save();
    notifyListeners();
  }

  Future<void> setName(String name) async {
    if (_userData == null) return;
    _userData!.name = name.trim();
    await _save();
    await _scheduleNotification();
    notifyListeners();
  }

  // --- Look ---

  Future<void> setThemeMode(String mode) async {
    if (_userData == null) return;
    _userData!.themeMode = mode;
    await _save();
    notifyListeners();
  }

  ThemeMode get themeMode => switch (_userData?.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  double get fontScale => _userData?.fontScale ?? 1.0;

  Future<void> setFontScale(double scale) async {
    if (_userData == null) return;
    _userData!.fontScale = scale.clamp(0.8, 1.6);
    await _save();
    notifyListeners();
  }

  String get readingFont => _userData?.readingFont ?? 'garamond';

  Future<void> setReadingFont(String font) async {
    if (_userData == null) return;
    _userData!.readingFont = font;
    await _save();
    notifyListeners();
  }

  String get verseLayout => _userData?.verseLayout ?? 'lines';

  Future<void> setVerseLayout(String layout) async {
    if (_userData == null) return;
    _userData!.verseLayout = layout;
    await _save();
    notifyListeners();
  }

  bool get aiEnabled => _userData?.aiEnabled ?? true;

  Future<void> setAiEnabled(bool on) async {
    if (_userData == null) return;
    _userData!.aiEnabled = on;
    AiService.i.enabled = on;
    await _save();
    notifyListeners();
  }

  // --- Plan resets ---

  Future<void> startFresh() async {
    if (_userData == null) return;
    _userData!
      ..startDate = UserData.dateOnly(DateTime.now())
      ..lastReadDate = null;
    _done = {};
    await _save();
    await _scheduleNotification();
    notifyListeners();
  }

  Future<void> resetProgress() => startFresh();

  /// Behind: move the plan's days so the next unread day is today. What's
  /// read stays read.
  Future<void> pickUpFromToday() async {
    if (_userData == null) return;
    final next = getNextUncompletedDay();
    final t = DateTime.now();
    _userData!.startDate = DateTime(t.year, t.month, t.day - (next - 1));
    await _save();
    await _scheduleNotification();
    await checkAppBlocking();
    notifyListeners();
  }

  // --- Reminders ---

  Future<void> setNotificationTime(int hour, int minute) async {
    if (_userData == null) return;
    _userData!.notificationHour = hour;
    _userData!.notificationMinute = minute;
    await _save();
    await _scheduleNotification();
    notifyListeners();
  }

  Future<void> toggleNotifications(bool enabled) async {
    if (_userData == null) return;
    _userData!.notificationsEnabled = enabled;
    await _save();
    if (enabled) await _notificationService.requestPermissions();
    await _scheduleNotification();
    notifyListeners();
  }

  Future<void> _scheduleNotification() async {
    final u = _userData;
    if (u == null) return;
    if (!u.notificationsEnabled || getProgress().isComplete) {
      await _notificationService.cancelAllNotifications();
      return;
    }
    final progress = getProgress();
    await _notificationService.scheduleReminders(
      hour: u.notificationHour,
      minute: u.notificationMinute,
      readToday: isTodayComplete(),
      text: (_) => (
        title: NotificationMessages.getTitle(
          percentComplete: progress.percentage,
        ),
        body: NotificationMessages.getMessage(
          name: u.name,
          daysComplete: progress.completed,
          totalDays: progress.total,
          percentComplete: progress.percentage,
        ),
      ),
      evening: (
        title: 'Still time to read today',
        body:
            '${u.name.isEmpty ? 'Friend' : u.name}, today\'s reading is waiting. Even a few verses before bed.',
      ),
    );
  }

  // --- Usage tracking ---

  Future<void> trackExtraChapterRead() async {
    if (_userData == null) return;
    _userData!.extraChaptersRead++;
    await _save();
  }

  Future<void> trackSearchPerformed() async {
    if (_userData == null) return;
    _userData!.searchesPerformed++;
    await _save();
  }

  bool didReadOnDate(DateTime date) =>
      _userData?.readDates.contains(_formatDate(date)) ?? false;

  /// The calendar date of a plan day.
  DateTime getDateForPlanDay(int planDay) {
    final s = _userData!.startDate;
    return DateTime(s.year, s.month, s.day + planDay - 1);
  }

  bool isPlanDayInPast(int planDay) => planDay < getCurrentPlanDay();

  /// Minimum reading time before a reading can be marked done while Focus
  /// Mode is on: the day's words at 200 a minute, at least 30 seconds.
  int minReadingSeconds(DayReading reading) =>
      ((reading.wordCount / 200) * 60).ceil().clamp(30, 1800);

  // --- App blocking ---

  Future<void> markReadingCompleteAndUnblock(DayReading reading) async {
    await markReadingComplete(reading);
    if (_userData?.appBlockingEnabled ?? false) {
      await _appBlockingService.markReadingComplete();
    }
  }

  Future<void> toggleAppBlocking(bool enabled) async {
    if (_userData == null) return;
    _userData!.appBlockingEnabled = enabled;
    await _save();
    if (enabled) {
      await _appBlockingService.enableBlocking();
      if (isTodayComplete()) await _appBlockingService.markReadingComplete();
    } else {
      await _appBlockingService.disableBlocking();
    }
    notifyListeners();
  }

  /// On opening the app: shields up if today isn't read, down if it is.
  Future<void> checkAppBlocking() async {
    if (_userData == null) return;
    if (_userData!.appBlockingEnabled) {
      // Idempotent: on, the daily schedule running, shields as the day needs.
      // (Also mends builds before 1.1, which could leave the native side off.)
      await _appBlockingService.enableBlocking();
      if (isTodayComplete()) await _appBlockingService.markReadingComplete();
    } else {
      // Safety: clear any stale shields that extensions may have re-applied
      await _appBlockingService.disableBlocking();
    }
  }

  // --- Quiz Tracking ---

  Future<void> recordQuizResult(int score, int maxScore) async {
    if (_userData == null) return;
    _userData!.quizzesTaken++;
    _userData!.totalQuizScore += score;
    final pct = maxScore > 0 ? ((score / maxScore) * 100).round() : 0;
    if (pct > _userData!.bestQuizScore) {
      _userData!.bestQuizScore = pct;
    }
    await _save();
    notifyListeners();
  }

  // --- Accountability Passcode ---

  String _hashPasscode(String passcode) {
    final bytes = utf8.encode(passcode);
    return sha256.convert(bytes).toString();
  }

  bool get hasAccountabilityPasscode =>
      _userData?.accountabilityPasscodeHash != null;

  Future<void> setAccountabilityPasscode(String passcode) async {
    if (_userData == null) return;
    _userData!.accountabilityPasscodeHash = _hashPasscode(passcode);
    await _save();
    notifyListeners();
  }

  Future<void> clearAccountabilityPasscode() async {
    if (_userData == null) return;
    _userData!.accountabilityPasscodeHash = null;
    await _save();
    notifyListeners();
  }

  bool verifyAccountabilityPasscode(String passcode) {
    if (_userData?.accountabilityPasscodeHash == null) return true;
    return _hashPasscode(passcode) == _userData!.accountabilityPasscodeHash;
  }
}
