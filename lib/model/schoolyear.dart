class SchoolYear {
  final String id;
  final String schoolyearstart;
  final String schoolyearend;

  SchoolYear({
    required this.id,
    required this.schoolyearstart,
    required this.schoolyearend,
  });

  factory SchoolYear.fromMap(String id, Map<String, dynamic> map) {
    return SchoolYear(
      id: id,
      schoolyearstart: map['schoolyearstart'] ?? "",
      schoolyearend: map['schoolyearend'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {'schoolyearstart': schoolyearstart, 'schoolyearend': schoolyearend};
  }

  SchoolYear copyWith({
    String? schoolyear,
    String? schoolyearstart,
    String? schoolyearend,
  }) {
    return SchoolYear(
      id: id,
      schoolyearstart: schoolyearstart ?? this.schoolyearstart,
      schoolyearend: schoolyearend ?? this.schoolyearend,
    );
  }
}
