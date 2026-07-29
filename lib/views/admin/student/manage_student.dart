import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/student/add_student.dart';
import 'package:ireader_web/views/admin/student/add_student_dialog.dart';
import 'package:ireader_web/views/admin/student/student_profile.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row;
import 'package:universal_html/html.dart' show AnchorElement;
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

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
  String? _teacherName;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    sectionteacher(); // ✅ Method name fixed
  }

  Future<void> sectionteacher() async {
    final teacherSnapshot = await firestore
        .collection('teachers')
        .doc(widget.section.teacherid)
        .get();
    if (teacherSnapshot.exists) {
      final teacherData = teacherSnapshot.data()!;
      final teacherName =
          "${teacherData['firstname']} ${teacherData['middlename']} ${teacherData['lastname']}";
      setState(() {
        _teacherName = teacherName;
      });
    }
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

  Future<void> exportStudents() async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    // Define last column (A=1, B=2, C=3, D=4 → so D is column 4)
    const String lastCol = 'D';
    const String lastcolgender = 'C';
    const String lastcolgstscore = 'D';

    // ==== HEADER 1: TITLE ====
    sheet
        .getRangeByName(
          'A1:$lastCol'
          '1',
        )
        .merge();
    sheet.getRangeByName('A1').setText('STAGE 2 ADMISSION IN PHIL-IRI');
    sheet.getRangeByName('A1').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center
      ..bold = true;

    // ==== HEADER 2: SCHOOL YEAR ====
    sheet
        .getRangeByName(
          'A2:$lastCol'
          '2',
        )
        .merge();
    sheet
        .getRangeByName('A2')
        .setText(
          'School Year: ${widget.schoolyear.schoolyearstart} - ${widget.schoolyear.schoolyearend}',
        );
    sheet.getRangeByName('A2').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    // ==== HEADER 3: TEACHER LINE ====
    sheet
        .getRangeByName(
          'A3:$lastCol'
          '3',
        )
        .merge();
    sheet.getRangeByName('A3').setText('Teacher: ${_teacherName}');
    sheet.getRangeByName('A3').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    // ==== HEADER 4: DESCRIPTION LINE ====
    sheet
        .getRangeByName(
          'A4:$lastCol'
          '4',
        )
        .merge();
    sheet
        .getRangeByName('A4')
        .setText(
          'Students who will undergo Phil-IRI Oral Reading in English (Stage 2)',
        );
    sheet.getRangeByName('A4').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    // ==== COLUMN HEADERS ====
    sheet.getRangeByName('A5').setText('NAME');
    sheet
        .getRangeByName(
          'B5:$lastcolgender'
          '5',
        )
        .setText('GENDER');
    sheet
        .getRangeByName(
          'C5:$lastcolgstscore'
          '5',
        )
        .setText('SCORE');
    sheet.getRangeByName('D5').setText('START LEVEL OF GRADE PASSAGE');
    sheet
        .getRangeByName(
          'A5:$lastCol'
          '5',
        )
        .cellStyle
      ..bold = true;

    // ==== STUDENT DATA ====
    int rowIndex = 6;
    // Always fetch all students for the current section and school year
    final snapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('sectionid', isEqualTo: widget.section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .get();

    final students = snapshot.docs
        .map((doc) => Student.fromMap(doc.id, doc.data()))
        .toList();

    students.sort(
      (a, b) => a.lastname.toLowerCase().compareTo(b.lastname.toLowerCase()),
    );

    for (var student in students) {
      sheet
          .getRangeByName('A$rowIndex')
          .setText(
            "${student.lastname}, ${student.firstname} ${student.middlename != null && student.middlename!.isNotEmpty ? student.middlename! + " " : ""}",
          );
      sheet.getRangeByName('B$rowIndex').setText(student.gender);
      sheet.getRangeByName('C$rowIndex').setText(student.gstscore.toString());
      sheet
          .getRangeByName('D$rowIndex')
          .setText(student.gradelevelread.toString());
      rowIndex++;
    }

    // Auto-fit columns
    sheet.getRangeByName('A1:$lastCol$rowIndex').autoFitColumns();

    // ==== EXPORT FILE ====
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    AnchorElement(
        href: 'data:application/octet-stream;base64,${base64.encode(bytes)}',
      )
      ..setAttribute('download', 'Phil-IRI_Student_List(Stage_2).xlsx')
      ..click();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobile = screenWidth <= 768;

              void onPressed() {
                if (isMobile) {
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
                } else {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AddStudentDialog(
                      section: widget.section,
                      schoolyear: widget.schoolyear,
                      student: null,
                    ),
                  );
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobile
                    ? IconButton(
                        icon: const Icon(Icons.person_add_alt_1),
                        tooltip: 'Add Student',
                        onPressed: onPressed,
                      )
                    : ElevatedButton.icon(
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
                        onPressed: onPressed,
                      ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          /// 🔥 TITLE AT THE TOP
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AutoSizeText(
              "School Year: ${widget.schoolyear.schoolyearstart} - "
              "${widget.schoolyear.schoolyearend} • "
              "Section: ${widget.section.sectionname}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          /// 🔥 STUDENT LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .where('sectionid', isEqualTo: widget.section.id)
                  .where('schoolyearid', isEqualTo: widget.schoolyear.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
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
                      (doc) => Student.fromMap(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList();

                students.sort(
                  (a, b) => a.lastname.toLowerCase().compareTo(
                    b.lastname.toLowerCase(),
                  ),
                );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// ─── Header Row ─────────────────────────────────────
                            /// const SizedBox(height: 20),

                            // 🔥 TITLE
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    student.gender == "Male"
                                        ? Icons.male
                                        : Icons.female,
                                    color: student.gender == "Female"
                                        ? Colors.pinkAccent
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${student.firstname} ${student.middlename != null && student.middlename!.isNotEmpty ? student.middlename! + " " : ""} ${student.lastname}",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("LRN: ${student.lrn}"),
                                      Text("GST Score: ${student.gstscore}"),
                                      Text(
                                        "Grade Level: ${student.gradelevelread}",
                                      ),
                                      Text("Gender: ${student.gender}"),
                                      Text(
                                        "Status: ${student.status}",
                                        style: TextStyle(
                                          color: student.status == "ACTIVE"
                                              ? Colors.green
                                              : Colors.redAccent,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            /// ─── Action Buttons ─────────────────────────────────
                            Row(
                              children: [
                                /// Go to Profile Button (PRIMARY)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "Go to Student Profile",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StudentProfileScreen(
                                                student: student,
                                                section: widget.section,
                                                schoolyear: widget.schoolyear,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            /// Secondary Actions
                            Row(
                              children: [
                                /// Edit Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text("Edit"),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      final screenWidth = MediaQuery.of(
                                        context,
                                      ).size.width;

                                      if (screenWidth <= 768) {
                                        // Mobile/Tablet: Open full screen
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddStudentScreen(
                                                  section: widget.section,
                                                  schoolyear: widget.schoolyear,
                                                  student: student,
                                                ),
                                          ),
                                        );
                                      } else {
                                        // Desktop: Show dialog
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            child: SizedBox(
                                              width: 600,
                                              child: AddStudentDialog(
                                                section: widget.section,
                                                schoolyear: widget.schoolyear,
                                                student: student,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),

                                const SizedBox(width: 12),

                                /// Active / Inactive Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(
                                      student.status == "ACTIVE"
                                          ? Icons.disabled_by_default
                                          : Icons.check_circle,
                                      color: student.status == "ACTIVE"
                                          ? Colors.redAccent
                                          : Colors.green,
                                    ),
                                    label: Text(
                                      student.status == "ACTIVE"
                                          ? "Set Inactive"
                                          : "Set Active",
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      firestore
                                          .collection("students")
                                          .doc(student.id)
                                          .update({
                                            "status": student.status == "ACTIVE"
                                                ? "INACTIVE"
                                                : "ACTIVE",
                                          });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
