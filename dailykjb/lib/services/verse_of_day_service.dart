import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A verse for each day, chosen ahead for the coming week (so the home screen
/// widgets can turn over at midnight without the app), and not repeated within
/// 90 days.
class VerseOfDayService {
  static final VerseOfDayService _instance = VerseOfDayService._internal();
  factory VerseOfDayService() => _instance;
  VerseOfDayService._internal();

  static const String _planKey = 'verse_of_day_plan'; // {"2026-11-25": id}
  static const String _recentVersesKey = 'verse_of_day_recent_ids';
  // Before 1.1: the day's verse, kept by itself
  static const String _dateKey = 'verse_of_day_date';
  static const String _referenceKey = 'verse_of_day_reference';
  static const int _cooldownDays = 90;
  static const int _ahead = 7;

  List<Map<String, dynamic>>? _versesData;

  Future<void> _loadVersesData() async {
    if (_versesData != null) return;
    try {
      final data = jsonDecode(
        await rootBundle.loadString('assets/verse_of_the_day.json'),
      );
      _versesData = List<Map<String, dynamic>>.from(data['verses']);
    } catch (e) {
      _versesData = [];
    }
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The verses for today and the six days after: (date, reference, text).
  Future<List<({String date, String reference, String verse})>> week() async {
    await _loadVersesData();
    final pool = _versesData!;
    if (pool.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    Map<String, int> plan = {};
    try {
      plan = Map<String, int>.from(
        jsonDecode(prefs.getString(_planKey) ?? '{}') as Map,
      );
    } catch (_) {}
    List<int> recent = [];
    try {
      recent = List<int>.from(
        jsonDecode(prefs.getString(_recentVersesKey) ?? '[]') as List,
      );
    } catch (_) {}

    final now = DateTime.now();
    final today = _day(now);
    // A verse already shown today by an earlier version stays today's
    if (!plan.containsKey(today) && prefs.getString(_dateKey) == today) {
      final ref = prefs.getString(_referenceKey);
      final match = pool.where((v) => v['reference'] == ref).firstOrNull;
      if (match != null) plan[today] = match['id'] as int;
    }

    final random = Random();
    var changed = false;
    final days = [
      for (var i = 0; i < _ahead; i++)
        _day(DateTime(now.year, now.month, now.day + i)),
    ];
    for (final d in days) {
      if (plan.containsKey(d)) continue;
      final taken = {...recent, ...plan.values};
      final free = pool.where((v) => !taken.contains(v['id'] as int)).toList();
      final from = free.isNotEmpty ? free : pool;
      final id = from[random.nextInt(from.length)]['id'] as int;
      plan[d] = id;
      recent.insert(0, id);
      changed = true;
    }
    // Days gone by are forgotten; the cooldown remembers them
    plan.removeWhere((d, _) => d.compareTo(today) < 0);
    if (recent.length > _cooldownDays) {
      recent = recent.sublist(0, _cooldownDays);
    }
    if (changed) {
      await prefs.setString(_planKey, jsonEncode(plan));
      await prefs.setString(_recentVersesKey, jsonEncode(recent));
    }

    final byId = {for (final v in pool) v['id'] as int: v};
    return [
      for (final d in days)
        if (byId[plan[d]] != null)
          (
            date: d,
            reference: byId[plan[d]]!['reference'] as String,
            verse: byId[plan[d]]!['text'] as String,
          ),
    ];
  }

  Future<({String verse, String reference})> getVerseOfDay() async {
    final w = await week();
    if (w.isEmpty) {
      return (
        verse: 'Thy word is a lamp unto my feet, and a light unto my path.',
        reference: 'Psalm 119:105',
      );
    }
    return (verse: w.first.verse, reference: w.first.reference);
  }
}
