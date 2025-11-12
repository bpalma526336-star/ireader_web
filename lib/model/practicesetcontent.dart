class PracticeSetContent {
  final String questiontext;
  final List<String> options;
  final int correctOptionIndex;

  PracticeSetContent({
    required this.questiontext,
    required this.options,
    required this.correctOptionIndex,
  });

  factory PracticeSetContent.fromMap(Map<String, dynamic> map) {
    return PracticeSetContent(
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

  PracticeSetContent copyWith({
    String? questiontext,
    List<String>? options,
    int? correctOptionIndex,
  }) {
    return PracticeSetContent(
      questiontext: questiontext ?? this.questiontext,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
    );
  }
}
