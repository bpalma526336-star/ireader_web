class Admin {
  final String id;
  final String firstname;
  final String? middlename;
  final String lastname;
  final String email;
  final String status;

  Admin({
    required this.id,
    required this.firstname,
    this.middlename,
    required this.lastname,
    required this.email,
    required this.status,
  });

  factory Admin.fromMap(String id, Map<String, dynamic> map) {
    return Admin(
      id: id,
      firstname: map['firstname'] ?? "",
      middlename: map['middlename'],
      lastname: map['lastname'] ?? "",
      email: map['email'] ?? "",
      status: map['status'] ?? "",
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'firstname': firstname,
      'middlename': middlename,
      'lastname': lastname,
      'email': email,
      'status': status,
    };
  }

  Admin copyWith({
    String? firstname,
    String? middlename,
    String? lastname,
    String? email,
    String? status,
  }) {
    return Admin(
      id: id,
      firstname: firstname ?? this.firstname,
      middlename: middlename ?? this.middlename,
      lastname: lastname ?? this.lastname,
      email: email ?? this.email,
      status: status ?? this.status,
    );
  }
}
