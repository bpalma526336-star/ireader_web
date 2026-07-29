class Wordrecognitionquestions {
  final String? image;
  final String questiontext;
  final List<String> options;
  final int correctOptionIndexes;

  Wordrecognitionquestions({
    this.image,
    required this.questiontext,
    required this.options,
    required this.correctOptionIndexes,
  });

  factory Wordrecognitionquestions.fromMap(Map<String, dynamic> map) {
    return Wordrecognitionquestions(
      image: map['image'] as String?,
      questiontext: map['questiontext'] ?? "",
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndexes: map['correctOptionIndexes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'questiontext': questiontext,
      'options': options,
      'correctOptionIndexes': correctOptionIndexes,
    };
    if (image != null) {
      map['image'] = image;
    }
    return map;
  }

  Wordrecognitionquestions copyWith({
    String? image,
    String? questiontext,
    List<String>? options,
    int? correctOptionIndexes,
  }) {
    return Wordrecognitionquestions(
      image: image ?? this.image,
      questiontext: questiontext ?? this.questiontext,
      options: options ?? this.options,
      correctOptionIndexes: correctOptionIndexes ?? this.correctOptionIndexes,
    );
  }
}
