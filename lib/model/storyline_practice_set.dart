import 'package:ireader_web/model/storyline_practice_set_content.dart';

class StorylinePracticeSet {
  final String id;
  final String sectionid;
  final String schoolyearid;
  final String title;
  final String category;
  final String gradelevel;
  final String visibility;
  final String readingpassage;
  final List<StorylinePracticeSetContent> questions;

  StorylinePracticeSet({
    required this.id,
    required this.sectionid,
    required this.schoolyearid,
    required this.title,
    required this.category,
    required this.visibility,
    required this.readingpassage,
    required this.gradelevel,
    required this.questions,
  });

  factory StorylinePracticeSet.fromMap(String id, Map<String, dynamic> map) {
    return StorylinePracticeSet(
      id: id,
      sectionid: map['sectionid'] ?? "",
      schoolyearid: map['schoolyearid'] ?? "",
      title: map['practicesettitle'] ?? "",
      category: map['category'] ?? "",
      visibility: map['visibility'] ?? "",
      readingpassage: map['readingpassage'] ?? "",
      gradelevel: map['gradelevel'] ?? "",
      questions: ((map['questions'] ?? []) as List)
          .map((e) => StorylinePracticeSetContent.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'practicesettitle': title,
      'sectionid': sectionid,
      'schoolyearid': schoolyearid,
      'category': category,
      'visibility': visibility,
      'readingpassage': readingpassage,
      'gradelevel': gradelevel,
      'questions': questions.map((e) => e.toMap()).toList(),
    };
  }

  StorylinePracticeSet copyWith({
    String? title,
    String? sectionid,
    String? schoolyearid,
    String? category,
    String? visibility,
    String? readingpassage,
    String? gradelevel,
    List<StorylinePracticeSetContent>? questions,
  }) {
    return StorylinePracticeSet(
      id: id,
      sectionid: sectionid ?? this.sectionid,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      title: title ?? this.title,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      readingpassage: readingpassage ?? this.readingpassage,
      gradelevel: gradelevel ?? this.gradelevel,
      questions: questions ?? this.questions,
    );
  }
}
