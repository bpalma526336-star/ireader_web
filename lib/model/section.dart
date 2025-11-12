import 'package:ireader_web/model/student.dart';

class Section {
  final String id;
  final String sectionname;
  final String schoolyearid;
  final String teacherid;

  Section({
    required this.id,
    required this.sectionname,
    required this.schoolyearid,
    required this.teacherid,
  });

  factory Section.fromMap(String id, Map<String, dynamic> map) {
    return Section(
      id: id,
      sectionname: map['sectionname'] ?? "",
      schoolyearid: map['schoolyearid'] ?? "",
      teacherid: map['teacherid'] ?? "",
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'sectionname': sectionname,
      'schoolyearid': schoolyearid,
      'teacherid': teacherid,
    };
  }

  Section copyWith({
    String? sectionname,
    String? schoolyearid,
    String? teacherid,
  }) {
    return Section(
      id: id,
      sectionname: sectionname ?? this.sectionname,
      schoolyearid: schoolyearid ?? this.schoolyearid,
      teacherid: teacherid ?? this.teacherid,
    );
  }
}
