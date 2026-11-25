class ReadingPlan {
  final String id;
  final String name;
  final String description;
  final String filename;
  final int totalDays; // the plan's own pace

  const ReadingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.filename,
    required this.totalDays,
  });
}

const List<int> planDurationOptions = [90, 180, 365, 730];

const List<ReadingPlan> availablePlans = [
  ReadingPlan(
    id: 'whole_bible',
    name: 'Whole Bible',
    description: 'Genesis to Revelation, in order',
    filename: 'whole_bible.csv',
    totalDays: 365,
  ),
  ReadingPlan(
    id: 'chronological',
    name: 'Chronological',
    description: 'The whole Bible in the order events happened',
    filename: 'chronological.csv',
    totalDays: 365,
  ),
  ReadingPlan(
    id: 'old_testament',
    name: 'Old Testament',
    description: 'Genesis to Malachi',
    filename: 'old_testament.csv',
    totalDays: 365,
  ),
  ReadingPlan(
    id: 'new_testament',
    name: 'New Testament',
    description: 'Matthew to Revelation, a passage a day',
    filename: 'new_testamant.csv',
    totalDays: 365,
  ),
];

const int totalPsalms = 150;
const int totalProverbs = 31;

String durationLabel(int days) => switch (days) {
  90 => '3 months',
  180 => '6 months',
  365 => '1 year',
  730 => '2 years',
  _ => '$days days',
};
