class RC {
  final String id;
  final String firstname;
  final String? middlename;
  final String lastname;
  final String email;
  final String status;
  final String? divisionid;
  final String? schoolid;

  RC({
    required this.id,
    required this.firstname,
    this.middlename,
    required this.lastname,
    required this.email,
    required this.status,
    this.divisionid,
    this.schoolid,
  });

  factory RC.fromMap(String id, Map<String, dynamic> map) {
    return RC(
      id: id,
      firstname: map['firstname'] ?? "",
      middlename: map['middlename'],
      lastname: map['lastname'] ?? "",
      email: map['email'] ?? "",
      status: map['status'] ?? "",
      divisionid: map['divisionid'],
      schoolid: map['schoolid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstname': firstname,
      'middlename': middlename,
      'lastname': lastname,
      'email': email,
      'status': status,
      'divisionid': divisionid,
      'schoolid': schoolid,
    };
  }

  RC copyWith({
    String? firstname,
    String? middlename,
    String? lastname,
    String? email,
    String? status,
    String? divisionid,
    String? schoolid,
  }) {
    return RC(
      id: id,
      firstname: firstname ?? this.firstname,
      middlename: middlename ?? this.middlename,
      lastname: lastname ?? this.lastname,
      email: email ?? this.email,
      status: status ?? this.status,
      divisionid: divisionid ?? this.divisionid,
      schoolid: schoolid ?? this.schoolid,
    );
  }
}
