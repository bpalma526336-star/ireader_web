class AssessmentContent {
  final String questiontext;
  final List<String> options;
  final int correctoptionindex;

  AssessmentContent({
    required this.questiontext,
    required this.options,
    required this.correctoptionindex,
  });

  factory AssessmentContent.fromMap(Map<String, dynamic> map) {
    return AssessmentContent(
      questiontext: map['questiontext'] ?? "",
      options: List<String>.from(map['options'] ?? []),
      correctoptionindex: map['correctoptionindex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questiontext': questiontext,
      'options': options,
      'correctoptionindex': correctoptionindex,
    };
  }

  AssessmentContent copywith({
    String? questiontext,
    String? complevel,
    List<String>? options,
    int? correctoptionindex,
  }) {
    return AssessmentContent(
      questiontext: questiontext ?? this.questiontext,
      options: options ?? this.options,
      correctoptionindex: correctoptionindex ?? this.correctoptionindex,
    );
  }
}
