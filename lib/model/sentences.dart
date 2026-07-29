import 'package:ireader_web/model/sentencesquestion.dart';

class sentencespracticeset {
  final String id;
  final String sectionid;
  final String schoolyearid;
  final String title;
  final String gradelevel;
  final String visibility;
  final String category;
  final List<sentencequestions> questions;

  sentencespracticeset({
    required this.id,
    required this.sectionid,
    required this.schoolyearid,
    required this.title,
    required this.gradelevel,
    required this.visibility,
    required this.category,
    required this.questions,
  });

  factory sentencespracticeset.fromMap(String id, Map<String, dynamic> map) {
    return sentencespracticeset(
      id: id,
      sectionid: map['sectionid'] ?? "",
      schoolyearid: map['schoolyearid'] ?? "",
      title: map['title'] ?? "",
      gradelevel: map['gradelevel'] ?? "",
      visibility: map['visibility'] ?? "",
      category: map['category'] ?? "",
      questions: ((map['questions'] ?? []) as List)
          .map((e) => sentencequestions.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    final map = {
      'title': title,
      'sectionid': sectionid,
      'schoolyearid': schoolyearid,
      'gradelevel': gradelevel,
      'visibility': visibility,
      'category': category,
      'questions': questions.map((e) => e.toMap()).toList(),
    };

    return map;
  }

  sentencespracticeset copyWith({
    String? id,
    String? sectionid,
    String? schoolyearid,
    String? title,
    String? gradelevel,
    String? visibility,
    String? category,
    List<sentencequestions>? questions,
  }) {
    return sentencespracticeset(
      id: id ?? this.id,
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
