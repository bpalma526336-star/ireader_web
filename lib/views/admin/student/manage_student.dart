import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/student/add_student.dart';
import 'package:ireader_web/views/admin/student/import_students.dart';
import 'package:ireader_web/views/admin/student/student_profile.dart';

class ManageStudentScreen extends StatefulWidget {
  final SchoolYear schoolyear;
  final Section section;

  const ManageStudentScreen({
    super.key,
    required this.section,
    required this.schoolyear,
  });

  @override
  State<ManageStudentScreen> createState() => _ManageStudentScreenState();
}

class _ManageStudentScreenState extends State<ManageStudentScreen> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Student> _students = []; // ✅ Correct model
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents(); // ✅ Method name fixed
  }

  Future<void> _fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students') // ✅ Fetch from students collection
          .where('sectionid', isEqualTo: widget.section.id)
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .get();

      setState(() {
        _students = snapshot.docs
            .map((doc) => Student.fromMap(doc.id, doc.data()))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load students")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "School Year: ${widget.schoolyear.schoolyearstart} - ${widget.schoolyear.schoolyearend} • Section: ${widget.section.sectionname}",
        ),
        elevation: 0,
        actions: [
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 12.0),
          //   child: ElevatedButton.icon(
          //     icon: const Icon(Icons.upload, size: 20),
          //     label: const Text('Import Student'),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: AppTheme.primaryColor,
          //       foregroundColor: Colors.white,
          //       textStyle: const TextStyle(
          //         fontSize: 16,
          //         fontWeight: FontWeight.bold,
          //       ),
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 16,
          //         vertical: 8,
          //       ),
          //       elevation: 0,
          //     ),
          //     onPressed: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder: (context) => importstudentscreen(
          //             section: widget.section,
          //             schoolyear: widget.schoolyear,
          //             student: null,
          //           ),
          //         ),
          //       );
          //     },
          //   ),
          // ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text('Add Student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddStudentScreen(
                      section: widget.section,
                      schoolyear: widget.schoolyear,
                      student: null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('sectionid', isEqualTo: widget.section.id)
            .where('schoolyearid', isEqualTo: widget.schoolyear.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    size: 64,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No Students Found in this Section",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddStudentScreen(
                            section: widget.section,
                            schoolyear: widget.schoolyear,
                            student: null,
                          ),
                        ),
                      );
                    },
                    child: const Text("Add Student"),
                  ),
                ],
              ),
            );
          }

          final students = snapshot.data!.docs
              .map(
                (doc) =>
                    Student.fromMap(doc.id, doc.data() as Map<String, dynamic>),
              )
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentProfileScreen(
                          student: student,
                          section: widget.section,
                          schoolyear: widget.schoolyear,
                        ),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      student.gender == "Male" ? Icons.man : Icons.woman,
                      color: student.gender == "Female"
                          ? Colors.pinkAccent
                          : AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    "${student.firstname} ${student.middlename} ${student.lastname}",
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("LRN: ${student.lrn}"),
                      Text("Gender: ${student.gender}"),
                      Text("Status: ${student.status}"),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "edit",
                        child: ListTile(
                          leading: Icon(
                            Icons.edit,
                            color: AppTheme.primaryColor,
                          ),
                          title: Text("Edit"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        // 👇 dynamic value & label depending on teacher.status
                        value: student.status == "ACTIVE"
                            ? "INACTIVE"
                            : "ACTIVE",
                        child: ListTile(
                          leading: Icon(
                            student.status == "ACTIVE"
                                ? Icons.disabled_by_default
                                : Icons.check_circle,
                            color: student.status == "ACTIVE"
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                          title: Text(
                            student.status == "ACTIVE"
                                ? "Set Inactive"
                                : "Set Active",
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == "edit") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddStudentScreen(
                              section: widget.section,
                              schoolyear: widget.schoolyear,
                              student: student,
                            ),
                          ),
                        );
                      } else if (value == "INACTIVE" || value == "ACTIVE") {
                        firestore.collection("students").doc(student.id).update(
                          {"status": value},
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
