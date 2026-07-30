import 'package:ireader_web/model/wordrecognitionquestions.dart';

class WordRecognition {
  final String id;
  final String sectionid;
  final String schoolyearid;
  final String title;
  final String gradelevel;
  final String visibility;
  final String category;
  final List<Wordrecognitionquestions> questions;

  WordRecognition({
    required this.id,
    required this.sectionid,
    required this.schoolyearid,
    required this.title,
    required this.gradelevel,
    required this.visibility,
    required this.category,
    required this.questions,
  });

  factory WordRecognition.fromMap(String id, Map<String, dynamic> map) {
    return WordRecognition(
      id: id,
      sectionid: map['sectionid'] ?? "",
      schoolyearid: map['schoolyearid'] ?? "",
      title: map['title'] ?? "",
      gradelevel: map['gradelevel'] ?? "",
      visibility: map['visibility'] ?? "",
      category: map['category'] ?? "",
      questions: ((map['questions'] ?? []) as List)
          .map((e) => Wordrecognitionquestions.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    final map = {
      'sectionid': sectionid,
      'schoolyearid': schoolyearid,
      'title': title,
      'gradelevel': gradelevel,
      'visibility': visibility,
      'category': category,
      'questions': questions.map((e) => e.toMap()).toList(),
    };
    return map;
  }

  WordRecognition copyWith({
    String? sectionid,
    String? schoolyearid,
    String? title,
    String? gradelevel,
    String? visibility,
    String? category,
    List<Wordrecognitionquestions>? questions,
  }) {
    return WordRecognition(
      id: id,
      sectionid: sectionid ?? this.sectionid,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      title: title ?? this.title,
      gradelevel: gradelevel ?? this.gradelevel,
      visibility: visibility ?? this.visibility,
      category: category ?? this.category,
      questions: questions ?? this.questions,
    );
  }
}
