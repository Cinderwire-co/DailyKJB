import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_data.dart';
import '../models/plan_history.dart';

class StorageService {
  static const String _userDataKey = 'user_data';
  static const String _planHistoryKey = 'plan_history';

  static Future<UserData?> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userDataKey);
    if (jsonString == null) return null;
    return UserData.fromJsonString(jsonString);
  }

  static Future<void> saveUserData(UserData userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, userData.toJsonString());
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
  }

  static Future<List<CompletedPlan>> loadPlanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_planHistoryKey);
    return CompletedPlan.fromJsonList(jsonString);
  }

  static Future<void> savePlanHistory(List<CompletedPlan> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planHistoryKey, CompletedPlan.toJsonList(history));
  }

  static Future<void> addCompletedPlan(CompletedPlan plan) async {
    final history = await loadPlanHistory();
    history.add(plan);
    await savePlanHistory(history);
  }
}
