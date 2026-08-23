class School {
  final String id;
  final String name;
  final String divisionid;
  final String? address;
  final String status;

  School({
    required this.id,
    required this.name,
    required this.divisionid,
    this.address,
    required this.status,
  });

  factory School.fromMap(String id, Map<String, dynamic> map) {
    return School(
      id: id,
      name: map['name'] ?? '',
      divisionid: map['divisionid'] ?? '',
      address: map['address'],
      status: map['status'] ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'divisionid': divisionid,
    'address': address,
    'status': status,
  };

  School copyWith({
    String? name,
    String? divisionid,
    String? address,
    String? status,
  }) {
    return School(
      id: id,
      name: name ?? this.name,
      divisionid: divisionid ?? this.divisionid,
      address: address ?? this.address,
      status: status ?? this.status,
    );
  }
}
