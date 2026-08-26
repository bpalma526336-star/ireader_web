import 'package:ireader_web/model/assessmentcontent.dart';

class Assessment {
  final String id;
  final String schoolyearid;
  final String? schoolid;
  final String assessmenttitle;
  final String visibility;
  final int timelimit;
  final String date;
  final String accesscode;
  final String readingpassagetitle;
  final String readingpassagecontent;
  final int totalwords;
  final List<AssessmentContent> questions;
  final String? testtype;

  Assessment({
    required this.id,
    required this.schoolyearid,
    this.schoolid,
    required this.assessmenttitle,
    required this.visibility,
    required this.timelimit,
    required this.date,
    required this.accesscode,
    required this.readingpassagetitle,
    required this.readingpassagecontent,
    required this.totalwords,
    required this.questions,
    this.testtype,
  });

  factory Assessment.fromMap(String id, Map<String, dynamic> map) {
    return Assessment(
      id: id,
      schoolyearid: map['schoolyearid'] ?? "",
      schoolid: map['schoolid'] ?? "",
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
      testtype: map['testtype'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'schoolyearid': schoolyearid,
      'schoolid': schoolid,
      'assessmenttitle': assessmenttitle,
      'visibility': visibility,
      'timelimit': timelimit,
      'date': date,
      'accesscode': accesscode,
      'readingpassagetitle': readingpassagetitle,
      'readingpassagecontent': readingpassagecontent,
      'totalwords': totalwords,
      'questions': questions.map((e) => e.toMap()).toList(),
      'testtype': testtype,
    };
  }

  Assessment copywith({
    String? schoolyearid,
    String? schoolid,
    String? assessmenttitle,
    String? visibility,
    int? timelimit,
    String? date,
    String? accesscode,
    String? readingpassagetitle,
    String? readingpassagecontent,
    int? totalwords,
    List<AssessmentContent>? questions,
    String? testtype,
  }) {
    return Assessment(
      id: id,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      schoolid: schoolid ?? this.schoolid,
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
      testtype: testtype ?? this.testtype,
    );
  }
}
