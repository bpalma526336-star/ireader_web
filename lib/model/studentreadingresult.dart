class StudentReadingresult {
  final String id;
  final String studentid;
  final String assessmentid;
  final String totalwordsread;
  final String totalmiscues;
  final int totalreadingresult;
  final String readinglevel;

  StudentReadingresult({
    required this.id,
    required this.studentid,
    required this.assessmentid,
    required this.totalwordsread,
    required this.totalmiscues,
    required this.totalreadingresult,
    required this.readinglevel,
  });

  factory StudentReadingresult.fromMap(String id, Map<String, dynamic> map) {
    return StudentReadingresult(
      id: id,
      studentid: map['studentid'] ?? "",
      assessmentid: map['assessmentid'] ?? "",
      totalwordsread: map['totalwordsread'] ?? "",
      totalmiscues: map['totalmiscues'] ?? "",
      totalreadingresult: (map['totalreadingresult'] ?? 0) is int
          ? map['totalreadingresult']
          : int.tryParse(map['totalreadingresult'].toString()) ?? 0,
      readinglevel: map['readinglevel'] ?? "",
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'studentid': studentid,
      'assessmentid': assessmentid,
      'totalwordsread': totalwordsread,
      'totalmiscues': totalmiscues,
      'totalreadingresult': totalreadingresult,
      'readinglevel': readinglevel,
    };
  }

  StudentReadingresult copyWith({
    String? studentid,
    String? assessmentid,
    String? totalwordsread,
    String? totalmiscues,
    int? totalreadingresult,
    String? readinglevel,
  }) {
    return StudentReadingresult(
      id: id,
      studentid: studentid ?? this.studentid,
      assessmentid: assessmentid ?? this.assessmentid,
      totalwordsread: totalwordsread ?? this.totalwordsread,
      totalmiscues: totalmiscues ?? this.totalmiscues,
      totalreadingresult: totalreadingresult ?? this.totalreadingresult,
      readinglevel: readinglevel ?? this.readinglevel,
    );
  }
}
