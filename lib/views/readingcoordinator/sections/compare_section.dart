import 'package:flutter/material.dart';
import 'package:ireader_web/model/readingcoordinator.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ireader_web/views/admin/section/compare_section.dart'
    as admin_compare;

class CompareSection extends StatefulWidget {
  final RC rc;
  final SchoolYear schoolYear;

  const CompareSection({super.key, required this.rc, required this.schoolYear});

  @override
  State<CompareSection> createState() => _CompareSectionState();
}

class _CompareSectionState extends State<CompareSection> {
  late final Future<School?> _schoolFuture;

  @override
  void initState() {
    super.initState();
    _schoolFuture = _loadSchool();
  }

  Future<School?> _loadSchool() async {
    final schoolId = widget.rc.schoolid;
    if (schoolId == null || schoolId.isEmpty) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;

    return School.fromMap(snapshot.id, snapshot.data()!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<School?>(
      future: _schoolFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final school = snapshot.data;
        if (school == null) {
          return const Scaffold(
            body: Center(child: Text('Reading coordinator school not found.')),
          );
        }

        return admin_compare.CompareSection(
          schoolYear: widget.schoolYear,
          school: school,
        );
      },
    );
  }
}
