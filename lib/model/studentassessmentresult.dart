import 'package:ireader_web/model/compresultdetail.dart';

class CompAssessmentResult {
  final String id;
  final String studentid;
  final String assessmentid;
  final String timefinished;
  final String correctitems;
  final String incorrectitems;
  final String totalitems;
  final String readingpassagetitle;
  final String readingpassage;
  final List<compleveldetails> compresultdetails;
  final String resultpercentage;
  final String result;

  CompAssessmentResult({
    required this.id,
    required this.studentid,
    required this.assessmentid,
    required this.timefinished,
    required this.correctitems,
    required this.incorrectitems,
    required this.totalitems,
    required this.resultpercentage,
    required this.result,
    required this.readingpassagetitle,
    required this.readingpassage,
    required this.compresultdetails,
  });

  factory CompAssessmentResult.fromMap(String id, Map<String, dynamic> map) {
    return CompAssessmentResult(
      id: id,
      studentid: map['studentid'] ?? "",
      assessmentid: map['assessmentid'] ?? "",
      timefinished: map['timefinished'] ?? "",
      correctitems: map['correctitems'] ?? "",
      incorrectitems: map['incorrectitems'] ?? "",
      totalitems: map['totalitems'] ?? "",
      resultpercentage: map['resultpercentage'] ?? "",
      result: map['result'] ?? "",
      readingpassagetitle: map['readingpassagetitle'] ?? "",
      readingpassage: map['readingpassage'] ?? "",
      compresultdetails: ((map['complevelhistorydetails'] ?? []) as List)
          .map((e) => compleveldetails.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'studentid': studentid,
      'assessmentid': assessmentid,
      'timefinished': timefinished,
      'correctitems': correctitems,
      'incorrectitems': incorrectitems,
      'totalitems': totalitems,
      'resultpercentage': resultpercentage,
      'result': result,
      'readingpassagetitle': readingpassagetitle,
      'readingpassage': readingpassage,
      'complevelhistorydetails': compresultdetails
          .map((e) => e.toMap())
          .toList(),
    };
  }

  CompAssessmentResult copyWith({
    String? studentid,
    String? assessmentid,
    String? readingassessmentid,
    String? timefinished,
    String? correctitems,
    String? incorrectitems,
    String? totalitems,
    String? resultpercentage,
    String? result,
    String? readingpassagetitle,
    String? readingpassage,
    List<compleveldetails>? compresultdetails,
  }) {
    return CompAssessmentResult(
      id: id,
      studentid: studentid ?? this.studentid,
      assessmentid: assessmentid ?? this.assessmentid,
      timefinished: timefinished ?? this.timefinished,
      correctitems: correctitems ?? this.correctitems,
      incorrectitems: incorrectitems ?? this.incorrectitems,
      totalitems: totalitems ?? this.totalitems,
      resultpercentage: resultpercentage ?? this.resultpercentage,
      result: result ?? this.result,
      readingpassagetitle: readingpassagetitle ?? this.readingpassagetitle,
      readingpassage: readingpassage ?? this.readingpassage,
      compresultdetails: compresultdetails ?? this.compresultdetails,
    );
  }
}
