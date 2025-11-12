class studentlevelhistory {
  final String id;
  final String studentid;
  final String assessmentid;
  final String wordreadresult;
  final String readcompresult;
  final String readlevel;

  studentlevelhistory({
    required this.id,
    required this.studentid,
    required this.assessmentid,
    required this.wordreadresult,
    required this.readcompresult,
    required this.readlevel,
  });

  factory studentlevelhistory.fromMap(String id, Map<String, dynamic> map) {
    return studentlevelhistory(
      id: id,
      studentid: map['studentid'] ?? "",
      assessmentid: map['assessmentid'] ?? "",
      wordreadresult: map['wordreadresult'] ?? "",
      readcompresult: map['readcompresult'] ?? "",
      readlevel: map['readlevel'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentid': studentid,
      'assessmentid': assessmentid,
      'wordreadresult': wordreadresult,
      'readcompresult': readcompresult,
      'readlevel': readlevel,
    };
  }

  studentlevelhistory copywith({
    String? studentid,
    String? assessmentid,
    String? wordreadresult,
    String? readcompresult,
    String? readlevel,
  }) {
    return studentlevelhistory(
      id: id,
      studentid: studentid ?? this.studentid,
      assessmentid: assessmentid ?? this.assessmentid,
      wordreadresult: wordreadresult ?? this.wordreadresult,
      readcompresult: readcompresult ?? this.readcompresult,
      readlevel: readlevel ?? this.readlevel,
    );
  }
}
