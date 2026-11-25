import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerseOfDayService {
  static final VerseOfDayService _instance = VerseOfDayService._internal();
  factory VerseOfDayService() => _instance;
  VerseOfDayService._internal();

  static const String _dateKey = 'verse_of_day_date';
  static const String _verseKey = 'verse_of_day_verse';
  static const String _referenceKey = 'verse_of_day_reference';
  static const String _recentVersesKey = 'verse_of_day_recent_ids';
  static const int _cooldownDays = 90;

  String? _cachedVerse;
  String? _cachedReference;
  String? _cachedDate;
  List<Map<String, dynamic>>? _versesData;

  Future<void> _loadVersesData() async {
    if (_versesData != null) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/verse_of_the_day.json',
      );
      final data = jsonDecode(jsonString);
      _versesData = List<Map<String, dynamic>>.from(data['verses']);
    } catch (e) {
      _versesData = [];
    }
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<List<int>> _getRecentVerseIds() async {
    final prefs = await SharedPreferences.getInstance();
    final recentJson = prefs.getString(_recentVersesKey);
    if (recentJson == null) return [];

    try {
      return List<int>.from(jsonDecode(recentJson));
    } catch (e) {
      return [];
    }
  }

  Future<void> _addToRecentVerses(int verseId) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = await _getRecentVerseIds();

    // Add new verse to front
    recent.insert(0, verseId);

    // Keep only last 90 verses (cooldown period)
    if (recent.length > _cooldownDays) {
      recent.removeRange(_cooldownDays, recent.length);
    }

    await prefs.setString(_recentVersesKey, jsonEncode(recent));
  }

  Future<({String verse, String reference})> getVerseOfDay() async {
    await _loadVersesData();

    final today = _getTodayString();

    // Check cache first
    if (_cachedDate == today &&
        _cachedVerse != null &&
        _cachedReference != null) {
      return (verse: _cachedVerse!, reference: _cachedReference!);
    }

    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dateKey);

    if (storedDate == today) {
      // Use stored verse for today
      _cachedVerse = prefs.getString(_verseKey) ?? '';
      _cachedReference = prefs.getString(_referenceKey) ?? '';
      _cachedDate = today;
    } else {
      // Generate new verse for today - random but not repeating within 90 days
      final recentIds = await _getRecentVerseIds();
      final availableVerses = _versesData!
          .where((v) => !recentIds.contains(v['id'] as int))
          .toList();

      // If all verses have been used recently, use any verse
      final versePool = availableVerses.isNotEmpty
          ? availableVerses
          : _versesData!;
      if (versePool.isEmpty) {
        return (
          verse: 'Thy word is a lamp unto my feet, and a light unto my path.',
          reference: 'Psalm 119:105',
        );
      }

      // Random selection
      final random = Random();
      final selected = versePool[random.nextInt(versePool.length)];

      _cachedVerse = selected['text'] as String;
      _cachedReference = selected['reference'] as String;
      _cachedDate = today;

      // Track this verse as recently used
      await _addToRecentVerses(selected['id'] as int);

      // Store for today
      await prefs.setString(_dateKey, today);
      await prefs.setString(_verseKey, _cachedVerse!);
      await prefs.setString(_referenceKey, _cachedReference!);
    }

    return (verse: _cachedVerse!, reference: _cachedReference!);
  }
}
