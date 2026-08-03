import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentoverallresult.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/readingcoordinator/assessments/manage_assessment.dart';
import 'package:ireader_web/views/readingcoordinator/sections/manage_section.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:universal_html/html.dart' hide File, VoidCallback;
import 'dart:io';
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

  String generateReadingInsight(Map<String, int> counts) {
    final frustration = counts['Frustration'] ?? 0;
    final instructional = counts['Instructional'] ?? 0;
    final independent = counts['Independent'] ?? 0;
    final total = frustration + instructional + independent;

    if (total == 0) return "No reading data available for this school year.";

    final totalScore =
        (frustration * 1) + (instructional * 2) + (independent * 3);
    final averageScore = totalScore / total;
    final percentage = (averageScore / 3) * 100;
    final percentFormatted = percentage.toStringAsFixed(1);

    if (independent >= instructional && independent >= frustration) {
      return "Most students are classified under the Independent level. "
          "This indicates a high average $_selectedReadType performance with a percentage of $percentFormatted%, and the majority "
          "of learners can read and comprehend words independently.";
    } else if (instructional >= independent && instructional >= frustration) {
      return "Most students are at the Instructional level. "
          "This suggests that $_selectedReadType performance remains stable with a percentage of $percentFormatted%, and learners "
          "benefit from guided reading support to improve further.";
    } else {
      return "Most students fall under the Frustration level. "
          "This indicates a low average $_selectedReadType performance with a percentage of $percentFormatted% and highlights the "
          "need for targeted reading interventions and support.";
    }
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

    Future<Map<String, int>> countSectionResults({
      required String sectionId,
      required String assessmentId,
    }) async {
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
      final resultSnap = await _firestore
          .collection('overallresult')
          .where('assessmentid', isEqualTo: assessmentId)
          .get();
      int fm = 0,
          ff = 0,
          fa = 0,
          im = 0,
          iff = 0,
          ia = 0,
          im2 = 0,
          iff2 = 0,
          ia2 = 0;
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

  Stream<Map<String, int>> _fetchStudentReadLevels(String schoolyearid) {
    return _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearid)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
          int frustration = 0, instructional = 0, independent = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final level = _selectedReadType == "Overall Result"
                ? (data['readlevel'] ?? '')
                : (data['comprehensionresult'] ?? '');
            if (level == 'Frustration')
              frustration++;
            else if (level == 'Instructional')
              instructional++;
            else if (level == 'Independent')
              independent++;
          }
          return {
            'Frustration': frustration,
            'Instructional': instructional,
            'Independent': independent,
          };
        });
  }

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
          : Drawer(child: RCSidebar(activeRoute: RCRoute.schoolYears)),
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
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No School Year Found"));
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
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: screenWidth <= 600 ? 600 : 380,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 320,
                        ),
                        itemCount: schoolYears.length,
                        itemBuilder: (context, index) {
                          final schoolyear = schoolYears[index];
                          final isCurrentYear = index == 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrentYear
                                              ? const Color(0xFFDCFCE7)
                                              : AppTheme.backgroundColor,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                                : AppTheme.textSecondaryColor,
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
                                      final insight = generateReadingInsight(
                                        counts,
                                      );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              _RCDonutChart(counts: counts),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _legendRow(
                                                      AppTheme.levelFrustration,
                                                      'Frustration',
                                                      counts['Frustration'] ??
                                                          0,
                                                    ),
                                                    const SizedBox(height: 7),
                                                    _legendRow(
                                                      AppTheme
                                                          .levelInstructional,
                                                      'Instructional',
                                                      counts['Instructional'] ??
                                                          0,
                                                    ),
                                                    const SizedBox(height: 7),
                                                    _legendRow(
                                                      AppTheme.levelIndependent,
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
                                              color:
                                                  AppTheme.textSecondaryColor,
                                              height: 1.45,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _cardButton('View Sections', () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => RCManageSection(
                                                schoolyear: schoolyear,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _cardButton('Assessments', () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ManageAssessment(
                                                schoolyear: schoolyear,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  // Export button hidden
                                  // const SizedBox(height: 6),
                                  // SizedBox(
                                  //   width: double.infinity,
                                  //   child: OutlinedButton(
                                  //     onPressed: () => exportschoolyeardata(schoolyear.id),
                                  //     child: const Text("Export Result"),
                                  //   ),
                                  // ),
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
    );
  }
}

class _RCDonutChart extends StatelessWidget {
  final Map<String, int> counts;
  const _RCDonutChart({required this.counts});

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
        painter: _RCDonutPainter(counts: counts, total: total),
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

class _RCDonutPainter extends CustomPainter {
  final Map<String, int> counts;
  final int total;
  _RCDonutPainter({required this.counts, required this.total});

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
  bool shouldRepaint(covariant _RCDonutPainter old) =>
      old.counts != counts || old.total != total;
}
