import 'package:ireader_web/model/ps_record_questions.dart';

class ps_record {
  final String id;
  final String studentid;
  final String psid;
  final String correctitems;
  final String incorrectitems;
  final String totalitems;
  final String resultpercentage;
  final String timestamp;
  final List<ps_record_details> psresultdetails;

  ps_record({
    required this.id,
    required this.studentid,
    required this.psid,
    required this.correctitems,
    required this.incorrectitems,
    required this.totalitems,
    required this.resultpercentage,
    required this.timestamp,
    required this.psresultdetails,
  });

  factory ps_record.fromMap(String id, Map<String, dynamic> map) {
    return ps_record(
      id: id,
      studentid: map['studentid'] ?? "",
      psid: map['psid'] ?? "",
      correctitems: map['correctitems'] ?? "",
      incorrectitems: map['incorrectitems'] ?? "",
      totalitems: map['totalitems'] ?? "",
      resultpercentage: map['resultpercentage'] ?? "",
      timestamp: map['timestamp'] ?? "",
      psresultdetails: ((map['pshistorydetails'] ?? []) as List)
          .map(
            (e) => ps_record_details(
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
      'psid': psid,
      'correctitems': correctitems,
      'incorrectitems': incorrectitems,
      'totalitems': totalitems,
      'resultpercentage': resultpercentage,
      'timestamp': timestamp,
      'pshistorydetails': psresultdetails
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

  ps_record copyWith({
    String? id,
    String? studentid,
    String? psid,
    String? correctitems,
    String? incorrectitems,
    String? totalitems,
    String? resultpercentage,
    String? timestamp,
    List<ps_record_details>? psresultdetails,
  }) {
    return ps_record(
      id: id ?? this.id,
      studentid: studentid ?? this.studentid,
      psid: psid ?? this.psid,
      correctitems: correctitems ?? this.correctitems,
      incorrectitems: incorrectitems ?? this.incorrectitems,
      totalitems: totalitems ?? this.totalitems,
      resultpercentage: resultpercentage ?? this.resultpercentage,
      timestamp: timestamp ?? this.timestamp,
      psresultdetails: psresultdetails ?? this.psresultdetails,
    );
  }
}
