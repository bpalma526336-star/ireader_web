import 'package:ireader_web/model/complevelhistorydetail.dart';

class CompAssessmentResult {
  final String id;
  final String studentid;
  final String assessmentid;
  final String timefinished;
  final String correctitems;
  final String incorrectitems;
  final String totalitems;
  // final List<compleveldetails> complevelhistorydetails;
  final String result;

  CompAssessmentResult({
    required this.id,
    required this.studentid,
    required this.assessmentid,
    required this.timefinished,
    required this.correctitems,
    required this.incorrectitems,
    required this.totalitems,
    required this.result,
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
      result: map['result'] ?? "",
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
      'result': result,
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
    String? result,
  }) {
    return CompAssessmentResult(
      id: id,
      studentid: studentid ?? this.studentid,
      assessmentid: assessmentid ?? this.assessmentid,
      timefinished: timefinished ?? this.timefinished,
      correctitems: correctitems ?? this.correctitems,
      incorrectitems: incorrectitems ?? this.incorrectitems,
      totalitems: totalitems ?? this.totalitems,
      result: result ?? this.result,
    );
  }
}
