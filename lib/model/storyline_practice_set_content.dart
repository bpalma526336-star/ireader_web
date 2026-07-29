class StorylinePracticeSetContent {
  final String questiontext;
  final List<String> options;
  final int correctOptionIndex;

  StorylinePracticeSetContent({
    required this.questiontext,
    required this.options,
    required this.correctOptionIndex,
  });

  factory StorylinePracticeSetContent.fromMap(Map<String, dynamic> map) {
    return StorylinePracticeSetContent(
      questiontext: map['questiontext'] ?? "",
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questiontext': questiontext,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
    };
  }

  StorylinePracticeSetContent copyWith({
    String? questiontext,
    List<String>? options,
    int? correctOptionIndex,
  }) {
    return StorylinePracticeSetContent(
      questiontext: questiontext ?? this.questiontext,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
    );
  }
}
