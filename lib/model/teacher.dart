class Teacher {
  final String id;
  final String firstname;
  final String? middlename;
  final String lastname;
  final String email;
  final String status;
  final String? schoolid;

  Teacher({
    required this.id,
    required this.firstname,
    this.middlename,
    required this.lastname,
    required this.email,
    required this.status,
    this.schoolid,
  });

  factory Teacher.fromMap(String id, Map<String, dynamic> map) {
    return Teacher(
      id: id,
      firstname: map['firstname'] ?? "",
      middlename: map['middlename'],
      lastname: map['lastname'] ?? "",
      email: map['email'] ?? "",
      status: map['status'] ?? "",
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
      'schoolid': schoolid,
    };
  }

  Teacher copyWith({
    String? firstname,
    String? middlename,
    String? lastname,
    String? email,
    String? status,
    String? schoolid,
  }) {
    return Teacher(
      id: id,
      firstname: firstname ?? this.firstname,
      middlename: middlename ?? this.middlename,
      lastname: lastname ?? this.lastname,
      email: email ?? this.email,
      status: status ?? this.status,
      schoolid: schoolid ?? this.schoolid,
    );
  }
}
