import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';

class importstudentscreen extends StatefulWidget {
  final Student? student;
  final Section section;
  final SchoolYear schoolyear;
  const importstudentscreen({
    super.key,
    required this.section,
    required this.schoolyear,
    required this.student,
  });

  @override
  State<importstudentscreen> createState() => _importstudentscreenState();
}

class _importstudentscreenState extends State<importstudentscreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Import Students Using Excel File")),
    );
  }
}
