class Section {
  final String id;
  final String sectionname;
  final String schoolyearid;
  final String? schoolid;
  final String teacherid;

  Section({
    required this.id,
    required this.sectionname,
    required this.schoolyearid,
    this.schoolid,
    required this.teacherid,
  });

  factory Section.fromMap(String id, Map<String, dynamic> map) {
    return Section(
      id: id,
      sectionname: map['sectionname'] ?? "",
      schoolyearid: map['schoolyearid'] ?? "",
      schoolid: map['schoolid'] ?? "",
      teacherid: map['teacherid'] ?? "",
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'sectionname': sectionname,
      'schoolyearid': schoolyearid,
      'schoolid': schoolid,
      'teacherid': teacherid,
    };
  }

  Section copyWith({
    String? sectionname,
    String? schoolyearid,
    String? schoolid,
    String? teacherid,
  }) {
    return Section(
      id: id,
      sectionname: sectionname ?? this.sectionname,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      schoolid: schoolid ?? this.schoolid,
      teacherid: teacherid ?? this.teacherid,
    );
  }
}
