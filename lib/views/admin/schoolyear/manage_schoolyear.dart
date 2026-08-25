import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/widgets/admin_sidebar.dart';
import 'package:ireader_web/widgets/admin_top_header.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentoverallresult.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/assessments/manage_assessment.dart';
import 'package:ireader_web/views/admin/schoolyear/add_schoolyear_dialog.dart';
import 'package:ireader_web/views/admin/section/manage_section.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' show AnchorElement;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class ManageSchoolyearScreen extends StatefulWidget {
  const ManageSchoolyearScreen({super.key});

  @override
  State<ManageSchoolyearScreen> createState() => _ManageSchoolyearScreenState();
}

class _ManageSchoolyearScreenState extends State<ManageSchoolyearScreen> {
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
          "This indicates a high average $_selectedReadType performance with a percentage of $percentFormatted%, where the majority "
          "of learners comprehend words independently.";
    } else if (instructional >= independent && instructional >= frustration) {
      insight =
          "Most students are at the Instructional level. "
          "This suggests that $_selectedReadType performance is distributed around a percentage of $percentFormatted%, with learners "
          "operating within a guided reading range.";
    } else {
      insight =
          "Most students fall under the Frustration level. "
          "This indicates a low average $_selectedReadType performance with a percentage of $percentFormatted% and reflects "
          "a concentration of learners currently facing reading difficulties.";
    }

    // ✅ STEP 4: Append percentage
    return insight;
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

  Widget _buildResultToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: studentreads.map((type) {
          final isSelected = _selectedReadType == type;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedReadType = type;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
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

      if (snap.docs.isEmpty) {
        return;
      }

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

  Widget _cardButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimaryColor,
          side: const BorderSide(color: AppTheme.borderColor),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      drawer: isDesktop
          ? null
          : Drawer(child: AdminSidebar(activeRoute: AdminRoute.schoolYears)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            const AdminSidebar(activeRoute: AdminRoute.schoolYears),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminTopHeader(
                  pageTitle: 'School Years',
                  pageSubtitle:
                      'Per-year results, sections, assessments and exports',
                  trailing: ElevatedButton.icon(
                    onPressed: () =>
                        AddSchoolyearDialog.show(context, schoolyear: null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add School Year'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<SchoolYear>>(
                    stream: _fetchSchoolYears(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('No School Years Found'),
                        );
                      }
                      final schoolYears = snapshot.data!;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                            child: Row(
                              children: [
                                _buildResultToggle(),
                                const Spacer(),
                                Text(
                                  '${schoolYears.length} of ${schoolYears.length} years',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: screenWidth <= 600
                                        ? 600
                                        : 380,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 370,
                                  ),
                              itemCount: schoolYears.length,
                              itemBuilder: (_, index) {
                                final schoolyear = schoolYears[index];
                                final isCurrentYear = index == 0;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.borderColor,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${schoolyear.schoolyearstart}-${schoolyear.schoolyearend}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    AppTheme.textPrimaryColor,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isCurrentYear
                                                    ? const Color(0xFFDCFCE7)
                                                    : AppTheme.backgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isCurrentYear
                                                    ? 'CURRENT'
                                                    : 'ARCHIVED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: isCurrentYear
                                                      ? const Color(0xFF15803D)
                                                      : AppTheme
                                                            .textSecondaryColor,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        StreamBuilder<Map<String, int>>(
                                          stream: _fetchStudentReadLevels(
                                            schoolyear.id,
                                          ),
                                          builder: (context, snap) {
                                            final counts =
                                                snap.data ??
                                                {
                                                  'Frustration': 0,
                                                  'Instructional': 0,
                                                  'Independent': 0,
                                                };
                                            final insight =
                                                generateReadingInsight(counts);
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    _DonutChart(counts: counts),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          _legendRow(
                                                            AppTheme
                                                                .levelFrustration,
                                                            'Frustration',
                                                            counts['Frustration'] ??
                                                                0,
                                                          ),
                                                          const SizedBox(
                                                            height: 7,
                                                          ),
                                                          _legendRow(
                                                            AppTheme
                                                                .levelInstructional,
                                                            'Instructional',
                                                            counts['Instructional'] ??
                                                                0,
                                                          ),
                                                          const SizedBox(
                                                            height: 7,
                                                          ),
                                                          _legendRow(
                                                            AppTheme
                                                                .levelIndependent,
                                                            'Independent',
                                                            counts['Independent'] ??
                                                                0,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  insight,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: AppTheme
                                                        .textSecondaryColor,
                                                    height: 1.45,
                                                  ),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _cardButton(
                                                'Sections',
                                                () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ManageSection(
                                                            schoolyear:
                                                                schoolyear,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _cardButton(
                                                'Edit Year',
                                                () {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (_) =>
                                                        AddSchoolyearDialog(
                                                          schoolyear:
                                                              schoolyear,
                                                        ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _cardButton(
                                                'Assessments',
                                                () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ManageAssessment(
                                                            schoolyear:
                                                                schoolyear,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _cardButton(
                                                'Export',
                                                () async {
                                                  final messenger =
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      );
                                                  try {
                                                    await exportschoolyeardata(
                                                      schoolyear.id,
                                                    );
                                                  } catch (e) {
                                                    messenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Export failed: $e',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 36,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ManageSection(
                                                    schoolyear: schoolyear,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1E293B,
                                              ),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              textStyle: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            child: const Text(
                                              'View Full Report',
                                            ),
                                          ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final Map<String, int> counts;
  const _DonutChart({required this.counts});

  @override
  Widget build(BuildContext context) {
    final total =
        (counts['Frustration'] ?? 0) +
        (counts['Instructional'] ?? 0) +
        (counts['Independent'] ?? 0);
    return SizedBox(
      width: 86,
      height: 86,
      child: CustomPaint(
        painter: _DonutPainter(counts: counts, total: total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Text(
                'students',
                style: TextStyle(
                  fontSize: 8,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> counts;
  final int total;
  _DonutPainter({required this.counts, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 7;
    const strokeWidth = 13.0;

    if (total == 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }

    final segments = [
      (key: 'Frustration', color: AppTheme.levelFrustration),
      (key: 'Instructional', color: AppTheme.levelInstructional),
      (key: 'Independent', color: AppTheme.levelIndependent),
    ];

    double startAngle = -math.pi / 2;
    const gap = 0.04;

    for (final seg in segments) {
      final value = counts[seg.key] ?? 0;
      if (value == 0) continue;
      final sweep = (value / total) * 2 * math.pi - gap;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap / 2,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.counts != counts || old.total != total;
}
