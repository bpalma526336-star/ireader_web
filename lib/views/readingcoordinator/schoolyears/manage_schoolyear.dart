import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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

  // Cached streams — created once, reused across rebuilds so StreamBuilder
  // never re-subscribes just because the widget rebuilt.
  late final Stream<List<SchoolYear>> _schoolYearsStream;
  final Map<String, Stream<List<Map<String, dynamic>>>> _studentStreams = {};

  @override
  void initState() {
    super.initState();
    _schoolYearsStream = _firestore
        .collection('schoolyears')
        .orderBy('schoolyearstart', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((doc) => SchoolYear.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<Map<String, dynamic>>> _studentStream(String schoolyearid) {
    return _studentStreams.putIfAbsent(
      schoolyearid,
      () => _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: schoolyearid)
          .where('status', isEqualTo: 'ACTIVE')
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList()),
    );
  }

  Map<String, int> _computeCounts(List<Map<String, dynamic>> students) {
    int frustration = 0, instructional = 0, independent = 0;
    for (final data in students) {
      final level = _selectedReadType == "Overall Result"
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
    };
  }

  String generateReadingInsight(Map<String, int> counts) {
    final frustration = counts['Frustration'] ?? 0;
    final instructional = counts['Instructional'] ?? 0;
    final independent = counts['Independent'] ?? 0;
    final total = frustration + instructional + independent;

    if (total == 0) return "No $_selectedReadType data recorded for this school year.";

    final frustPct = ((frustration / total) * 100).round();
    final instrPct = ((instructional / total) * 100).round();
    final indepPct = ((independent / total) * 100).round();

    if (independent >= instructional && independent >= frustration) {
      return "$indepPct% ($independent) of students reached the Independent level — "
          "they can read $_selectedReadType without teacher support. "
          "$frustPct% ($frustration) are still at Frustration and require the most immediate attention.";
    } else if (instructional >= independent && instructional >= frustration) {
      return "$instrPct% ($instructional) of students are at the Instructional level — "
          "they can progress in $_selectedReadType with guided support. "
          "$frustPct% ($frustration) are at Frustration and need intensive intervention.";
    } else {
      return "$frustPct% ($frustration) of students are at the Frustration level in $_selectedReadType — "
          "most learners are struggling significantly. "
          "Only $indepPct% ($independent) have reached the Independent level.";
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
      sheet.getRangeByName('A1').setText(
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
          'fm': 0, 'ff': 0, 'fa': 0,
          'im': 0, 'iff': 0, 'ia': 0,
          'im2': 0, 'iff2': 0, 'ia2': 0,
        };
      }

      final resultSnap = await _firestore
          .collection('overallresult')
          .where('assessmentid', isEqualTo: assessmentId)
          .get();

      int fm = 0, ff = 0, fa = 0, im = 0, iff = 0, ia = 0, im2 = 0, iff2 = 0, ia2 = 0;
      for (final r in resultSnap.docs) {
        final result = studentoverallresult.fromMap(r.id, r.data());
        final student = studentMap[result.studentid];
        if (student == null) continue;
        final gender = student.gender;
        final level = result.readlevel;
        if (level == 'Frustration') {
          fa++; if (gender == 'Male') fm++; if (gender == 'Female') ff++;
        }
        if (level == 'Instructional') {
          ia++; if (gender == 'Male') im++; if (gender == 'Female') iff++;
        }
        if (level == 'Independent') {
          ia2++; if (gender == 'Male') im2++; if (gender == 'Female') iff2++;
        }
      }
      return {
        'fm': fm, 'ff': ff, 'fa': fa,
        'im': im, 'iff': iff, 'ia': ia,
        'im2': im2, 'iff2': iff2, 'ia2': ia2,
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
          counts['fm'], counts['ff'], counts['fa'],
          counts['im'], counts['iff'], counts['ia'],
          counts['im2'], counts['iff2'], counts['ia2'],
        ];
        for (int i = 0; i < values.length; i++) {
          sheet.getRangeByIndex(row, 5 + i).setNumber(values[i]!.toDouble());
        }
        row++;
      }
      sheet.protect('');
    }

    await buildSheet(sheet: workbook.worksheets[0], title: 'Pre-Test', assessmentTitle: 'Stage 2 - Pre-Test');
    await buildSheet(sheet: workbook.worksheets.add(), title: 'Midway Test', assessmentTitle: 'Stage 3 - Midway/Mid-test');
    await buildSheet(sheet: workbook.worksheets.add(), title: 'Post-Test', assessmentTitle: 'Stage 4 - Post-Test');

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    if (kIsWeb) {
      AnchorElement(
        href: 'data:application/octet-stream;charset=utf-16le;base64,${base64.encode(bytes)}',
      )
        ..setAttribute('download', 'School Year ${schoolyear['schoolyearstart']} - ${schoolyear['schoolyearend']} Result.xlsx')
        ..click();
    } else {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final filePath = '$directory/School Year ${schoolyear['schoolyearstart']} - ${schoolyear['schoolyearend']} Result.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      OpenFile.open(filePath);
    }
  }


  Future<List<Map<String, dynamic>>> _fetchStudentsByLevel(
    String schoolyearid,
    String level,
  ) async {
    final sectionsSnap = await _firestore
        .collection('sections')
        .where('schoolyearid', isEqualTo: schoolyearid)
        .get();
    final sectionMap = <String, String>{
      for (final s in sectionsSnap.docs)
        s.id: (s.data()['sectionname'] ?? 'Unknown') as String,
    };

    final levelField = _selectedReadType == 'Overall Result' ? 'readlevel' : 'comprehensionresult';

    final snap = await _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearid)
        .where(levelField, isEqualTo: level)
        .where('status', isEqualTo: 'ACTIVE')
        .get();

    final list = snap.docs.map((doc) {
      final d = doc.data();
      return {
        ...d,
        'id': doc.id,
        'sectionname': sectionMap[d['sectionid']] ?? 'Unknown Section',
      };
    }).toList();

    list.sort((a, b) =>
        ((a['lastname'] as String?) ?? '').compareTo((b['lastname'] as String?) ?? ''));
    return list;
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'Frustration':   return Icons.warning_amber_rounded;
      case 'Instructional': return Icons.school_outlined;
      case 'Independent':   return Icons.stars_rounded;
      default:              return Icons.person;
    }
  }

  void _showStudentsByLevel(
    BuildContext context,
    String schoolyearid,
    String level,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.93,
          builder: (_, scrollController) =>
              FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchStudentsByLevel(schoolyearid, level),
            builder: (ctx, snap) {
              final students = snap.data ?? [];
              final isLoading = snap.connectionState == ConnectionState.waiting;

              return Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Sheet header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_levelIcon(level), size: 22, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$level Level',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              Text(
                                isLoading
                                    ? 'Loading students...'
                                    : '${students.length} student${students.length == 1 ? '' : 's'} · $_selectedReadType',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: const Color(0xFFF1F5F9)),
                  // Content
                  Expanded(
                    child: isLoading
                        ? Center(child: CircularProgressIndicator(color: color, strokeWidth: 2))
                        : students.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_off_outlined, size: 52, color: const Color(0xFFCBD5E1)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No students at $level level',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'There are no active students matching this level.',
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                                itemCount: students.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final s = students[i];
                                  final firstname = (s['firstname'] as String?) ?? '';
                                  final lastname = (s['lastname'] as String?) ?? '';
                                  final middle = (s['middlename'] as String?) ?? '';
                                  final initial = middle.isNotEmpty ? ' ${middle[0]}.' : '';
                                  final lrn = (s['lrn'] as String?) ?? '—';
                                  final section = (s['sectionname'] as String?) ?? '—';
                                  final gradeLevel = (s['gradelevelread'] as String?) ?? '';

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFEEF2F7), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              firstname.isNotEmpty ? firstname[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$lastname, $firstname$initial',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: AppTheme.textPrimaryColor,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(Icons.badge_outlined, size: 10, color: AppTheme.textSecondaryColor),
                                                  const SizedBox(width: 3),
                                                  Text('LRN: $lrn', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.group_outlined, size: 10, color: AppTheme.textSecondaryColor),
                                                  const SizedBox(width: 3),
                                                  Flexible(
                                                    child: Text(
                                                      gradeLevel.isNotEmpty ? '$section · Grade $gradeLevel read' : section,
                                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            level,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ],
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
      ),
    );
  }

  // --- Segmented toggle ---
  Widget _buildResultToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: studentreads.map((type) {
          final isSelected = _selectedReadType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedReadType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Center(
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  // --- Tappable level tile (replaces _legendRow) ---
  Widget _levelTile(Color color, String label, int count, int total, VoidCallback? onTap) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    final hasData = count > 0;
    return Expanded(
      child: GestureDetector(
        onTap: hasData ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: hasData ? color.withValues(alpha: 0.07) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: hasData ? color.withValues(alpha: 0.28) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: hasData ? color : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  if (hasData)
                    Icon(Icons.arrow_forward_ios_rounded, size: 9, color: color.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasData ? '$pct%' : '—',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: hasData ? color : const Color(0xFFCBD5E1),
                  height: 1.1,
                ),
              ),
              Text(
                '$count student${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: hasData ? color.withValues(alpha: 0.75) : const Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Action button ---
  Widget _cardButton({required String label, required VoidCallback onTap, IconData? icon}) {
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13),
              const SizedBox(width: 5),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      drawer: isDesktop ? null : Drawer(child: RCSidebar(activeRoute: RCRoute.schoolYears)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const RCSidebar(activeRoute: RCRoute.schoolYears),
          Expanded(
            child: StreamBuilder<List<SchoolYear>>(
              stream: _schoolYearsStream,
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Page header ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'School Years',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phil-IRI $_selectedReadType · ${schoolYears.length} year${schoolYears.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(width: 290, child: _buildResultToggle()),
                        ],
                      ),
                    ),

                    // ── Card list ────────────────────────────────────────────
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        itemCount: schoolYears.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final schoolyear = schoolYears[index];
                          final isCurrentYear = index == 0;

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top accent strip
                                  Container(
                                    height: 3.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isCurrentYear
                                            ? [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.5)]
                                            : [const Color(0xFFCBD5E1), const Color(0xFFE2E8F0)],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Card header
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'SCHOOL YEAR',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppTheme.textSecondaryColor,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${schoolyear.schoolyearstart} – ${schoolyear.schoolyearend}',
                                                    style: const TextStyle(
                                                      fontSize: 21,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppTheme.textPrimaryColor,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isCurrentYear ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                isCurrentYear ? 'CURRENT' : 'ARCHIVED',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isCurrentYear ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                                                  letterSpacing: 0.7,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),
                                        Container(height: 1, color: const Color(0xFFF1F5F9)),
                                        const SizedBox(height: 16),

                                        // ── Reading level data ────────────
                                        StreamBuilder<List<Map<String, dynamic>>>(
                                          stream: _studentStream(schoolyear.id),
                                          builder: (context, snap) {
                                            if (snap.connectionState == ConnectionState.waiting) {
                                              return const SizedBox(
                                                height: 130,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    color: AppTheme.primaryColor,
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              );
                                            }

                                            final counts = _computeCounts(snap.data ?? []);
                                            final total =
                                                (counts['Frustration'] ?? 0) +
                                                (counts['Instructional'] ?? 0) +
                                                (counts['Independent'] ?? 0);
                                            final needIntervention = counts['Frustration'] ?? 0;
                                            final insight = generateReadingInsight(counts);

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Donut + summary
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    _RCDonutChart(counts: counts),
                                                    const SizedBox(width: 18),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            '$total',
                                                            style: const TextStyle(
                                                              fontSize: 30,
                                                              fontWeight: FontWeight.w900,
                                                              color: AppTheme.textPrimaryColor,
                                                              height: 1,
                                                            ),
                                                          ),
                                                          const Text(
                                                            'total students',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme.textSecondaryColor,
                                                            ),
                                                          ),
                                                          if (needIntervention > 0) ...[
                                                            const SizedBox(height: 10),
                                                            GestureDetector(
                                                              onTap: () => _showStudentsByLevel(
                                                                context, schoolyear.id, 'Frustration', AppTheme.levelFrustration,
                                                              ),
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme.levelFrustration.withValues(alpha: 0.1),
                                                                  borderRadius: BorderRadius.circular(7),
                                                                  border: Border.all(color: AppTheme.levelFrustration.withValues(alpha: 0.3)),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(Icons.priority_high_rounded, size: 12, color: AppTheme.levelFrustration),
                                                                    const SizedBox(width: 4),
                                                                    Flexible(
                                                                      child: Text(
                                                                        '$needIntervention need${needIntervention == 1 ? 's' : ''} intervention',
                                                                        style: TextStyle(
                                                                          fontSize: 10.5,
                                                                          fontWeight: FontWeight.w700,
                                                                          color: AppTheme.levelFrustration,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 3),
                                                                    Icon(Icons.chevron_right_rounded, size: 13, color: AppTheme.levelFrustration),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 14),

                                                // 3 tappable level tiles
                                                Row(
                                                  children: [
                                                    _levelTile(
                                                      AppTheme.levelFrustration,
                                                      'Frustration',
                                                      counts['Frustration'] ?? 0,
                                                      total,
                                                      () => _showStudentsByLevel(context, schoolyear.id, 'Frustration', AppTheme.levelFrustration),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _levelTile(
                                                      AppTheme.levelInstructional,
                                                      'Instructional',
                                                      counts['Instructional'] ?? 0,
                                                      total,
                                                      () => _showStudentsByLevel(context, schoolyear.id, 'Instructional', AppTheme.levelInstructional),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _levelTile(
                                                      AppTheme.levelIndependent,
                                                      'Independent',
                                                      counts['Independent'] ?? 0,
                                                      total,
                                                      () => _showStudentsByLevel(context, schoolyear.id, 'Independent', AppTheme.levelIndependent),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 12),

                                                // Insight box
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF8FAFC),
                                                    borderRadius: BorderRadius.circular(9),
                                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Icon(
                                                        Icons.info_outline_rounded,
                                                        size: 14,
                                                        color: AppTheme.primaryColor,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          insight,
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            color: AppTheme.textSecondaryColor,
                                                            height: 1.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 16),

                                        // Action buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _cardButton(
                                                label: 'View Sections',
                                                icon: Icons.grid_view_rounded,
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => RCManageSection(schoolyear: schoolyear),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _cardButton(
                                                label: 'Assessments',
                                                icon: Icons.assignment_outlined,
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ManageAssessment(schoolyear: schoolyear),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _RCDonutPainter(counts: counts, total: total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Text(
                'total',
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
  bool shouldRepaint(covariant _RCDonutPainter old) =>
      old.counts != counts || old.total != total;
}
