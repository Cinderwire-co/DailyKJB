import 'dart:convert';

class UserData {
  /// 2: progress is kept by chapter units ([completedUnits]), not plan rows.
  static const currentVersion = 2;

  String name;
  String planId;
  int targetDays; // How many days to complete the plan
  DateTime startDate;
  List<int> completedReadings; // Plan rows read (version 1; kept for migration)
  List<int> completedUnits; // Plan chapter units read (version 2)
  int version;
  DateTime? lastReadDate;
  bool notificationsEnabled;
  int notificationHour;
  int notificationMinute;
  bool addDailyPsalm;
  bool addDailyProverb;
  String themeMode; // 'system', 'light', 'dark'
  double fontScale; // Reading font scale (0.8 - 1.6)
  String readingFont; // 'garamond', 'georgia', 'sans'
  String verseLayout; // 'lines' (a verse to a line) or 'paragraph'
  bool aiEnabled; // Use Apple Intelligence on this device when it's there
  List<String> readDates; // Dates (yyyy-MM-dd) the user completed a reading
  int extraChaptersRead; // Chapters read in the Bible reader tab
  int searchesPerformed; // Searches performed in the Bible reader tab
  bool appBlockingEnabled; // Whether app blocking is enabled
  String? accountabilityPasscodeHash; // Hashed 4-digit accountability passcode
  int quizzesTaken; // Total number of quizzes completed
  int totalQuizScore; // Cumulative quiz score across all quizzes
  int bestQuizScore; // Best single quiz score percentage (0-100)

  UserData({
    required this.name,
    required this.planId,
    required this.targetDays,
    required this.startDate,
    required this.completedReadings,
    List<int>? completedUnits,
    this.version = currentVersion,
    this.lastReadDate,
    this.notificationsEnabled = true,
    this.notificationHour = 8,
    this.notificationMinute = 0,
    this.addDailyPsalm = false,
    this.addDailyProverb = false,
    this.themeMode = 'system',
    this.fontScale = 1.0,
    this.readingFont = 'garamond',
    this.verseLayout = 'lines',
    this.aiEnabled = true,
    List<String>? readDates,
    this.extraChaptersRead = 0,
    this.searchesPerformed = 0,
    this.appBlockingEnabled = false,
    this.accountabilityPasscodeHash,
    this.quizzesTaken = 0,
    this.totalQuizScore = 0,
    this.bestQuizScore = 0,
  }) : readDates = readDates ?? [],
       completedUnits = completedUnits ?? [];

  factory UserData.create({
    required String name,
    required String planId,
    required int targetDays,
    bool addDailyPsalm = false,
    bool addDailyProverb = false,
    int notificationHour = 8,
    int notificationMinute = 0,
    String themeMode = 'system',
  }) {
    return UserData(
      name: name,
      planId: planId,
      targetDays: targetDays,
      startDate: dateOnly(DateTime.now()),
      completedReadings: [],
      completedUnits: [],
      notificationsEnabled: true,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
      addDailyPsalm: addDailyPsalm,
      addDailyProverb: addDailyProverb,
      themeMode: themeMode,
    );
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  factory UserData.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    var theme = json['themeMode'] as String? ?? 'system';
    // Version 1 was always dark, never chosen: let the phone decide now
    if (version < 2 && theme == 'dark') theme = 'system';
    return UserData(
      name: json['name'] ?? '',
      planId: json['planId'] ?? 'whole_bible',
      targetDays: (json['targetDays'] as num?)?.toInt() ?? 365,
      startDate: dateOnly(DateTime.parse(json['startDate'])),
      completedReadings: List<int>.from(json['completedReadings'] ?? []),
      completedUnits: List<int>.from(json['completedUnits'] ?? []),
      version: version,
      lastReadDate: json['lastReadDate'] != null
          ? DateTime.parse(json['lastReadDate'])
          : null,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      notificationHour: json['notificationHour'] ?? 8,
      notificationMinute: json['notificationMinute'] ?? 0,
      addDailyPsalm: json['addDailyPsalm'] ?? false,
      addDailyProverb: json['addDailyProverb'] ?? false,
      themeMode: theme,
      fontScale: (json['fontScale'] ?? 1.0).toDouble(),
      readingFont: json['readingFont'] ?? 'garamond',
      verseLayout: json['verseLayout'] ?? 'lines',
      aiEnabled: json['aiEnabled'] ?? true,
      readDates: List<String>.from(json['readDates'] ?? []),
      extraChaptersRead: json['extraChaptersRead'] ?? 0,
      searchesPerformed: json['searchesPerformed'] ?? 0,
      appBlockingEnabled: json['appBlockingEnabled'] ?? false,
      accountabilityPasscodeHash: json['accountabilityPasscodeHash'],
      quizzesTaken: json['quizzesTaken'] ?? 0,
      totalQuizScore: json['totalQuizScore'] ?? 0,
      bestQuizScore: json['bestQuizScore'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'planId': planId,
      'targetDays': targetDays,
      'startDate': _day(startDate),
      'completedReadings': completedReadings,
      'completedUnits': completedUnits,
      'version': version,
      'lastReadDate': lastReadDate == null ? null : _day(lastReadDate!),
      'notificationsEnabled': notificationsEnabled,
      'notificationHour': notificationHour,
      'notificationMinute': notificationMinute,
      'addDailyPsalm': addDailyPsalm,
      'addDailyProverb': addDailyProverb,
      'themeMode': themeMode,
      'fontScale': fontScale,
      'readingFont': readingFont,
      'verseLayout': verseLayout,
      'aiEnabled': aiEnabled,
      'readDates': readDates,
      'extraChaptersRead': extraChaptersRead,
      'searchesPerformed': searchesPerformed,
      'appBlockingEnabled': appBlockingEnabled,
      'accountabilityPasscodeHash': accountabilityPasscodeHash,
      'quizzesTaken': quizzesTaken,
      'totalQuizScore': totalQuizScore,
      'bestQuizScore': bestQuizScore,
    };
  }

  // The local date, not UTC: a reading late in the evening belongs to that day
  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String toJsonString() => jsonEncode(toJson());

  static UserData? fromJsonString(String jsonString) {
    try {
      return UserData.fromJson(jsonDecode(jsonString));
    } catch (e) {
      return null;
    }
  }
}
