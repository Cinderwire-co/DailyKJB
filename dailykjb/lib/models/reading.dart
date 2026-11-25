import '../bible/kjb.dart';

/// A row of a reading plan: its date in the source and its passage
/// ("Gen 1-3", "Mat 2:19–3:17").
class Reading {
  final String date;
  final String passage;

  Reading({required this.date, required this.passage});

  factory Reading.fromCsv(List<dynamic> row) {
    return Reading(
      date: row[0].toString().replaceAll('"', ''),
      passage: row.length > 1 ? row[1].toString().replaceAll('"', '') : '',
    );
  }
}

/// One chapter (or part of one) of a plan: the smallest thing ticked off.
class PlanUnit {
  final int index; // its place in the whole plan
  final int row; // the plan row it came from
  final ChapterSpan span;

  const PlanUnit(this.index, this.row, this.span);
}

/// A day of the plan: the chapters to read, and any daily Psalm or Proverb
/// read alongside them (not counted toward the plan).
class DayReading {
  final int planDay;
  final int totalDays;
  final List<PlanUnit> units;
  final List<ChapterSpan> extras;

  DayReading({
    required this.planDay,
    required this.totalDays,
    required this.units,
    this.extras = const [],
  });

  List<ChapterSpan> get spans => [for (final u in units) u.span, ...extras];

  List<int> get unitIndices => [for (final u in units) u.index];

  /// "Genesis 1–3; Psalm 1"
  String get title => Kjb.describe(spans);

  /// "Gen. 1–3; Psa. 1"
  String get shortTitle => Kjb.describe(spans, short: true);

  int get wordCount {
    var n = 0;
    for (final s in spans) {
      for (final v in s.verses()) {
        n += v.$2.split(' ').length;
      }
    }
    return n;
  }

  /// Minutes at an unhurried reading pace.
  int get minutes => (wordCount / 200).ceil().clamp(1, 999);
}

class PassageData {
  final String reference;
  final ChapterSpan span;

  PassageData({required this.reference, required this.span});
}
