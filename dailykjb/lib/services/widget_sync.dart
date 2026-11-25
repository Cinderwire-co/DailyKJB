import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../providers/app_provider.dart';
import 'verse_of_day_service.dart';

/// Keeps the home screen widgets (ios/DailyKJBWidgets) up to date: what they
/// need, left where they can read it, whenever the plan changes. A week of
/// verses goes with it, so they turn over at midnight on their own.
class WidgetSync {
  WidgetSync._();

  static const _channel = MethodChannel('com.dailykjb/home');
  static Timer? _wait;

  /// After a moment, so a run of changes sends once.
  static void push(AppProvider prov) {
    if (!Platform.isIOS) return;
    _wait?.cancel();
    _wait = Timer(const Duration(milliseconds: 600), () => _send(prov));
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> _send(AppProvider prov) async {
    final u = prov.userData;
    try {
      if (u == null) {
        await _channel.invokeMethod('update', '');
        return;
      }
      final progress = prov.getProgress();
      final next = progress.isComplete ? null : prov.getTodaysReading();
      final verses = await VerseOfDayService().week();
      final dates = u.readDates.toList()..sort();
      final snapshot = {
        'name': u.name,
        'plan': prov.currentPlan.name,
        'start': _day(u.startDate),
        'total': progress.total,
        'completed': progress.completed,
        'streak': prov.streak,
        'lastRead': dates.isEmpty ? null : dates.last,
        'complete': progress.isComplete,
        'next': next == null
            ? null
            : {
                'day': next.planDay,
                'title': next.title,
                'short': next.shortTitle,
                'minutes': next.minutes,
              },
        'verses': [
          for (final v in verses)
            {'date': v.date, 'ref': v.reference, 'text': v.verse},
        ],
      };
      await _channel.invokeMethod('update', jsonEncode(snapshot));
    } catch (e) {
      debugPrint('Widgets not updated: $e');
    }
  }
}

/// Links the app is opened with from a widget: dailykjb://read,
/// dailykjb://today, dailykjb://verse?ref=John%203:16. A Focus Mode shield's
/// "Read now" arrives the same way, as dailykjb://read.
class Links {
  Links._();

  static const _channel = MethodChannel('com.dailykjb/home');
  static final latest = ValueNotifier<Uri?>(null);
  static bool _started = false;

  static Future<void> start() async {
    if (_started || !Platform.isIOS) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        latest.value = Uri.tryParse(call.arguments as String);
      }
    });
    try {
      final first = await _channel.invokeMethod<String>('initialLink');
      if (first != null) latest.value = Uri.tryParse(first);
    } catch (_) {}
    await fromShield();
  }

  /// Sent here by the shield's "Read now": straight to today's reading.
  static Future<void> fromShield() async {
    if (!Platform.isIOS) return;
    try {
      if (await _channel.invokeMethod<bool>('shieldReadNow') == true) {
        latest.value = Uri.parse('dailykjb://read');
      }
    } catch (_) {}
  }
}
