class Section {
  final String id;
  final String sectionname;
  final String schoolyearid;
  final String? schoolid;
  final String? divisionid;
  final String teacherid;

  Section({
    required this.id,
    required this.sectionname,
    required this.schoolyearid,
    this.schoolid,
    this.divisionid,
    required this.teacherid,
  });

  factory Section.fromMap(String id, Map<String, dynamic> map) {
    return Section(
      id: id,
      sectionname: map['sectionname'] ?? "",
      schoolyearid: map['schoolyearid'] ?? "",
      schoolid: map['schoolid'] ?? "",
      divisionid: map['divisionid'] ?? "",
      teacherid: map['teacherid'] ?? "",
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'sectionname': sectionname,
      'schoolyearid': schoolyearid,
      'schoolid': schoolid,
      'divisionid': divisionid,
      'teacherid': teacherid,
    };
  }

  Section copyWith({
    String? sectionname,
    String? schoolyearid,
    String? schoolid,
    String? divisionid,
    String? teacherid,
  }) {
    return Section(
      id: id,
      sectionname: sectionname ?? this.sectionname,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      schoolid: schoolid ?? this.schoolid,
      divisionid: divisionid ?? this.divisionid,
      teacherid: teacherid ?? this.teacherid,
    );
  }
}
