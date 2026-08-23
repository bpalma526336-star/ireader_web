class Division {
  final String id;
  final String name;
  final String status;

  Division({required this.id, required this.name, required this.status});

  factory Division.fromMap(String id, Map<String, dynamic> map) {
    return Division(
      id: id,
      name: map['name'] ?? '',
      status: map['status'] ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'status': status,
  };

  Division copyWith({String? name, String? status}) {
    return Division(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
    );
  }
}
