import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentoverallresult.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/admin/assessments/manage_assessment.dart';
import 'package:ireader_web/views/admin/practice_set/select_practice_set.dart';
import 'package:ireader_web/views/admin/readingcoordinator/manage_rc.dart';
import 'package:ireader_web/views/admin/schoolyear/add_schoolyear_dialog.dart';
import 'package:ireader_web/views/admin/section/manage_section.dart';
import 'package:ireader_web/views/admin/schoolyear/add_schoolyear.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' show AnchorElement;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io';

class ManageSchoolyearScreen extends StatefulWidget {
  const ManageSchoolyearScreen({super.key});

  @override
  State<ManageSchoolyearScreen> createState() => _ManageSchoolyearScreenState();
}

class _ManageSchoolyearScreenState extends State<ManageSchoolyearScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedbox = 0;
  SchoolYear? _startYear;
  SchoolYear? _endYear;
  String? _startYearId;
  String? _endYearId;
  final List<String> studentreads = ["Overall Result", "Comprehension Result"];
  String _selectedReadType = "Overall Result";

  bool _loadingAnalysis = false;

  /// yearId -> counts
  Map<String, Map<String, int>> _rangeCounts = {};
  List<SchoolYear> _selectedRangeYears = [];

  // String generateReadingInsight(Map<String, int> counts) {
  //   final frustration = counts['Frustration'] ?? 0;
  //   final instructional = counts['Instructional'] ?? 0;
  //   final independent = counts['Independent'] ?? 0;

  //   final total = frustration + instructional + independent;

  //   if (total == 0) {
  //     return "No reading data available for this school year.";
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

  Future<Map<String, int>> _computeCounts(String schoolyearId) async {
    final snap = await _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearId)
        .where('status', isEqualTo: 'ACTIVE')
        .get();

    int frustration = 0;
    int instructional = 0;
    int independent = 0;

    for (final doc in snap.docs) {
      String level = '';

      if (_selectedReadType == "Overall Result") {
        level = (doc.data()['readlevel'] ?? '') as String;
      } else {
        level = (doc.data()['comprehensionresult'] ?? '') as String;
      }

      // final level = (doc.data()['readlevel'] ?? '') as String;
      if (level == 'Frustration') frustration++;
      if (level == 'Instructional') instructional++;
      if (level == 'Independent') independent++;
    }

    return {
      'Frustration': frustration,
      'Instructional': instructional,
      'Independent': independent,
    };
  }

  String _buildMultiYearChartUrl() {
    final labels = ['Frustration', 'Instructional', 'Independent'];
    final datasets = <Map<String, dynamic>>[];

    for (final y in _selectedRangeYears) {
      final counts = _rangeCounts[y.id] ?? {};
      datasets.add({
        'label': '${y.schoolyearstart}-${y.schoolyearend}',
        'data': labels.map((l) => counts[l] ?? 0).toList(),
      });
    }

    final chart = {
      'type': 'bar',
      'data': {'labels': labels, 'datasets': datasets},
    };

    return 'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chart))}&width=900&height=400';
  }

  Future<void> _analyzeRange(List<SchoolYear> years) async {
    _rangeCounts.clear();
    for (final y in years) {
      _rangeCounts[y.id] = await _computeCounts(y.id);
    }
    _selectedRangeYears = years;
  }

  /// Fetches student counts per reading level for a specific school year
  Stream<Map<String, int>> _fetchStudentReadLevels(String schoolyearid) {
    return _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearid)
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
            // final level = data['readlevel'] ?? '';

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

  /// Fetches all school years from Firestore
  Stream<List<SchoolYear>> _fetchSchoolYears() {
    return _firestore
        .collection('schoolyears')
        .orderBy('schoolyearstart', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SchoolYear.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Widget _buildWinnersWidget() {
    final labels = ['Frustration', 'Instructional', 'Independent'];

    List<Widget> rows = [];

    for (final level in labels) {
      int max = 0;
      SchoolYear? winner;

      for (final y in _selectedRangeYears) {
        final value = _rangeCounts[y.id]?[level] ?? 0;

        if (value > max) {
          max = value;
          winner = y;
        }
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '$level → Most students in '
            '${winner?.schoolyearstart}-${winner?.schoolyearend} ($max)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildResultDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedReadType,
      decoration: const InputDecoration(
        labelText: "Result Type",
        border: OutlineInputBorder(),
      ),
      items: studentreads
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedReadType = value!;
        });
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

  Future<void> exportschoolyeardata(String schoolYearId) async {
    final workbook = Workbook();
    const subject = "English";

    final schoolyear = await _firestore
        .collection('schoolyears')
        .doc(schoolYearId)
        .get();

    final sections = await _firestore
        .collection('sections')
        .where('schoolyearid', isEqualTo: schoolYearId)
        .get();

    // =========================================================
    // HEADER BUILDER
    // =========================================================
    void buildHeaders(Worksheet sheet, String stageTitle) {
      sheet.getRangeByName('A1:M1').merge();
      sheet
          .getRangeByName('A1')
          .setText(
            'Phil IRI: School Year ${schoolyear['schoolyearstart']} - ${schoolyear['schoolyearend']} Report',
          );

      sheet.getRangeByName('A2:M2').merge();
      sheet.getRangeByName('A2').setText(subject);

      sheet.getRangeByName('A3:M3').merge();
      sheet.getRangeByName('A3').setText('Grade 4');

      sheet.getRangeByName('A4:M4').merge();
      sheet.getRangeByName('A4').setText(stageTitle);

      for (int r = 1; r <= 4; r++) {
        sheet.getRangeByIndex(r, 1, r, 13).cellStyle
          ..hAlign = HAlignType.center
          ..bold = true;
      }

      sheet.getRangeByName('E5:G5').merge();
      sheet.getRangeByName('E5').setText('FRUSTRATION');

      sheet.getRangeByName('H5:J5').merge();
      sheet.getRangeByName('H5').setText('INSTRUCTIONAL');

      sheet.getRangeByName('K5:M5').merge();
      sheet.getRangeByName('K5').setText('INDEPENDENT');

      sheet.getRangeByName('A6:B6').merge();
      sheet.getRangeByName('A6').setText('SECTIONS');

      sheet.getRangeByName('C6:D6').merge();
      sheet.getRangeByName('C6').setText('TEACHERS');

      const labels = ['MALE', 'FEMALE', 'TOTAL'];
      for (int i = 0; i < 3; i++) {
        sheet.getRangeByIndex(6, 5 + i).setText(labels[i]);
        sheet.getRangeByIndex(6, 8 + i).setText(labels[i]);
        sheet.getRangeByIndex(6, 11 + i).setText(labels[i]);
      }
    }

    // =========================================================
    // ⭐⭐⭐ FIXED COUNT FUNCTION (REAL SOLUTION)
    // =========================================================
    Future<Map<String, int>> countSectionResults({
      required String sectionId,
      required String assessmentId,
    }) async {
      // 1️⃣ Get students of this section
      final studentsSnap = await _firestore
          .collection('students')
          .where('sectionid', isEqualTo: sectionId)
          .get();

      final studentMap = <String, Student>{};

      for (final s in studentsSnap.docs) {
        final student = Student.fromMap(s.id, s.data());
        studentMap[student.id] = student;
      }

      if (studentMap.isEmpty) {
        return {
          'fm': 0,
          'ff': 0,
          'fa': 0,
          'im': 0,
          'iff': 0,
          'ia': 0,
          'im2': 0,
          'iff2': 0,
          'ia2': 0,
        };
      }

      // 2️⃣ Get overall results for assessment
      final resultSnap = await _firestore
          .collection('overallresult')
          .where('assessmentid', isEqualTo: assessmentId)
          .get();

      int fm = 0, ff = 0, fa = 0;
      int im = 0, iff = 0, ia = 0;
      int im2 = 0, iff2 = 0, ia2 = 0;

      // 3️⃣ Match using studentid
      for (final r in resultSnap.docs) {
        final result = studentoverallresult.fromMap(r.id, r.data());

        final student = studentMap[result.studentid];
        if (student == null) continue;

        final gender = student.gender;
        final level = result.readlevel;

        if (level == 'Frustration') {
          fa++;
          if (gender == 'Male') fm++;
          if (gender == 'Female') ff++;
        }

        if (level == 'Instructional') {
          ia++;
          if (gender == 'Male') im++;
          if (gender == 'Female') iff++;
        }

        if (level == 'Independent') {
          ia2++;
          if (gender == 'Male') im2++;
          if (gender == 'Female') iff2++;
        }
      }

      return {
        'fm': fm,
        'ff': ff,
        'fa': fa,
        'im': im,
        'iff': iff,
        'ia': ia,
        'im2': im2,
        'iff2': iff2,
        'ia2': ia2,
      };
    }

    // =========================================================
    // SHEET BUILDER
    // =========================================================
    Future<void> buildSheet({
      required Worksheet sheet,
      required String title,
      required String assessmentTitle,
      // required String schoolYearId,
    }) async {
      sheet.name = title;

      final snap = await _firestore
          .collection('assessment')
          .where('assessmenttitle', isEqualTo: assessmentTitle)
          .where('schoolyearid', isEqualTo: schoolYearId)
          .limit(1)
          .get();

      // if (snap.docs.isEmpty) {
      //   return;
      // }

      final assessmentId = snap.docs.first.id;

      buildHeaders(sheet, title);

      int row = 7;

      for (final sec in sections.docs) {
        final teacherSnap = await _firestore
            .collection('teachers')
            .doc(sec['teacherid'])
            .get();

        final counts = await countSectionResults(
          sectionId: sec.id,
          assessmentId: assessmentId,
        );

        sheet.getRangeByName('A$row').setText(sec['sectionname']);
        sheet.getRangeByName('C$row').setText(teacherSnap['lastname']);

        final values = [
          counts['fm'],
          counts['ff'],
          counts['fa'],
          counts['im'],
          counts['iff'],
          counts['ia'],
          counts['im2'],
          counts['iff2'],
          counts['ia2'],
        ];

        for (int i = 0; i < values.length; i++) {
          sheet.getRangeByIndex(row, 5 + i).setNumber(values[i]!.toDouble());
        }

        row++;
      }
    }

    // =========================================================
    // BUILD ALL
    // =========================================================
    await buildSheet(
      sheet: workbook.worksheets[0],
      title: 'Pre-Test',
      assessmentTitle: 'Stage 2 - Pre-Test',
      // schoolYearId: schoolYearId,
    );

    await buildSheet(
      sheet: workbook.worksheets.add(),
      title: 'Midway Test',
      assessmentTitle: 'Stage 3 - Midway/Mid-test',
      // schoolYearId: schoolYearId,
    );

    await buildSheet(
      sheet: workbook.worksheets.add(),
      title: 'Post-Test',
      assessmentTitle: 'Stage 4 - Post-Test',
      // schoolYearId: schoolYearId,
    );

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    if (kIsWeb) {
      AnchorElement(
          href:
              'data:application/octet-stream;charset=utf-16le;base64,${base64.encode(bytes)}',
        )
        ..setAttribute(
          'download',
          'School Year ${schoolyear['schoolyearstart']} - ${schoolyear['schoolyearend']} Result.xlsx',
        )
        ..click();
    } else {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final filePath =
          '$directory/School Year ${schoolyear['schoolyearstart']} - ${schoolyear['schoolyearend']} Result.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      OpenFile.open(filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Up"),
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobileS = screenWidth <= 768;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobileS
                    // 🔥 ICON ONLY (Mobile S 320px)
                    ? IconButton(
                        icon: const Icon(Icons.add),
                        color: AppTheme.primaryColor,
                        tooltip: "Add School Year",
                        onPressed: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddSchoolyearScreen(schoolyear: null),
                            ),
                          );
                        },
                      )
                    // 🔥 ICON + LABEL (Tablet/Desktop)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add School Year'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          AddSchoolyearDialog.show(context, schoolyear: null);
                        },
                      ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.backgroundColor),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Image.asset(
                      'assets/images/Department-of-Education-DepEd-Seal-300x300.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'iReader',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboard(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.primaryColor,
              ),
              title: const Text(
                'Set Up',
                style: TextStyle(fontSize: 20, color: AppTheme.primaryColor),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageSchoolyearScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageAdminScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.integration_instructions,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Reading Coordinators',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageRcScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Teachers',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageTeacherScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Log Out',
                style: TextStyle(fontSize: 20, color: Colors.redAccent),
              ),
              onTap: () async {
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
          ],
        ),
      ),
      body: StreamBuilder<List<SchoolYear>>(
        stream: _fetchSchoolYears(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No School Year Found"));
          }

          final schoolYears = snapshot.data!;
          final screenWidth = MediaQuery.of(context).size.width;

          return Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildResultToggle(),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: screenWidth <= 600 ? 600 : 500,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: screenWidth <= 360
                        ? 520 // slightly taller for 320px devices
                        : screenWidth <= 600
                        ? 540
                        : 560,
                  ),
                  itemCount: schoolYears.length,
                  itemBuilder: (context, index) {
                    final schoolyear = schoolYears[index];

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// TITLE
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "School Year: ${schoolyear.schoolyearstart} - ${schoolyear.schoolyearend}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            /// RESPONSIVE CHART
                            SizedBox(
                              height: screenWidth <= 360
                                  ? 200
                                  : screenWidth <= 600
                                  ? 230
                                  : 300,
                              child: StreamBuilder<Map<String, int>>(
                                stream: _fetchStudentReadLevels(schoolyear.id),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  } else if (snapshot.hasError) {
                                    return const Center(
                                      child: Text("Failed to load chart"),
                                    );
                                  } else if (!snapshot.hasData) {
                                    return const Center(
                                      child: Text("No chart data available"),
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
                                        "legend": {"position": "bottom"},
                                      },
                                    },
                                  };

                                  final encodedConfig = Uri.encodeComponent(
                                    jsonEncode(chartConfig),
                                  );

                                  final chartUrl =
                                      'https://quickchart.io/chart?width=500&height=300&devicePixelRatio=2&c=$encodedConfig';

                                  // final insight = generateReadingInsight(counts);
                                  final insight =
                                      "${_selectedReadType}: ${generateReadingInsight(counts)}";

                                  return Column(
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: PointerInterceptor(
                                            child: Image.network(
                                              chartUrl,
                                              width: double.infinity,
                                              fit: BoxFit.contain,
                                              loadingBuilder:
                                                  (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    );
                                                  },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
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
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 10),

                            /// FULL WIDTH BUTTONS (STACKED LIKE RC)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.class_),
                                    label: const Text("Sections"),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ManageSection(
                                            schoolyear: schoolyear,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.edit_calendar),
                                    label: const Text("Edit School Year"),
                                    onPressed: () {
                                      final width = MediaQuery.of(
                                        context,
                                      ).size.width;

                                      if (width <= 768) {
                                        // 📱 Small screen → full screen route
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddSchoolyearScreen(
                                                  schoolyear: schoolyear,
                                                ),
                                          ),
                                        );
                                      } else {
                                        // 🖥️ Larger screen → dialog
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) =>
                                              AddSchoolyearDialog(
                                                schoolyear: schoolyear,
                                              ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.assignment),
                                    label: const Text("Assessments"),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ManageAssessment(
                                                schoolyear: schoolyear,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.download),
                                    label: const Text("Export Result"),
                                    onPressed: () async {
                                      try {
                                        await exportschoolyeardata(
                                          schoolyear.id,
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text("Export failed: $e"),
                                          ),
                                        );
                                      }
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
