import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/teacher/assessments/viewassessment.dart';
import 'package:ireader_web/views/teacher/practice_set/select_practice_set.dart';
import 'package:ireader_web/views/teacher/students/manage_student.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row;
import 'package:universal_html/html.dart' show AnchorElement;
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' show AnchorElement;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io';

class TeacherManageSection extends StatefulWidget {
  final Teacher teacher;
  final SchoolYear schoolyear;

  const TeacherManageSection({
    super.key,
    required this.teacher,
    required this.schoolyear,
  });

  @override
  State<TeacherManageSection> createState() => _TeacherManageSectionState();
}

class _TeacherManageSectionState extends State<TeacherManageSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> studentreads = ["Overall Result", "Comprehension Result"];
  String _selectedReadType = "Overall Result";

  // String generateReadingInsight(Map<String, int> counts) {
  //   final frustration = counts['Frustration'] ?? 0;
  //   final instructional = counts['Instructional'] ?? 0;
  //   final independent = counts['Independent'] ?? 0;

  //   final total = frustration + instructional + independent;

  //   if (total == 0) {
  //     return "No reading data available for this section.";
  //   }

  //   if (independent >= instructional && independent >= frustration) {
  //     return "Most students are classified under the Independent level. "
  //         "This indicates a high average reading performance, and the majority "
  //         "of learners can read and comprehend words independently.";
  //   }

  //   if (instructional >= independent && instructional >= frustration) {
  //     return "Most students are at the Instructional level. "
  //         "This suggests that reading performance remains stable, and learners "
  //         "benefit from guided reading support to improve further.";
  //   }

  //   return "Most students fall under the Frustration level. "
  //       "This indicates a low average reading performance and highlights the "
  //       "need for targeted reading interventions and support.";
  // }

  String generateReadingInsight(Map<String, int> counts) {
    final frustration = counts['Frustration'] ?? 0;
    final instructional = counts['Instructional'] ?? 0;
    final independent = counts['Independent'] ?? 0;

    final total = frustration + instructional + independent;

    if (total == 0) {
      return "No reading data available for this school year.";
    }

    // ✅ STEP 1: Compute weighted average
    final totalScore =
        (frustration * 1) + (instructional * 2) + (independent * 3);

    final averageScore = totalScore / total;

    // ✅ STEP 2: Convert to percentage (out of 3 → 100%)
    final percentage = (averageScore / 3) * 100;
    final percentFormatted = percentage.toStringAsFixed(1);

    // ✅ STEP 3: Your existing insight logic
    String insight;

    if (independent >= instructional && independent >= frustration) {
      insight =
          "Most students are classified under the Independent level. "
          "This indicates a high average ${_selectedReadType} performance with a percentage of $percentFormatted%, and the majority "
          "of learners can read and comprehend words independently.";
    } else if (instructional >= independent && instructional >= frustration) {
      insight =
          "Most students are at the Instructional level. "
          "This suggests that ${_selectedReadType} performance remains stable with a percentage of $percentFormatted%, and learners "
          "benefit from guided reading support to improve further.";
    } else {
      insight =
          "Most students fall under the Frustration level. "
          "This indicates a low average ${_selectedReadType} performance with a percentage of $percentFormatted% and highlights the "
          "need for targeted reading interventions and support.";
    }

    // ✅ STEP 4: Append percentage
    return insight;
  }

  // ✅ Fetch counts of reading levels per section
  Stream<Map<String, int>> _fetchStudentReadLevels(
    String sectionid,
    String schoolyearid,
  ) {
    return _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearid)
        .where('sectionid', isEqualTo: sectionid)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
          int frustration = 0;
          int instructional = 0;
          int independent = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            String level = '';

            if (_selectedReadType == "Overall Result") {
              level = data['readlevel'] ?? '';
            } else {
              level = data['comprehensionresult'] ?? '';
            }
            // final level = doc.data()['readlevel'] ?? '';

            if (level == 'Frustration') {
              frustration++;
            } else if (level == 'Instructional') {
              instructional++;
            } else if (level == 'Independent') {
              independent++;
            }
          }

          return {
            'Frustration': frustration,
            'Instructional': instructional,
            'Independent': independent,
          };
        });
  }

  Stream<Map<String, int>> fetchStudentReadLevelsStream(
    String sectionid,
    String schoolyearid,
  ) {
    return _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearid)
        .where('sectionid', isEqualTo: sectionid)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
          int frustration = 0;
          int instructional = 0;
          int independent = 0;

          for (var doc in snapshot.docs) {
            // final data = doc.data();
            // final level = data['readlevel'] ?? '';
            final data = doc.data();
            String level = '';

            if (_selectedReadType == "Overall Result") {
              level = data['readlevel'] ?? '';
            } else {
              level = data['comprehensionresult'] ?? '';
            }
            if (level == 'Frustration') {
              frustration++;
            } else if (level == 'Instructional') {
              instructional++;
            } else if (level == 'Independent') {
              independent++;
            }
          }

          return {
            'Frustration': frustration,
            'Instructional': instructional,
            'Independent': independent,
            'Total': snapshot.docs.length,
          };
        });
  }

  // ✅ Generate chart per section
  String generateChartUrlFromCounts(Map<String, int> counts) {
    final chartConfig = {
      "type": "pie",
      "data": {
        "labels": ["Frustration", "Instructional", "Independent"],
        "datasets": [
          {
            "data": [
              counts['Frustration'] ?? 0,
              counts['Instructional'] ?? 0,
              counts['Independent'] ?? 0,
            ],
            "backgroundColor": ["#FF8C00", "#FFD580", "#90EE90"],
          },
        ],
      },
      "options": {
        "responsive": true,
        "maintainAspectRatio": false,
        "layout": {"padding": 20},
        "plugins": {
          "legend": {
            "position": "right",
            "labels": {
              "font": {
                "size": 20, // 🔥 Bigger legend text
              },
            },
          },
          "title": {
            "display": true,
            "text": "Reading Levels",
            "font": {
              "size": 26, // 🔥 Bigger title
            },
          },
          "datalabels": {
            "color": "#000",
            "font": {
              "size": 20, // 🔥 Bigger slice labels
              "weight": "bold",
            },
          },
        },
      },
      "plugins": ["chartjs-plugin-datalabels"],
    };

    final encodedConfig = Uri.encodeComponent(jsonEncode(chartConfig));

    return 'https://quickchart.io/chart?c=$encodedConfig&width=500&height=450';
  }

  Future<void> exportSectionStudents(Section section) async {
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

    // Fetch teacher
    final teacherSnap = await _firestore
        .collection('teachers')
        .doc(section.teacherid)
        .get();
    final teacherName = teacherSnap.exists
        ? "${teacherSnap['firstname']} ${teacherSnap['middlename']} ${teacherSnap['lastname']}"
        : 'Unknown';

    // ==== HEADER 3: TEACHER LINE ====
    sheet
        .getRangeByName(
          'A3:$lastCol'
          '3',
        )
        .merge();
    sheet.getRangeByName('A3').setText('Teacher: $teacherName');
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
    final snapshot = await _firestore
        .collection('students')
        .where('sectionid', isEqualTo: section.id)
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

    if (kIsWeb) {
      AnchorElement(
          href: 'data:application/octet-stream;base64,${base64.encode(bytes)}',
        )
        ..setAttribute(
          'download',
          'Phil-IRI_Student_List(Stage_2)_${section.sectionname}.xlsx',
        )
        ..click();
    } else {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final filePath =
          '$directory/Phil-IRI_Student_List(Stage_2)_${section.sectionname}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      OpenFile.open(filePath);
    }
  }

  Widget _viewStudentsButton(Section section) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.people),
      label: const Text('View Students'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      onPressed: () async {
        // 🔥 Get correct schoolyear from section
        final schoolYearDoc = await _firestore
            .collection("schoolyears")
            .doc(section.schoolyearid)
            .get();

        if (!schoolYearDoc.exists) return;

        final correctSchoolYear = SchoolYear.fromMap(
          schoolYearDoc.id,
          schoolYearDoc.data() as Map<String, dynamic>,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherManageStudentScreen(
              section: section,
              schoolyear: correctSchoolYear, // ✅ CORRECT YEAR
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: studentreads.map((type) {
          final isSelected = _selectedReadType == type;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedReadType = type;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _viewAssessmentButton(Section section) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.assignment),
      label: const Text('View Assessments'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      onPressed: () async {
        // 🔥 Get correct schoolyear from section
        final schoolYearDoc = await _firestore
            .collection("schoolyears")
            .doc(section.schoolyearid)
            .get();

        if (!schoolYearDoc.exists) return;

        final correctSchoolYear = SchoolYear.fromMap(
          schoolYearDoc.id,
          schoolYearDoc.data() as Map<String, dynamic>,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewAssessment(
              schoolyear: correctSchoolYear, // ✅ CORRECT YEAR
            ),
          ),
        );
      },
    );
  }

  Widget _viewpracticeset(Section section) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.menu_book),
      label: const Text('View Practice Sets'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      onPressed: () async {
        final schoolYearDoc = await _firestore
            .collection("schoolyears")
            .doc(section.schoolyearid)
            .get();

        if (!schoolYearDoc.exists) return;

        final schoolyear = SchoolYear.fromMap(
          schoolYearDoc.id,
          schoolYearDoc.data() as Map<String, dynamic>,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectPracticeSetScreen(
              section: section,
              schoolyear: widget.schoolyear,
            ),
          ),
        );
      },
    );
  }

  Widget _exportButton(Section section) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.file_download),
      label: const Text('Export Students'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      onPressed: () => exportSectionStudents(section),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          "Assigned Sections",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobileS = screenWidth <= 320;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobileS
                    // 🔥 ICON ONLY (Mobile S 320px)
                    ? IconButton(
                        icon: const Icon(Icons.logout),
                        color: Colors.redAccent,
                        tooltip: "Log Out",
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();

                          html.window.history.pushState(null, '', '');
                          html.window.onPopState.listen((event) {
                            html.window.history.pushState(null, '', '');
                          });

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => LoginScreen()),
                            (Route<dynamic> route) => false,
                          );
                        },
                      )
                    // 🔥 ICON + LABEL (Tablet/Desktop)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text('Log Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();

                          html.window.history.pushState(null, '', '');
                          html.window.onPopState.listen((event) {
                            html.window.history.pushState(null, '', '');
                          });

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => LoginScreen()),
                            (Route<dynamic> route) => false,
                          );
                        },
                      ),
              );
            },
          ),
        ],

        elevation: 0,
      ),

      // ✅ Display sections
      body: Column(
        children: [
          const SizedBox(height: 12),

          /// ✅ GLOBAL RESULT FILTER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildResultToggle(),
          ),

          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('sections')
                  .where('teacherid', isEqualTo: widget.teacher.id)
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
                  return const Center(
                    child: Text("No Sections Found for this School Year."),
                  );
                }

                final sections = snapshot.data!.docs
                    .map(
                      (doc) => Section.fromMap(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    int crossAxisCount;

                    if (width <= 480) {
                      crossAxisCount = 1;
                    } else if (width <= 900) {
                      crossAxisCount = 2;
                    } else {
                      crossAxisCount = 3;
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 580,
                      ),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔹 Section Name
                                Center(
                                  child: Text(
                                    section.sectionname,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // 🔹 School Year
                                FutureBuilder<DocumentSnapshot>(
                                  future: _firestore
                                      .collection("schoolyears")
                                      .doc(section.schoolyearid)
                                      .get(),
                                  builder: (context, sySnap) {
                                    if (!sySnap.hasData) {
                                      return const Text(
                                        "Loading school year...",
                                      );
                                    }

                                    if (!sySnap.data!.exists) {
                                      return const Text(
                                        "School year not found",
                                      );
                                    }

                                    final sy = sySnap.data!;

                                    return Center(
                                      child: Text(
                                        "SY: ${sy['schoolyearstart']} - ${sy['schoolyearend']}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // 🔹 Teacher
                                FutureBuilder<DocumentSnapshot>(
                                  future: _firestore
                                      .collection("teachers")
                                      .doc(section.teacherid)
                                      .get(),
                                  builder: (context, snap) {
                                    if (!snap.hasData) {
                                      return const Text("Loading teacher...");
                                    }
                                    final t = snap.data!;
                                    return Center(
                                      child: Text(
                                        "Teacher: ${t['firstname']} ${t['lastname']}",
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 6),

                                // 🔹 Student Count
                                // 🔹 Student Count + Chart
                                StreamBuilder<Map<String, int>>(
                                  stream: fetchStudentReadLevelsStream(
                                    section.id,
                                    section.schoolyearid,
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (!snapshot.hasData) {
                                      return const Center(
                                        child: Text("No students yet"),
                                      );
                                    }

                                    final counts = snapshot.data!;
                                    final chartUrl = generateChartUrlFromCounts(
                                      counts,
                                    );

                                    return Column(
                                      children: [
                                        // Total students
                                        Text(
                                          "Total Students: ${counts['Total']}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Chart with fixed height
                                        SizedBox(
                                          height: 250,
                                          child: StreamBuilder<Map<String, int>>(
                                            stream: _fetchStudentReadLevels(
                                              section.id,
                                              section.schoolyearid,
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              } else if (snapshot.hasError) {
                                                return const Center(
                                                  child: Text(
                                                    "Failed to load chart",
                                                  ),
                                                );
                                              } else if (!snapshot.hasData) {
                                                return const Center(
                                                  child: Text(
                                                    "No chart data available",
                                                  ),
                                                );
                                              }

                                              final counts = snapshot.data!;

                                              final chartConfig = {
                                                "type": "pie",
                                                "data": {
                                                  "labels": [
                                                    "Frustration",
                                                    "Instructional",
                                                    "Independent",
                                                  ],
                                                  "datasets": [
                                                    {
                                                      "data": [
                                                        counts['Frustration'],
                                                        counts['Instructional'],
                                                        counts['Independent'],
                                                      ],
                                                      "backgroundColor": [
                                                        "rgb(255,140,0)",
                                                        "rgb(255,215,128)",
                                                        "rgb(144,238,144)",
                                                      ],
                                                    },
                                                  ],
                                                },
                                                "options": {
                                                  "plugins": {
                                                    "legend": {
                                                      "position": "bottom",
                                                    },
                                                  },
                                                },
                                              };

                                              final encodedConfig =
                                                  Uri.encodeComponent(
                                                    jsonEncode(chartConfig),
                                                  );

                                              final chartUrl =
                                                  'https://quickchart.io/chart?width=500&height=300&devicePixelRatio=2&c=$encodedConfig';

                                              final insight =
                                                  "${_selectedReadType}: ${generateReadingInsight(counts)}";

                                              // final insight =
                                              //     generateReadingInsight(
                                              //       counts,
                                              //     );
                                              return Column(
                                                children: [
                                                  Expanded(
                                                    child: Center(
                                                      child: PointerInterceptor(
                                                        child: Image.network(
                                                          chartUrl,
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.contain,
                                                          loadingBuilder:
                                                              (
                                                                context,
                                                                child,
                                                                loadingProgress,
                                                              ) {
                                                                if (loadingProgress ==
                                                                    null)
                                                                  return child;
                                                                return const Center(
                                                                  child:
                                                                      CircularProgressIndicator(),
                                                                );
                                                              },
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) {
                                                                return const Center(
                                                                  child: Text(
                                                                    'Failed to load chart image',
                                                                  ),
                                                                );
                                                              },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  AutoSizeText(
                                                    insight,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                                const SizedBox(height: 8),

                                // 🔹 Button
                                Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: _viewStudentsButton(section),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _viewpracticeset(section),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _viewAssessmentButton(section),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _exportButton(section),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
