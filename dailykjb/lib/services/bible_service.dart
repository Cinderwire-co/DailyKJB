import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../bible/kjb.dart';
import '../models/reading.dart';
import '../utils/constants.dart';

/// Reading plans: their rows, the chapters in them, and how they fall across
/// the days a reader chose.
class BibleService {
  static final BibleService _instance = BibleService._internal();
  factory BibleService() => _instance;
  BibleService._internal();

  final Map<String, List<Reading>> _planCache = {};
  final Map<String, List<PlanUnit>> _unitCache = {};

  Future<List<Reading>> loadReadingPlan(String planId) async {
    if (_planCache.containsKey(planId)) return _planCache[planId]!;

    final plan = availablePlans.firstWhere(
      (p) => p.id == planId,
      orElse: () => availablePlans.first,
    );

    final csvString = await rootBundle.loadString(
      'assets/plans/${plan.filename}',
    );
    final csvData = const CsvToListConverter().convert(
      csvString.replaceAll('\r\n', '\n'),
      eol: '\n',
    );

    final readings = csvData
        .skip(1)
        .where((row) => row.isNotEmpty)
        .map((row) => Reading.fromCsv(row))
        .toList();
    _planCache[planId] = readings;
    return readings;
  }

  /// Every chapter of a plan, in order, each with the row it came from.
  Future<List<PlanUnit>> loadUnits(String planId) async {
    if (_unitCache.containsKey(planId)) return _unitCache[planId]!;
    await Kjb.load();
    final readings = await loadReadingPlan(planId);
    final units = <PlanUnit>[];
    for (var r = 0; r < readings.length; r++) {
      for (final s in Kjb.spans(readings[r].passage)) {
        units.add(PlanUnit(units.length, r, s));
      }
    }
    return _unitCache[planId] = units;
  }

  /// The longest a plan can be spread: a chapter or part of one each day.
  static int maxDays(List<PlanUnit> units) => units.length;

  /// The units for each day of a plan spread over [days].
  ///
  /// At the plan's own pace or faster, days are made of whole rows, as the
  /// plan's authors grouped them. Slower, the chapters are shared out evenly,
  /// so no day is ever empty.
  static List<List<PlanUnit>> spread(List<PlanUnit> units, int days) {
    if (units.isEmpty || days < 1) return List.generate(days, (_) => []);
    final rows = units.last.row + 1;
    final out = <List<PlanUnit>>[];
    if (days <= rows) {
      final byRow = <int, List<PlanUnit>>{};
      for (final u in units) {
        byRow.putIfAbsent(u.row, () => []).add(u);
      }
      for (var d = 1; d <= days; d++) {
        final a = ((d - 1) * rows / days).floor();
        final b = (d * rows / days).floor();
        out.add([for (var r = a; r < b; r++) ...?byRow[r]]);
      }
    } else {
      final n = units.length;
      final per = days.clamp(1, n);
      for (var d = 1; d <= days; d++) {
        final dd = d.clamp(1, per);
        final a = ((dd - 1) * n / per).floor();
        final b = (dd * n / per).floor();
        out.add(d > per ? [] : units.sublist(a, b));
      }
    }
    return out;
  }
}
