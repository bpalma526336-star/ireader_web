class Parent {
  final String id;
  final String firstname;
  final String? middlename;
  final String lastname;
  final String accesscode;
  final String status;
  final List<String>? studentids;

  Parent({
    required this.id,
    required this.firstname,
    this.middlename,
    required this.lastname,
    required this.accesscode,
    required this.status,
    this.studentids,
  });

  factory Parent.fromMap(String id, Map<String, dynamic> map) {
    return Parent(
      id: id,
      firstname: map['firstname'] ?? "",
      middlename: map['middlename'],
      lastname: map['lastname'] ?? "",
      accesscode: map['accesscode'] ?? "",
      status: map['status'] ?? "",
      studentids: map['studentids'] == null
          ? null
          : List<String>.from(map['studentids']),
    );
  }

  Map<String, dynamic> toMap({bool isUpdate = false}) {
    return {
      'firstname': firstname,
      'middlename': middlename,
      'lastname': lastname,
      'accesscode': accesscode,
      'status': status,
      'studentids': studentids,
    };
  }

  Parent copyWith({
    String? firstname,
    String? middlename,
    String? lastname,
    String? accesscode,
    String? status,
    List<String>? studentids,
  }) {
    return Parent(
      id: id,
      firstname: firstname ?? this.firstname,
      middlename: middlename ?? this.middlename,
      lastname: lastname ?? this.lastname,
      accesscode: accesscode ?? this.accesscode,
      status: status ?? this.status,
      studentids: studentids ?? this.studentids,
    );
  }
}
