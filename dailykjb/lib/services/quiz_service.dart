import 'dart:math';

import '../bible/kjb.dart';

class QuizQuestion {
  final String reference; // e.g. "Genesis 1:3"
  final String fullVerseText;
  final List<String> displayWords; // Words with some replaced by blanks
  final List<int> blankIndices; // Which indices in displayWords are blanks
  final List<String> correctAnswers; // The removed words (in order)
  final List<String> options; // correctAnswers + distractors, shuffled

  QuizQuestion({
    required this.reference,
    required this.fullVerseText,
    required this.displayWords,
    required this.blankIndices,
    required this.correctAnswers,
    required this.options,
  });
}

class QuizResult {
  final int totalQuestions;
  final int score;
  final int maxScore;
  final String grade;
  final bool passed;

  QuizResult({
    required this.totalQuestions,
    required this.score,
    required this.maxScore,
    required this.grade,
    required this.passed,
  });

  double get percentage => maxScore > 0 ? score / maxScore : 0;
}

class QuizService {
  static const int questionsPerQuiz = 10;
  static const int pointsPerCorrect = 5;
  static const int penaltyPerWrong = 1;
  static const int blanksPerVerse = 3;
  static const double passingPercentage = 0.5;

  final Random _random = Random();

  /// Generate quiz questions from the day's reading passages.
  /// Picks 10 random verses from all passages and creates fill-in-the-blank questions.
  List<QuizQuestion> generateQuiz(List<ChapterSpan> spans) {
    // Collect all verses with their references
    final allVerses = <({String reference, String text})>[];
    for (final s in spans) {
      final name = Kjb.bookOf(s.book)?.singular ?? '';
      for (final (n, text) in s.verses()) {
        allVerses.add((reference: '$name ${s.chapter}:$n', text: text));
      }
    }

    if (allVerses.isEmpty) return [];

    // Shuffle and pick up to 10 verses
    allVerses.shuffle(_random);
    final selected = allVerses.take(questionsPerQuiz).toList();

    // Collect all words from all selected verses for distractor pool
    final allWords = <String>{};
    for (final v in allVerses) {
      allWords.addAll(_getSignificantWords(v.text));
    }

    return selected
        .map((v) => _createQuestion(v.reference, v.text, allWords))
        .toList();
  }

  QuizQuestion _createQuestion(
    String reference,
    String verseText,
    Set<String> wordPool,
  ) {
    final words = verseText.split(RegExp(r'\s+'));
    if (words.length < 4) {
      // Very short verse — blank out 1 word
      return _createQuestionWithBlanks(
        reference,
        verseText,
        words,
        1,
        wordPool,
      );
    }
    final numBlanks = words.length < 6 ? 2 : blanksPerVerse;
    return _createQuestionWithBlanks(
      reference,
      verseText,
      words,
      numBlanks,
      wordPool,
    );
  }

  QuizQuestion _createQuestionWithBlanks(
    String reference,
    String fullText,
    List<String> words,
    int numBlanks,
    Set<String> wordPool,
  ) {
    // Pick indices to blank out — prefer significant words (not tiny ones like "a", "the")
    final candidateIndices = <int>[];
    for (var i = 0; i < words.length; i++) {
      final clean = _cleanWord(words[i]);
      if (clean.length >= 3) {
        candidateIndices.add(i);
      }
    }

    // Fallback: if not enough significant words, use all indices
    if (candidateIndices.length < numBlanks) {
      candidateIndices.clear();
      for (var i = 0; i < words.length; i++) {
        candidateIndices.add(i);
      }
    }

    candidateIndices.shuffle(_random);
    final blankIndices = candidateIndices.take(numBlanks).toList()..sort();

    final correctAnswers = <String>[];
    final displayWords = List<String>.from(words);
    // The answer is the bare word; its punctuation stays in the verse, so the
    // answers can't be told from the other choices by a comma
    for (final idx in blankIndices) {
      final clean = _cleanWord(words[idx]);
      correctAnswers.add(clean.isEmpty ? words[idx] : clean);
      final at = words[idx].indexOf(clean);
      displayWords[idx] = clean.isEmpty || at < 0
          ? '___'
          : '${words[idx].substring(0, at)}___${words[idx].substring(at + clean.length)}';
    }

    // Generate distractors from word pool
    final cleanCorrect = correctAnswers
        .map(_cleanWord)
        .map((w) => w.toLowerCase())
        .toSet();
    final distractors = wordPool
        .where((w) => !cleanCorrect.contains(w.toLowerCase()) && w.length >= 3)
        .toSet()
        .toList();
    distractors.shuffle(_random);

    // Take enough distractors to have roughly 2x the options
    final numDistractors = (numBlanks * 1.5).ceil().clamp(2, 5);
    final selectedDistractors = distractors.take(numDistractors).toList();

    final options = [...correctAnswers, ...selectedDistractors];
    options.shuffle(_random);

    return QuizQuestion(
      reference: reference,
      fullVerseText: fullText,
      displayWords: displayWords,
      blankIndices: blankIndices,
      correctAnswers: correctAnswers,
      options: options,
    );
  }

  /// Extract significant words (3+ chars, stripped of punctuation)
  Set<String> _getSignificantWords(String text) {
    return text
        .split(RegExp(r'\s+'))
        .map(_cleanWord)
        .where((w) => w.length >= 3)
        .toSet();
  }

  /// Remove leading/trailing punctuation from a word
  String _cleanWord(String word) {
    return word.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '');
  }

  /// Calculate the final quiz result
  QuizResult calculateResult(List<int> scoresPerQuestion) {
    final totalQuestions = scoresPerQuestion.length;
    final maxScore = totalQuestions * pointsPerCorrect;
    final score = scoresPerQuestion.fold<int>(0, (a, b) => a + b);

    final percentage = maxScore > 0 ? score / maxScore : 0.0;
    String grade;
    if (percentage >= 0.9) {
      grade = 'A';
    } else if (percentage >= 0.8) {
      grade = 'B';
    } else if (percentage >= 0.7) {
      grade = 'C';
    } else if (percentage >= 0.6) {
      grade = 'D';
    } else {
      grade = 'F';
    }

    return QuizResult(
      totalQuestions: totalQuestions,
      score: score,
      maxScore: maxScore,
      grade: grade,
      passed: percentage >= passingPercentage,
    );
  }
}
