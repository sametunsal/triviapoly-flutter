/// Question difficulty levels
enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

/// Question model - represents a trivia question
class Question {
  final String questionText;
  final List<String> options; // A, B, C, D options
  final int correctIndex; // Index of correct answer (0-3)
  final QuestionDifficulty difficulty;
  final bool isBonus; // Whether this is a bonus question

  Question({
    required this.questionText,
    required this.options,
    required this.correctIndex,
    this.difficulty = QuestionDifficulty.medium,
    this.isBonus = false,
  });

  /// Validate that the question has exactly 4 options
  bool get isValid => options.length == 4 && correctIndex >= 0 && correctIndex < 4;
}

