import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/teacher/assessments/viewassessment.dart';
import 'package:ireader_web/views/teacher/practice_set/select_practice_set.dart';
import 'package:ireader_web/views/teacher/students/manage_student.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:universal_html/html.dart' show AnchorElement;
import 'dart:html' as html;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
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
  final List<String> studentreads = ['Overall Result', 'Comprehension Result'];
  String _selectedReadType = 'Overall Result';

  String generateReadingInsight(Map<String, int> counts) {
    final frustration = counts['Frustration'] ?? 0;
    final instructional = counts['Instructional'] ?? 0;
    final independent = counts['Independent'] ?? 0;
    final total = frustration + instructional + independent;

    if (total == 0) return 'No reading data available for this section yet.';

    final totalScore = (frustration * 1) + (instructional * 2) + (independent * 3);
    final averageScore = totalScore / total;
    final percentage = (averageScore / 3) * 100;
    final percentFormatted = percentage.toStringAsFixed(1);

    if (independent >= instructional && independent >= frustration) {
      return 'Most students read at the Independent level ($percentFormatted% avg). '
          'Learners can comprehend passages with minimal guidance.';
    } else if (instructional >= independent && instructional >= frustration) {
      return 'Most students are at the Instructional level ($percentFormatted% avg). '
          'Guided reading support will help learners progress further.';
    } else {
      return 'Most students fall at the Frustration level ($percentFormatted% avg). '
          'Targeted reading interventions are recommended.';
    }
  }

  Stream<Map<String, int>> _fetchStudentReadLevels(String sectionid, String schoolyearid) {
    return _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearid)
        .where('sectionid', isEqualTo: sectionid)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
          int frustration = 0, instructional = 0, independent = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final level = _selectedReadType == 'Overall Result'
                ? (data['readlevel'] ?? '')
                : (data['comprehensionresult'] ?? '');
            if (level == 'Frustration') frustration++;
            else if (level == 'Instructional') instructional++;
            else if (level == 'Independent') independent++;
          }
          return {
            'Frustration': frustration,
            'Instructional': instructional,
            'Independent': independent,
            'Total': snapshot.docs.length,
          };
        });
  }

  Future<void> exportSectionStudents(Section section) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    const String lastCol = 'D';
    const String lastcolgender = 'C';
    const String lastcolgstscore = 'D';

    sheet.getRangeByName('A1:${lastCol}1').merge();
    sheet.getRangeByName('A1').setText('STAGE 2 ADMISSION IN PHIL-IRI');
    sheet.getRangeByName('A1').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center
      ..bold = true;

    sheet.getRangeByName('A2:${lastCol}2').merge();
    sheet.getRangeByName('A2').setText(
      'School Year: ${widget.schoolyear.schoolyearstart} - ${widget.schoolyear.schoolyearend}',
    );
    sheet.getRangeByName('A2').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    final teacherSnap = await _firestore.collection('teachers').doc(section.teacherid).get();
    final teacherName = teacherSnap.exists
        ? '${teacherSnap['firstname']} ${teacherSnap['middlename']} ${teacherSnap['lastname']}'
        : 'Unknown';

    sheet.getRangeByName('A3:${lastCol}3').merge();
    sheet.getRangeByName('A3').setText('Teacher: $teacherName');
    sheet.getRangeByName('A3').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    sheet.getRangeByName('A4:${lastCol}4').merge();
    sheet.getRangeByName('A4').setText(
      'Students who will undergo Phil-IRI Oral Reading in English (Stage 2)',
    );
    sheet.getRangeByName('A4').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    sheet.getRangeByName('A5').setText('NAME');
    sheet.getRangeByName('B5:${lastcolgender}5').setText('GENDER');
    sheet.getRangeByName('C5:${lastcolgstscore}5').setText('SCORE');
    sheet.getRangeByName('D5').setText('START LEVEL OF GRADE PASSAGE');
    sheet.getRangeByName('A5:${lastCol}5').cellStyle.bold = true;

    int rowIndex = 6;
    final snapshot = await _firestore
        .collection('students')
        .where('sectionid', isEqualTo: section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .get();
    final students =
        snapshot.docs.map((doc) => Student.fromMap(doc.id, doc.data())).toList();
    students.sort((a, b) => a.lastname.toLowerCase().compareTo(b.lastname.toLowerCase()));

    for (var student in students) {
      sheet.getRangeByName('A$rowIndex').setText(
        '${student.lastname}, ${student.firstname} ${student.middlename != null && student.middlename!.isNotEmpty ? "${student.middlename!} " : ""}',
      );
      sheet.getRangeByName('B$rowIndex').setText(student.gender);
      sheet.getRangeByName('C$rowIndex').setText(student.gstscore.toString());
      sheet.getRangeByName('D$rowIndex').setText(student.gradelevelread.toString());
      rowIndex++;
    }

    sheet.getRangeByName('A1:$lastCol$rowIndex').autoFitColumns();

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    if (kIsWeb) {
      AnchorElement(
          href: 'data:application/octet-stream;base64,${base64.encode(bytes)}',
        )
        ..setAttribute('download', 'Phil-IRI_Student_List(Stage_2)_${section.sectionname}.xlsx')
        ..click();
    } else {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final filePath = '$directory/Phil-IRI_Student_List(Stage_2)_${section.sectionname}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      OpenFile.open(filePath);
    }
  }

  // ─── TOP BAR ────────────────────────────────────────────────
  Widget _buildTopBar() {
    final teacherName =
        '${widget.teacher.firstname} ${widget.teacher.lastname}'.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 0, 24, 0),
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo / brand mark
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'iR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'iReader',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Teacher',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const Spacer(),
          // Teacher info chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.teacher.firstname.isNotEmpty
                          ? widget.teacher.firstname[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      teacherName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      'SY ${widget.schoolyear.schoolyearstart}-${widget.schoolyear.schoolyearend}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Logout
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 15, color: Color(0xFFDC2626)),
            label: const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDC2626),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: const Color(0xFFFFF1F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              html.window.history.pushState(null, '', '');
              html.window.onPopState.listen((event) {
                html.window.history.pushState(null, '', '');
              });
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── RESULT TOGGLE ──────────────────────────────────────────
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
              if (_selectedReadType != type) setState(() => _selectedReadType = type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SECTION CARD ────────────────────────────────────────────
  Widget _buildSectionCard(Section section) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.class_outlined, size: 20, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.sectionname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('schoolyears').doc(section.schoolyearid).get(),
                        builder: (context, sySnap) {
                          if (!sySnap.hasData || !sySnap.data!.exists) return const SizedBox.shrink();
                          final sy = sySnap.data!.data() as Map<String, dynamic>;
                          return Text(
                            'SY ${sy['schoolyearstart']}-${sy['schoolyearend']}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondaryColor,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Reading level stats ──
          Padding(
            padding: const EdgeInsets.all(20),
            child: StreamBuilder<Map<String, int>>(
              stream: _fetchStudentReadLevels(section.id, section.schoolyearid),
              builder: (context, snapshot) {
                final counts = snapshot.data ??
                    {'Frustration': 0, 'Instructional': 0, 'Independent': 0, 'Total': 0};
                final f = counts['Frustration'] ?? 0;
                final i = counts['Instructional'] ?? 0;
                final ind = counts['Independent'] ?? 0;
                final total = counts['Total'] ?? 0;
                final displayCounts = {'Frustration': f, 'Instructional': i, 'Independent': ind};
                final insight = generateReadingInsight(displayCounts);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Donut + legend side by side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _DonutChart(counts: displayCounts),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Total students callout
                              Row(
                                children: [
                                  Text(
                                    '$total',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'total students',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _legendRow(AppTheme.levelFrustration, 'Frustration', f),
                              const SizedBox(height: 6),
                              _legendRow(AppTheme.levelInstructional, 'Instructional', i),
                              const SizedBox(height: 6),
                              _legendRow(AppTheme.levelIndependent, 'Independent', ind),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Progress bar distribution
                    if (total > 0) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: Row(
                            children: [
                              if (f > 0)
                                Expanded(
                                  flex: f,
                                  child: Container(color: AppTheme.levelFrustration),
                                ),
                              if (i > 0)
                                Expanded(
                                  flex: i,
                                  child: Container(color: AppTheme.levelInstructional),
                                ),
                              if (ind > 0)
                                Expanded(
                                  flex: ind,
                                  child: Container(color: AppTheme.levelIndependent),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Reading insight
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              insight,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondaryColor,
                                height: 1.45,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Action buttons ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _viewStudentsButton(section)),
                    const SizedBox(width: 8),
                    Expanded(child: _viewAssessmentButton(section)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _viewPracticeSetButton(section)),
                    const SizedBox(width: 8),
                    Expanded(child: _exportButton(section)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
        ),
        Text(
          '$count',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor),
        ),
      ],
    );
  }

  // ─── ACTION BUTTONS ──────────────────────────────────────────
  Widget _viewStudentsButton(Section section) {
    return _actionBtn(
      icon: Icons.people_outline,
      label: 'Students',
      isPrimary: true,
      onTap: () async {
        final schoolYearDoc = await _firestore.collection('schoolyears').doc(section.schoolyearid).get();
        if (!schoolYearDoc.exists) return;
        final correctSchoolYear = SchoolYear.fromMap(schoolYearDoc.id, schoolYearDoc.data() as Map<String, dynamic>);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherManageStudentScreen(section: section, schoolyear: correctSchoolYear)));
      },
    );
  }

  Widget _viewAssessmentButton(Section section) {
    return _actionBtn(
      icon: Icons.assignment_outlined,
      label: 'Assessments',
      isPrimary: true,
      onTap: () async {
        final schoolYearDoc = await _firestore.collection('schoolyears').doc(section.schoolyearid).get();
        if (!schoolYearDoc.exists) return;
        final correctSchoolYear = SchoolYear.fromMap(schoolYearDoc.id, schoolYearDoc.data() as Map<String, dynamic>);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAssessment(schoolyear: correctSchoolYear)));
      },
    );
  }

  Widget _viewPracticeSetButton(Section section) {
    return _actionBtn(
      icon: Icons.menu_book_outlined,
      label: 'Practice Set',
      isPrimary: false,
      onTap: () async {
        final schoolYearDoc = await _firestore.collection('schoolyears').doc(section.schoolyearid).get();
        if (!schoolYearDoc.exists) return;
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => SelectPracticeSetScreen(section: section, schoolyear: widget.schoolyear)));
      },
    );
  }

  Widget _exportButton(Section section) {
    return _actionBtn(
      icon: Icons.file_download_outlined,
      label: 'Export',
      isPrimary: false,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await exportSectionStudents(section);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
        }
      },
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.primaryColor : Colors.white,
          foregroundColor: isPrimary ? Colors.white : AppTheme.textPrimaryColor,
          elevation: 0,
          side: isPrimary ? null : const BorderSide(color: AppTheme.borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildTopBar(),

          // Page title + toggle toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(28, 14, 24, 14),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'My Sections',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sections assigned to you for SY ${widget.schoolyear.schoolyearstart}-${widget.schoolyear.schoolyearend}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildResultToggle(),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderColor),

          // Sections content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('sections')
                  .where('teacherid', isEqualTo: widget.teacher.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Center(
                            child: Icon(Icons.class_outlined, size: 32, color: AppTheme.textSecondaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No sections assigned yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Contact your administrator to be assigned to a section.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  );
                }

                final sections = snapshot.data!.docs
                    .map((doc) => Section.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    double cardWidth;
                    if (width <= 520) {
                      cardWidth = width - 48;
                    } else if (width <= 900) {
                      cardWidth = (width - 64) / 2;
                    } else {
                      cardWidth = (width - 80) / 3;
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: sections.map((section) {
                          return SizedBox(
                            width: cardWidth,
                            child: _buildSectionCard(section),
                          );
                        }).toList(),
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

// ─── DONUT CHART ─────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final Map<String, int> counts;
  const _DonutChart({required this.counts});

  @override
  Widget build(BuildContext context) {
    final total = (counts['Frustration'] ?? 0) +
        (counts['Instructional'] ?? 0) +
        (counts['Independent'] ?? 0);
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _DonutPainter(counts: counts, total: total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Text(
                'total',
                style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryColor),
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
    final radius = (size.shortestSide / 2) - 8;
    const strokeWidth = 14.0;

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
