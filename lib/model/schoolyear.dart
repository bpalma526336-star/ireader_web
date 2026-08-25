class SchoolYear {
  final String id;
  final String? schoolid;
  final String schoolyearstart;
  final String schoolyearend;

  SchoolYear({
    required this.id,
    this.schoolid,
    required this.schoolyearstart,
    required this.schoolyearend,
  });

  factory SchoolYear.fromMap(String id, Map<String, dynamic> map) {
    return SchoolYear(
      id: id,
      schoolid: map['schoolid'],
      schoolyearstart: map['schoolyearstart'] ?? "",
      schoolyearend: map['schoolyearend'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolid': schoolid,
      'schoolyearstart': schoolyearstart,
      'schoolyearend': schoolyearend,
    };
  }

  SchoolYear copyWith({
    String? schoolid,
    String? schoolyear,
    String? schoolyearstart,
    String? schoolyearend,
  }) {
    return SchoolYear(
      id: id,
      schoolid: schoolid ?? this.schoolid,
      schoolyearstart: schoolyearstart ?? this.schoolyearstart,
      schoolyearend: schoolyearend ?? this.schoolyearend,
    );
  }
}
