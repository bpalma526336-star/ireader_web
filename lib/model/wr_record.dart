import 'package:ireader_web/model/wr_record_questions.dart';

class wr_record {
  final String id;
  final String studentid;
  final String correctitems;
  final String incorrectitems;
  final String totalitems;
  final String resultpercentage;
  final String timestamp;
  final List<wr_record_details> wrresultdetails;

  wr_record({
    required this.id,
    required this.studentid,
    required this.correctitems,
    required this.incorrectitems,
    required this.totalitems,
    required this.resultpercentage,
    required this.timestamp,
    required this.wrresultdetails,
  });

  factory wr_record.fromMap(String id, Map<String, dynamic> map) {
    return wr_record(
      id: id,
      studentid: map['studentid'] ?? "",
      correctitems: map['correctitems'] ?? "",
      incorrectitems: map['incorrectitems'] ?? "",
      totalitems: map['totalitems'] ?? "",
      resultpercentage: map['resultpercentage'] ?? "",
      timestamp: map['timestamp'] ?? "",
      wrresultdetails: ((map['wrhistorydetails'] ?? []) as List)
          .map(
            (e) => wr_record_details(
              question: e['question'] ?? "",
              selectedanswer: e['selectedanswer'] ?? "",
              correctanswer: e['correctanswer'] ?? "",
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'studentid': studentid,
      'correctitems': correctitems,
      'incorrectitems': incorrectitems,
      'totalitems': totalitems,
      'resultpercentage': resultpercentage,
      'timestamp': timestamp,
      'wrhistorydetails': wrresultdetails
          .map(
            (e) => {
              'question': e.question,
              'selectedanswer': e.selectedanswer,
              'correctanswer': e.correctanswer,
            },
          )
          .toList(),
    };
  }

  wr_record copyWith({
    String? id,
    String? studentid,
    String? correctitems,
    String? incorrectitems,
    String? totalitems,
    String? resultpercentage,
    String? timestamp,
    List<wr_record_details>? wrresultdetails,
  }) {
    return wr_record(
      id: id ?? this.id,
      studentid: studentid ?? this.studentid,
      correctitems: correctitems ?? this.correctitems,
      incorrectitems: incorrectitems ?? this.incorrectitems,
      totalitems: totalitems ?? this.totalitems,
      resultpercentage: resultpercentage ?? this.resultpercentage,
      timestamp: timestamp ?? this.timestamp,
      wrresultdetails: wrresultdetails ?? this.wrresultdetails,
    );
  }
}
