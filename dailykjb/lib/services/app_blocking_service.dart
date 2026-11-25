import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Service to manage app blocking via native platform APIs.
/// iOS: Screen Time API (FamilyControls + ManagedSettings)
/// Android: UsageStatsManager + Overlay + ForegroundService
class AppBlockingService {
  static const _channel = MethodChannel('com.dailykjb/app_blocking');

  /// Check if the current platform supports app blocking
  Future<bool> isSupported() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request authorization from the user
  /// iOS: Screen Time permission
  /// Android: Usage Stats + Draw Over Other Apps permissions
  Future<bool> requestAuthorization() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestAuthorization');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Authorization failed: ${e.message}');
      return false;
    }
  }

  /// Check if required permissions are granted
  Future<bool> isAuthorized() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAuthorized');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Show the native app picker to select apps to block
  /// iOS: Returns the count of selected apps/categories
  /// Android: Returns a list of app info maps for Flutter to display a picker
  Future<dynamic> showAppPicker() async {
    try {
      final result = await _channel.invokeMethod('showAppPicker');
      if (Platform.isIOS) {
        return result as int? ?? 0;
      } else {
        // Android returns List<Map> of installed apps
        if (result is List) {
          return result.map((e) => Map<String, String>.from(e as Map)).toList();
        }
        return <Map<String, String>>[];
      }
    } on PlatformException catch (e) {
      debugPrint('App picker failed: ${e.message}');
      if (Platform.isIOS) return 0;
      return <Map<String, String>>[];
    }
  }

  /// Android only: save the selected packages to block
  Future<int> setBlockedPackages(List<String> packages) async {
    try {
      final result = await _channel.invokeMethod<int>('setBlockedPackages', {
        'packages': packages,
      });
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Android only: get currently blocked packages
  Future<List<String>> getBlockedPackages() async {
    try {
      final result = await _channel.invokeMethod<List>('getBlockedPackages');
      return result?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Enable blocking on selected apps
  Future<bool> enableBlocking() async {
    try {
      final result = await _channel.invokeMethod<bool>('enableBlocking');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Disable blocking (remove shields/overlay)
  Future<bool> disableBlocking() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableBlocking');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mark today's reading as complete and remove shields/overlay
  Future<bool> markReadingComplete() async {
    try {
      final result = await _channel.invokeMethod<bool>('markReadingComplete');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check if today's reading is already complete
  Future<bool> isReadingCompleteToday() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isReadingCompleteToday',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check and re-enable shields/overlay if needed (new day)
  Future<void> checkAndReenableShields() async {
    try {
      await _channel.invokeMethod('checkAndReenableShields');
    } catch (_) {}
  }

  /// Check if user has selected any apps to block
  Future<bool> hasSelectedApps() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSelectedApps');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get the count of selected apps/categories
  Future<int> selectedAppCount() async {
    try {
      final result = await _channel.invokeMethod<int>('selectedAppCount');
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
