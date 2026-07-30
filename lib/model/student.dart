class Student {
  final String id;
  final String lrn;
  final String sectionid;
  final String schoolyearid;
  final String firstname;
  final String? middlename;
  final String lastname;
  final String gender;
  final String gstscore;
  final String gradelevelread;
  final String readlevel;
  final String readingresult;
  final String comprehensionresult;
  final String status;

  Student({
    required this.id,
    required this.lrn,
    required this.sectionid,
    required this.schoolyearid,
    required this.firstname,
    this.middlename,
    required this.lastname,
    required this.gender,
    required this.gstscore,
    required this.gradelevelread,
    required this.readlevel,
    required this.readingresult,
    required this.comprehensionresult,
    required this.status,
  });

  factory Student.fromMap(String id, Map<String, dynamic> map) {
    return Student(
      id: id,
      lrn: map['lrn'] ?? "",
      sectionid: map['sectionid'] ?? "",
      schoolyearid: map['schoolyearid'] ?? "",
      firstname: map['firstname'] ?? "",
      middlename: map['middlename'],
      lastname: map['lastname'] ?? "",
      gender: map['gender'] ?? "",
      gstscore: map['gstscore'] ?? "",
      gradelevelread: map['gradelevelread'] ?? "",
      readlevel: map['readlevel'] ?? "",
      readingresult: map['readingresult'] ?? "",
      comprehensionresult: map['comprehensionresult'] ?? "",
      status: map['status'] ?? "",
    );
  }
  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'id': id,
      'lrn': lrn,
      'sectionid': sectionid,
      'schoolyearid': schoolyearid,
      'firstname': firstname,
      'middlename': middlename,
      'lastname': lastname,
      'gender': gender,
      'gstscore': gstscore,
      'gradelevelread': gradelevelread,
      'readlevel': readlevel,
      'readingresult': readingresult,
      'comprehensionresult': comprehensionresult,
      'status': status,
    };
  }

  Student copyWith({
    String? sectionid,
    String? lrn,
    String? schoolyearid,
    String? firstname,
    String? middlename,
    String? lastname,
    String? gender,
    String? gstscore,
    String? gradelevelread,
    String? readlevel,
    String? readingresult,
    String? comprehensionresult,
    String? status,
  }) {
    return Student(
      id: id,
      lrn: lrn ?? this.lrn,
      sectionid: sectionid ?? this.sectionid,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      firstname: firstname ?? this.firstname,
      middlename: middlename ?? this.middlename,
      lastname: lastname ?? this.lastname,
      gender: gender ?? this.gender,
      gstscore: gstscore ?? this.gstscore,
      gradelevelread: gradelevelread ?? this.gradelevelread,
      readlevel: readlevel ?? this.readlevel,
      readingresult: readingresult ?? this.readingresult,
      comprehensionresult: comprehensionresult ?? this.comprehensionresult,
      status: status ?? this.status,
    );
  }
}
