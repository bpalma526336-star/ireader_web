class School {
  final String id;
  final String name;
  final String divisionid;
  final List<String>? schoolyearids;
  final String? address;
  final String status;

  School({
    required this.id,
    required this.name,
    required this.divisionid,
    this.schoolyearids,
    this.address,
    required this.status,
  });

  factory School.fromMap(String id, Map<String, dynamic> map) {
    return School(
      id: id,
      name: map['name'] ?? '',
      divisionid: map['divisionid'] ?? '',
      schoolyearids: (map['schoolyearids'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      address: map['address'],
      status: map['status'] ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'divisionid': divisionid,
    'schoolyearids': schoolyearids,
    'address': address,
    'status': status,
  };

  School copyWith({
    String? name,
    String? divisionid,
    List<String>? schoolyearids,
    String? address,
    String? status,
  }) {
    return School(
      id: id,
      name: name ?? this.name,
      divisionid: divisionid ?? this.divisionid,
      schoolyearids: schoolyearids ?? this.schoolyearids,
      address: address ?? this.address,
      status: status ?? this.status,
    );
  }
}
