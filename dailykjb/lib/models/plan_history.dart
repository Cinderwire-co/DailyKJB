import 'dart:convert';

class CompletedPlan {
  final String planId;
  final String planName;
  final DateTime startDate;
  final DateTime completedDate;
  final int targetDays;
  final int actualDays;

  CompletedPlan({
    required this.planId,
    required this.planName,
    required this.startDate,
    required this.completedDate,
    required this.targetDays,
    required this.actualDays,
  });

  factory CompletedPlan.fromJson(Map<String, dynamic> json) {
    return CompletedPlan(
      planId: json['planId'] ?? '',
      planName: json['planName'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      completedDate: DateTime.parse(json['completedDate']),
      targetDays: json['targetDays'] ?? 365,
      actualDays: json['actualDays'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'planName': planName,
      'startDate': startDate.toIso8601String().split('T')[0],
      'completedDate': completedDate.toIso8601String().split('T')[0],
      'targetDays': targetDays,
      'actualDays': actualDays,
    };
  }

  static List<CompletedPlan> fromJsonList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => CompletedPlan.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static String toJsonList(List<CompletedPlan> plans) {
    return jsonEncode(plans.map((p) => p.toJson()).toList());
  }
}
