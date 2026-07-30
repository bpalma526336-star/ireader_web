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
import 'package:ireader_web/views/readingcoordinator/assessments/manage_assessment.dart';
import 'dart:html' as html;
import 'package:ireader_web/views/readingcoordinator/practice_set/select_practice_set.dart';
import 'package:ireader_web/views/readingcoordinator/rcdashboard.dart';
import 'package:ireader_web/views/readingcoordinator/sections/manage_section.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row;
import 'package:universal_html/html.dart' hide File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:open_file/open_file.dart';
import 'package:ireader_web/widgets/rc_sidebar.dart';

class RCManageSchoolyearScreen extends StatefulWidget {
  const RCManageSchoolyearScreen({super.key});

  @override
  State<RCManageSchoolyearScreen> createState() =>
      _RCManageSchoolyearScreenState();
}

class _RCManageSchoolyearScreenState extends State<RCManageSchoolyearScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> studentreads = ["Overall Result", "Comprehension Result"];
  String _selectedReadType = "Overall Result";

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
          "This indicates a high average $_selectedReadType performance with a percentage of $percentFormatted%, and the majority "
          "of learners can read and comprehend words independently.";
    } else if (instructional >= independent && instructional >= frustration) {
      insight =
          "Most students are at the Instructional level. "
          "This suggests that $_selectedReadType performance remains stable with a percentage of $percentFormatted%, and learners "
          "benefit from guided reading support to improve further.";
    } else {
      insight =
          "Most students fall under the Frustration level. "
          "This indicates a low average $_selectedReadType performance with a percentage of $percentFormatted% and highlights the "
          "need for targeted reading interventions and support.";
    }

    // ✅ STEP 4: Append percentage
    return insight;
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
    }) async {
      sheet.name = title;

      final snap = await _firestore
          .collection('assessment')
          .where('assessmenttitle', isEqualTo: assessmentTitle)
          .where('schoolyearid', isEqualTo: schoolYearId)
          .limit(1)
          .get();

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
    );

    await buildSheet(
      sheet: workbook.worksheets.add(),
      title: 'Midway Test',
      assessmentTitle: 'Stage 3 - Midway/Mid-test',
    );

    await buildSheet(
      sheet: workbook.worksheets.add(),
      title: 'Post-Test',
      assessmentTitle: 'Stage 4 - Post-Test',
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

  /// Fetches student counts per reading level for a specific school year
  Future<Map<String, int>> _fetchStudentReadLevels(String schoolyearid) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: schoolyearid)
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      int frustration = 0;
      int instructional = 0;
      int independent = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String level = '';

        if (_selectedReadType == "Overall Result") {
          level = (doc.data()['readlevel'] ?? '') as String;
        } else {
          level = (doc.data()['comprehensionresult'] ?? '') as String;
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load student read levels for school year: $e",
          ),
        ),
      );
      return {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
    }
  }

  /// Builds the QuickChart pie chart URL for a given school year
  Future<String> _generateChartUrl(
    String schoolyearid,
    double cardWidth,
  ) async {
    final counts = await _fetchStudentReadLevels(schoolyearid);

    // Safety clamp for very small screens (320px)
    final safeWidth = cardWidth.clamp(260, 600);

    final chartWidth = safeWidth.toInt();
    final chartHeight = (safeWidth * 0.75).toInt(); // balanced ratio

    bool isSmallMobile = safeWidth <= 320;
    bool isTablet = safeWidth > 320 && safeWidth <= 600;
    bool isDesktop = safeWidth > 600;

    int sliceFontSize = isSmallMobile
        ? 10
        : isTablet
        ? 14
        : 18;

    int legendFontSize = isSmallMobile
        ? 10
        : isTablet
        ? 12
        : 14;

    int titleFontSize = isSmallMobile
        ? 12
        : isTablet
        ? 14
        : 18;

    final chartConfig = {
      "type": "pie",
      "data": {
        "labels": ["Frustration", "Instructional", "Independent"],
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
        "layout": {"padding": 20},
        "plugins": {
          "title": {
            "display": true,
            "text": "Student Reading Levels",
            "font": {"size": titleFontSize},
          },
          "legend": {
            "position": "bottom",
            "labels": {
              "boxWidth": 15,
              "padding": 15,
              "font": {"size": legendFontSize},
            },
          },
          "datalabels": {
            "color": "#000",
            "anchor": "center",
            "align": "center",
            "font": {"size": sliceFontSize},
            "formatter": "@value", // cleaner inside slice
          },
        },
      },
      "plugins": ["chartjs-plugin-datalabels"],
    };

    final encodedConfig = Uri.encodeComponent(jsonEncode(chartConfig));
    return 'https://quickchart.io/chart?width=$chartWidth&height=$chartHeight&devicePixelRatio=2&c=$encodedConfig';
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text("School Years"),
        actions: [
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 12.0),
          //   child: ElevatedButton.icon(
          //     icon: const Icon(Icons.add, size: 20),
          //     label: const Text('Add School Year'),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: AppTheme.primaryColor,
          //       foregroundColor: Colors.white,
          //     ),
          //     onPressed: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder: (context) => AddSchoolyearScreen(schoolyear: null),
          //         ),
          //       );
          //     },
          //   ),
          // ),
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: RCSidebar(activeRoute: RCRoute.schoolYears)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const RCSidebar(activeRoute: RCRoute.schoolYears),
          Expanded(
            child: StreamBuilder<List<SchoolYear>>(
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
          return LayoutBuilder(
            builder: (context, cardConstraints) {
              final cardWidth = cardConstraints.maxWidth;

              // Make chart proportional to card width
              final chartHeight = cardWidth * 0.6;

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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: screenWidth <= 600
                            ? 1
                            : screenWidth <= 1100
                            ? 2
                            : 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: screenWidth <= 600 ? 0.68 : 0.75,
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
                                SizedBox(
                                  height: screenWidth <= 360
                                      ? 200
                                      : screenWidth <= 600
                                      ? 230
                                      : 300,

                                  child: FutureBuilder<Map<String, int>>(
                                    future: _fetchStudentReadLevels(
                                      schoolyear.id,
                                    ),
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
                                          child: Text(
                                            "No chart data available",
                                          ),
                                        );
                                      }

                                      final counts = snapshot.data!;
                                      // final insight = generateReadingInsight(
                                      //   counts,
                                      // );
                                      final insight =
                                          "$_selectedReadType: ${generateReadingInsight(counts)}";

                                      // Now generate chart using counts directly
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

                                      return Column(
                                        children: [
                                          Expanded(
                                            child: PointerInterceptor(
                                              child: Image.network(
                                                chartUrl,
                                                width: double.infinity,
                                                fit: BoxFit.contain,
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

                                Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  RCManageSection(
                                                    schoolyear: schoolyear,
                                                  ),
                                            ),
                                          );
                                        },
                                        label: const Text("View Sections"),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
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
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          exportschoolyeardata(schoolyear.id);
                                        },
                                        child: const Text("Export Result"),
                                      ),
                                    ),
                                  ],
                                ),
                                // Wrap(
                                //   spacing: 8,
                                //   runSpacing: 8,
                                //   alignment: WrapAlignment.spaceBetween,
                                //   children: [
                                //     ElevatedButton.icon(
                                //       style: ElevatedButton.styleFrom(
                                //         backgroundColor: AppTheme.primaryColor,
                                //         foregroundColor: Colors.white,
                                //       ),
                                //       onPressed: () {
                                //         Navigator.push(
                                //           context,
                                //           MaterialPageRoute(
                                //             builder: (context) => RCManageSection(
                                //               schoolyear: schoolyear,
                                //             ),
                                //           ),
                                //         );
                                //       },
                                //       label: const Text("View Sections"),
                                //     ),

                                //     ElevatedButton.icon(
                                //       style: ElevatedButton.styleFrom(
                                //         backgroundColor: AppTheme.primaryColor,
                                //         foregroundColor: Colors.white,
                                //       ),
                                //       icon: const Icon(Icons.assignment),
                                //       label: const Text("Assessments"),
                                //       onPressed: () {
                                //         Navigator.push(
                                //           context,
                                //           MaterialPageRoute(
                                //             builder: (context) => RCManageAssessment(
                                //               schoolyear: schoolyear,
                                //             ),
                                //           ),
                                //         );
                                //       },
                                //     ),

                                //     OutlinedButton(
                                //       style: OutlinedButton.styleFrom(
                                //         backgroundColor: AppTheme.primaryColor,
                                //         foregroundColor: Colors.white,
                                //       ),
                                //       onPressed: () {
                                //         exportschoolyeardata(schoolyear.id);
                                //       },
                                //       child: const Text("Export Result"),
                                //     ),
                                //   ],
                                // ),
                              ],
                            ),
                          ),
                        );

                        // return InkWell(
                        //   onTap: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) =>
                        //             ManageSection(schoolyear: schoolyear),
                        //       ),
                        //     );
                        //   },
                        // );
                      },
                    ),
                  ),
                ],
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
