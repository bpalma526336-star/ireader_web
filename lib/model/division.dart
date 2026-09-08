class Division {
  final String id;
  final String name;
  final String status;
  final List<String>? schoolyearids;

  Division({
    required this.id,
    required this.name,
    required this.status,
    this.schoolyearids,
  });

  factory Division.fromMap(String id, Map<String, dynamic> map) {
    return Division(
      id: id,
      name: map['name'] ?? '',
      status: map['status'] ?? 'ACTIVE',
      schoolyearids: (map['schoolyearids'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'status': status,
    'schoolyearids': schoolyearids,
  };

  Division copyWith({
    String? name,
    String? status,
    List<String>? schoolyearids,
  }) {
    return Division(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      schoolyearids: schoolyearids ?? this.schoolyearids,
    );
  }
}
