import 'package:ireader_web/model/practicesetcontent.dart';

class PracticeSet {
  final String id;
  final String title;
  final String category;
  final int timeLimit;
  final String visibility;
  final String readingpassage;
  final List<PracticeSetContent> questions;

  PracticeSet({
    required this.id,
    required this.title,
    required this.category,
    required this.visibility,
    required this.readingpassage,
    required this.timeLimit,
    required this.questions,
  });

  factory PracticeSet.fromMap(String id, Map<String, dynamic> map) {
    return PracticeSet(
      id: id,
      title: map['practicesettitle'] ?? "",
      category: map['category'] ?? "",
      visibility: map['visibility'] ?? "",
      readingpassage: map['readingpassage'] ?? "",
      timeLimit: map['timeLimit'] ?? 0,
      questions: ((map['questions'] ?? []) as List)
          .map((e) => PracticeSetContent.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'practicesettitle': title,
      'category': category,
      'visibility': visibility,
      'readingpassage': readingpassage,
      'timeLimit': timeLimit,
      'questions': questions.map((e) => e.toMap()).toList(),
    };
  }

  PracticeSet copyWith({
    String? title,
    String? category,
    String? visibility,
    String? readingpassage,
    int? timeLimit,
    List<PracticeSetContent>? questions,
  }) {
    return PracticeSet(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      readingpassage: readingpassage ?? this.readingpassage,
      timeLimit: timeLimit ?? this.timeLimit,
      questions: questions ?? this.questions,
    );
  }
}
