import 'package:flutter/material.dart';
import 'models/question_model.dart';

/// Tile Effect Panel - displays bonus, penalty, bankruptcy, and special tile effects
class TileEffectPanel extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onClose;

  const TileEffectPanel({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SizedBox.expand(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 400,
                height: 250, // Increased height for better readability
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TITLE - Clear hierarchy
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      // MESSAGE - Scrollable, wraps gracefully
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.start,
                            softWrap: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ACTION BUTTON - Clear call to action
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: onClose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Question Panel - displays questions when landing on question tiles
class QuestionPanel extends StatelessWidget {
  final Question question;
  final String? feedback;
  final Function(int) onAnswer;
  final VoidCallback onClose;

  const QuestionPanel({
    super.key,
    required this.question,
    this.feedback,
    required this.onAnswer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SizedBox.expand(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 450,
                height: 400,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TITLE
                      Row(
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Soru Karesi',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // QUESTION TEXT
                      Text(
                        question.questionText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // OPTIONS (A, B, C, D)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: question.options
                                .asMap()
                                .entries
                                .map((entry) {
                              final index = entry.key;
                              final option = entry.value;
                              final optionLabel =
                                  String.fromCharCode(65 + index); // A, B, C, D

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: feedback == null
                                      ? () => onAnswer(index)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: feedback != null
                                        ? (index == question.correctIndex
                                            ? Colors.green.shade100
                                            : Colors.white)
                                        : Colors.blue.shade50,
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: feedback != null &&
                                                index == question.correctIndex
                                            ? Colors.green.shade400
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    elevation: feedback == null ? 2 : 0,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            optionLabel,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.start,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // FEEDBACK MESSAGE
                      if (feedback != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: feedback!.contains('Doğru')
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: feedback!.contains('Doğru')
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Text(
                            feedback!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: feedback!.contains('Doğru')
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // CLOSE BUTTON (only shown after answering)
                      if (feedback != null)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: onClose,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Devam',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

