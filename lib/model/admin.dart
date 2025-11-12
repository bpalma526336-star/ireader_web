class Admin {
  final String id;
  final String firstname;
  final String middlename;
  final String lastname;
  final String email;
  final String phonenumber;
  final String status;

  Admin({
    required this.id,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.email,
    required this.phonenumber,
    required this.status,
  });

  factory Admin.fromMap(String id, Map<String, dynamic> map) {
    return Admin(
      id: id,
      firstname: map['firstname'] ?? "",
      middlename: map['middlename'] ?? "",
      lastname: map['lastname'] ?? "",
      email: map['email'] ?? "",
      phonenumber: map['phonenumber'] ?? "",
      status: map['status'] ?? "",
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'firstname': firstname,
      'middlename': middlename,
      'lastname': lastname,
      'email': email,
      'phonenumber': phonenumber,
      'status': status,
    };
  }

  Admin copyWith({
    String? firstname,
    String? middlename,
    String? lastname,
    String? email,
    String? phonenumber,
    String? status,
  }) {
    return Admin(
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
