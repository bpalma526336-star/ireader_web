class RC {
  final String id;
  final String firstname;
  final String middlename;
  final String lastname;
  final String email;
  final String phonenumber;
  final String status;

  RC({
    required this.id,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.email,
    required this.phonenumber,
    required this.status,
  });

  factory RC.fromMap(String id, Map<String, dynamic> map) {
    return RC(
      id: id,
      firstname: map['firstname'] ?? "",
      middlename: map['middlename'] ?? "",
      lastname: map['lastname'] ?? "",
      email: map['email'] ?? "",
      phonenumber: map['phonenumber'] ?? "",
      status: map['status'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstname': firstname,
      'middlename': middlename,
      'lastname': lastname,
      'email': email,
      'phonenumber': phonenumber,
      'status': status,
    };
  }

  RC copyWith({
    String? firstname,
    String? middlename,
    String? lastname,
    String? email,
    String? phonenumber,
    String? status,
  }) {
    return RC(
      id: id,
      firstname: firstname ?? this.firstname,
      middlename: middlename ?? this.middlename,
      lastname: lastname ?? this.lastname,
      email: email ?? this.email,
      phonenumber: phonenumber ?? this.phonenumber,
      status: status ?? this.status,
    );
  }
}
