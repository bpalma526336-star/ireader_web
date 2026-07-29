import 'package:ireader_web/model/assessmentcontent.dart';

class Assessment {
  final String id;
  final String schoolyearid;
  final String assessmenttitle;
  final String visibility;
  final int timelimit;
  final String date;
  final String accesscode;
  final String readingpassagetitle;
  final String readingpassagecontent;
  final int totalwords;
  final List<AssessmentContent> questions;

  Assessment({
    required this.id,
    required this.schoolyearid,
    required this.assessmenttitle,
    required this.visibility,
    required this.timelimit,
    required this.date,
    required this.accesscode,
    required this.readingpassagetitle,
    required this.readingpassagecontent,
    required this.totalwords,
    required this.questions,
  });

  factory Assessment.fromMap(String id, Map<String, dynamic> map) {
    return Assessment(
      id: id,
      schoolyearid: map['schoolyearid'] ?? "",
      assessmenttitle: map['assessmenttitle'] ?? "",
      visibility: map['visibility'] ?? "",
      timelimit: map['timelimit'] ?? "",
      date: map['date'] ?? "",
      accesscode: map['accesscode'] ?? "",
      readingpassagetitle: map['readingpassagetitle'] ?? "",
      readingpassagecontent: map['readingpassagecontent'] ?? "",
      totalwords: map['totalwords'] ?? "",
      questions: ((map['questions'] ?? []) as List)
          .map((e) => AssessmentContent.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'schoolyearid': schoolyearid,
      'assessmenttitle': assessmenttitle,
      'visibility': visibility,
      'timelimit': timelimit,
      'date': date,
      'accesscode': accesscode,
      'readingpassagetitle': readingpassagetitle,
      'readingpassagecontent': readingpassagecontent,
      'totalwords': totalwords,
      'questions': questions.map((e) => e.toMap()).toList(),
    };
  }

  Assessment copywith({
    String? schoolyearid,
    String? assessmenttitle,
    String? visibility,
    int? timelimit,
    String? date,
    String? accesscode,
    String? readingpassagetitle,
    String? readingpassagecontent,
    int? totalwords,
    List<AssessmentContent>? questions,
  }) {
    return Assessment(
      id: id,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      assessmenttitle: assessmenttitle ?? this.assessmenttitle,
      visibility: visibility ?? this.visibility,
      timelimit: timelimit ?? this.timelimit,
      date: date ?? this.date,
      accesscode: accesscode ?? this.accesscode,
      readingpassagetitle: readingpassagetitle ?? this.readingpassagetitle,
      readingpassagecontent:
          readingpassagecontent ?? this.readingpassagecontent,
      totalwords: totalwords ?? this.totalwords,
      questions: questions ?? this.questions,
    );
  }
}
