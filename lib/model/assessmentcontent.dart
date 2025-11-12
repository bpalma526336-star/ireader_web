class AssessmentContent {
  final String questiontext;
  final String complevel;
  final List<String> options;
  final int correctoptionindex;

  AssessmentContent({
    required this.questiontext,
    required this.complevel,
    required this.options,
    required this.correctoptionindex,
  });

  factory AssessmentContent.fromMap(Map<String, dynamic> map) {
    return AssessmentContent(
      questiontext: map['questiontext'] ?? "",
      complevel: map['complevel'] ?? "",
      options: List<String>.from(map['options'] ?? []),
      correctoptionindex: map['correctOptionindex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questiontext': questiontext,
      'complevel': complevel,
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
      complevel: complevel ?? this.complevel,
      options: options ?? this.options,
      correctoptionindex: correctoptionindex ?? this.correctoptionindex,
    );
  }
}
