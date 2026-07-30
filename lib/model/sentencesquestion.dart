class sentencequestions {
  final String questiontext;
  final List<String> options;
  final int correctOptionIndexes;

  sentencequestions({
    required this.questiontext,
    required this.options,
    required this.correctOptionIndexes,
  });

  factory sentencequestions.fromMap(Map<String, dynamic> map) {
    return sentencequestions(
      questiontext: map['questiontext'] ?? "",
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndexes: map['correctOptionIndexes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questiontext': questiontext,
      'options': options,
      'correctOptionIndexes': correctOptionIndexes,
    };
  }

  sentencequestions copyWith({
    String? questiontext,
    List<String>? options,
    int? correctOptionIndexes,
  }) {
    return sentencequestions(
      questiontext: questiontext ?? this.questiontext,
      options: options ?? this.options,
      correctOptionIndexes: correctOptionIndexes ?? this.correctOptionIndexes,
    );
  }
}
