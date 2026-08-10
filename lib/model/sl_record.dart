import 'package:ireader_web/model/sl_record_questions.dart';

class sl_record {
  final String id;
  final String studentid;
  final String slid;
  final String correctitems;
  final String incorrectitems;
  final String totalitems;
  final String readingpassagetitle;
  final String readingpassage;
  final String resultpercentage;
  final String timestamp;
  final List<sl_record_details> slresultdetails;

  sl_record({
    required this.id,
    required this.studentid,
    required this.slid,
    required this.correctitems,
    required this.incorrectitems,
    required this.totalitems,
    required this.readingpassagetitle,
    required this.readingpassage,
    required this.resultpercentage,
    required this.timestamp,
    required this.slresultdetails,
  });

  factory sl_record.fromMap(
    Map<String, dynamic> map, {
    // Map<String, dynamic> data,
    String? id,
  }) {
    return sl_record(
      id: id ?? "",
      studentid: map['studentid'] ?? "",
      slid: map['slid'] ?? "",
      correctitems: map['correctitems'] ?? "",
      incorrectitems: map['incorrectitems'] ?? "",
      totalitems: map['totalitems'] ?? "",
      readingpassagetitle: map['readingpassagetitle'] ?? "",
      readingpassage: map['readingpassage'] ?? "",
      resultpercentage: map['resultpercentage'] ?? "",
      timestamp: map['timestamp'] ?? "",
      slresultdetails: ((map['slhistorydetails'] ?? []) as List)
          .map(
            (e) => sl_record_details(
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
      'slid': slid,
      'correctitems': correctitems,
      'incorrectitems': incorrectitems,
      'totalitems': totalitems,
      'readingpassagetitle': readingpassagetitle,
      'readingpassage': readingpassage,
      'resultpercentage': resultpercentage,
      'timestamp': timestamp,
      'slhistorydetails': slresultdetails.map((e) => e.toMap()).toList(),
    };
  }

  sl_record copyWith({
    String? id,
    String? studentid,
    String? slid,
    String? correctitems,
    String? incorrectitems,
    String? totalitems,
    String? readingpassagetitle,
    String? readingpassage,
    String? resultpercentage,
    String? timestamp,
    List<sl_record_details>? slresultdetails,
  }) {
    return sl_record(
      id: id ?? this.id,
      studentid: studentid ?? this.studentid,
      slid: slid ?? this.slid,
      correctitems: correctitems ?? this.correctitems,
      incorrectitems: incorrectitems ?? this.incorrectitems,
      totalitems: totalitems ?? this.totalitems,
      readingpassagetitle: readingpassagetitle ?? this.readingpassagetitle,
      readingpassage: readingpassage ?? this.readingpassage,
      resultpercentage: resultpercentage ?? this.resultpercentage,
      timestamp: timestamp ?? this.timestamp,
      slresultdetails: slresultdetails ?? this.slresultdetails,
    );
  }
}
