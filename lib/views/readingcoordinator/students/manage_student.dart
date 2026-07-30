import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/student/add_student.dart';
import 'package:ireader_web/views/admin/student/add_student_dialog.dart';
import 'package:ireader_web/views/readingcoordinator/students/student_profile.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:universal_html/html.dart' show AnchorElement;

class RCManageStudentScreen extends StatefulWidget {
  final SchoolYear schoolyear;
  final Section section;

  const RCManageStudentScreen({
    super.key,
    required this.section,
    required this.schoolyear,
  });

  @override
  State<RCManageStudentScreen> createState() => _RCManageStudentScreenState();
}

class _RCManageStudentScreenState extends State<RCManageStudentScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String? _teacherName;

  @override
  void initState() {
    super.initState();
    _fetchTeacherName();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeacherName() async {
    final teacherSnapshot = await firestore
        .collection('teachers')
        .doc(widget.section.teacherid)
        .get();
    if (teacherSnapshot.exists) {
      final d = teacherSnapshot.data()!;
      setState(() {
        _teacherName =
            "${d['firstname']} ${d['middlename']} ${d['lastname']}";
      });
    }
  }

  Future<void> exportStudents() async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    const String lastCol = 'D';

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

    sheet.getRangeByName('A3:${lastCol}3').merge();
    sheet.getRangeByName('A3').setText('Teacher: $_teacherName');
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
    sheet.getRangeByName('B5').setText('GENDER');
    sheet.getRangeByName('C5').setText('SCORE');
    sheet.getRangeByName('D5').setText('START LEVEL OF GRADE PASSAGE');
    sheet.getRangeByName('A5:${lastCol}5').cellStyle.bold = true;

    int rowIndex = 6;

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
      sheet.getRangeByName('A$rowIndex').setText(
        "${student.lastname}, ${student.firstname} ${student.middlename != null && student.middlename!.isNotEmpty ? "${student.middlename!} " : ""}",
      );
      sheet.getRangeByName('B$rowIndex').setText(student.gender);
      sheet.getRangeByName('C$rowIndex').setText(student.gstscore.toString());
      sheet
          .getRangeByName('D$rowIndex')
          .setText(student.gradelevelread.toString());
      rowIndex++;
    }

    sheet.getRangeByName('A1:$lastCol$rowIndex').autoFitColumns();

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    AnchorElement(
        href: 'data:application/octet-stream;base64,${base64.encode(bytes)}',
      )
      ..setAttribute('download', 'Phil-IRI_Student_List(Stage_2).xlsx')
      ..click();
  }

  void _openAddStudent() {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    if (isMobile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddStudentScreen(
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
        builder: (_) => AddStudentDialog(
          section: widget.section,
          schoolyear: widget.schoolyear,
          student: null,
        ),
      );
    }
  }

  // ─── Reading level badge ───────────────────────────────────────────────────

  Widget _readingLevelBadge(String level) {
    Color bg;
    Color fg;

    switch (level) {
      case 'Frustration':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFF7C2D12);
        break;
      case 'Instructional':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF78350F);
        break;
      case 'Independent':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = AppTheme.textSecondaryColor;
    }

    final label = level.isEmpty ? 'N/A' : level;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // ─── Avatar ────────────────────────────────────────────────────────────────

  static const _avatarColors = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  Widget _avatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    final color = _avatarColors[name.codeUnitAt(0) % _avatarColors.length];
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ─── Table header ──────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'GRADE LEVEL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'READING LEVEL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'ACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Table row ─────────────────────────────────────────────────────────────

  Widget _buildRow(Student student) {
    final fullName =
        '${student.firstname}${student.middlename != null && student.middlename!.isNotEmpty ? " ${student.middlename}" : ""} ${student.lastname}';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // NAME
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _avatar(student.lastname),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'LRN: ${student.lrn}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // GRADE LEVEL
          Expanded(
            flex: 2,
            child: Text(
              student.gradelevelread.isEmpty ? '—' : student.gradelevelread,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),

          // READING LEVEL
          Expanded(
            flex: 3,
            child: _readingLevelBadge(student.readlevel),
          ),

          // ACTIONS
          SizedBox(
            width: 80,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RCStudentProfileScreen(
                      student: student,
                      section: widget.section,
                      schoolyear: widget.schoolyear,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 15,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(int shown, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search students by name or LRN...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$shown of $total students',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _openAddStudent,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.section.sectionname,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            Text(
              'SY ${widget.schoolyear.schoolyearstart}–${widget.schoolyear.schoolyearend}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('sectionid', isEqualTo: widget.section.id)
            .where('schoolyearid', isEqualTo: widget.schoolyear.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading students'));
          }

          var students = (snapshot.data?.docs ?? [])
              .map(
                (doc) => Student.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();

          students.sort(
            (a, b) =>
                a.lastname.toLowerCase().compareTo(b.lastname.toLowerCase()),
          );

          final total = students.length;

          final query = _searchController.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            students = students.where((s) {
              final name =
                  '${s.firstname} ${s.middlename ?? ''} ${s.lastname}'
                      .toLowerCase();
              return name.contains(query) || s.lrn.toLowerCase().contains(query);
            }).toList();
          }

          return Column(
            children: [
              _buildToolbar(students.length, total),
              if (students.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 52,
                          color:
                              AppTheme.textSecondaryColor.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          total == 0
                              ? 'No students in this section yet.'
                              : 'No students match "$query".',
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 15,
                          ),
                        ),
                        if (total == 0) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openAddStudent,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Student'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      _buildTableHeader(),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: students.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: AppTheme.borderColor,
                          ),
                          itemBuilder: (_, index) =>
                              _buildRow(students[index]),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
