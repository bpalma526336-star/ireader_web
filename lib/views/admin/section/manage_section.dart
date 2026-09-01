import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/section/add_section_dialog.dart';
import 'package:ireader_web/views/admin/section/compare_section.dart';
import 'package:ireader_web/views/admin/section/edit_section.dart';
import 'package:ireader_web/views/admin/section/edit_section_dialog.dart';
import 'package:ireader_web/views/admin/student/manage_student.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:universal_html/html.dart' show AnchorElement;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ManageSection extends StatefulWidget {
  final SchoolYear schoolyear;

  const ManageSection({super.key, required this.schoolyear});

  @override
  State<ManageSection> createState() => _ManageSectionState();
}

class _ManageSectionState extends State<ManageSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final List<String> studentreads = ["Overall Result", "Comprehension Result"];
  String _selectedReadType = "Overall Result";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Reading insight ───────────────────────────────────────────────────────

  String generateReadingInsight(Map<String, int> counts) {
    final frustration = counts['Frustration'] ?? 0;
    final instructional = counts['Instructional'] ?? 0;
    final independent = counts['Independent'] ?? 0;

    final total = frustration + instructional + independent;

    if (total == 0) {
      return "No reading data available for this section.";
    }

    final totalScore =
        (frustration * 1) + (instructional * 2) + (independent * 3);
    final averageScore = totalScore / total;
    final percentage = (averageScore / 3) * 100;
    final percentFormatted = percentage.toStringAsFixed(1);

    String insight;
    if (independent >= instructional && independent >= frustration) {
      insight =
          "Most students are classified under the Independent level, "
          "accounting for $percentFormatted% of $_selectedReadType performance, "
          "indicating that the majority of learners comprehend material independently.";
    } else if (instructional >= independent && instructional >= frustration) {
      insight =
          "Most students are at the Instructional level, "
          "accounting for $percentFormatted% of $_selectedReadType performance, "
          "reflecting a distribution where learners typically require guided reading support.";
    } else {
      insight =
          "Most students fall under the Frustration level, "
          "accounting for $percentFormatted% of $_selectedReadType performance, "
          "highlighting a concentration of learners facing reading challenges.";
    }

    return insight;
  }

  // ─── Stream: reading level counts per section ──────────────────────────────

  Stream<Map<String, int>> _fetchStudentReadLevels(String sectionid) {
    return _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
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

  // ─── Stream: all sections for this school year ─────────────────────────────

  Stream<List<Section>> _fetchSections() {
    return _firestore
        .collection('sections')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Section.fromMap(d.id, d.data())).toList(),
        );
  }

  // ─── Export: all students in this school year ──────────────────────────────

  Future<void> exportStudents() async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    const String lastCol = 'F';

    sheet.getRangeByName('A1:${lastCol}1').merge();
    sheet.getRangeByName('A1').setText('STUDENT LIST FOR PHIL-IRI');
    sheet.getRangeByName('A1').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center
      ..bold = true;

    sheet.getRangeByName('A2:${lastCol}2').merge();
    sheet
        .getRangeByName('A2')
        .setText(
          'School Year: ${widget.schoolyear.schoolyearstart} - ${widget.schoolyear.schoolyearend}',
        );
    sheet.getRangeByName('A2').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    sheet.getRangeByName('A3:${lastCol}3').merge();
    sheet
        .getRangeByName('A3')
        .setText('All Students enrolled in Phil-IRI for the School Year');
    sheet.getRangeByName('A3').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    sheet.getRangeByName('A4').setText('SECTION');
    sheet.getRangeByName('B4').setText('TEACHER');
    sheet.getRangeByName('C4').setText('NAME');
    sheet.getRangeByName('D4').setText('GENDER');
    sheet.getRangeByName('E4').setText('GST SCORE');
    sheet.getRangeByName('F4').setText('START LEVEL OF GRADE PASSAGE');
    sheet.getRangeByName('A4:${lastCol}4').cellStyle.bold = true;

    int rowIndex = 5;

    final sectionsSnap = await _firestore
        .collection('sections')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .get();

    for (var sectionDoc in sectionsSnap.docs) {
      final section = Section.fromMap(sectionDoc.id, sectionDoc.data());

      final teacherSnap = await _firestore
          .collection('teachers')
          .doc(section.teacherid)
          .get();

      String teacherName = "Unknown";

      if (teacherSnap.exists) {
        final data = teacherSnap.data() as Map<String, dynamic>;

        final middle = (data['middlename'] ?? '').toString();

        teacherName =
            "${data['firstname'] ?? ''} "
            "${middle.isNotEmpty ? '$middle ' : ''}"
            "${data['lastname'] ?? ''}";
      }

      final studentsSnap = await _firestore
          .collection('students')
          .where('sectionid', isEqualTo: section.id)
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .get();

      for (var studentDoc in studentsSnap.docs) {
        final student = Student.fromMap(studentDoc.id, studentDoc.data());

        sheet.getRangeByName('A$rowIndex').setText(section.sectionname);
        sheet.getRangeByName('B$rowIndex').setText(teacherName);
        sheet
            .getRangeByName('C$rowIndex')
            .setText(
              "${student.lastname}, ${student.firstname} ${student.middlename != null && student.middlename!.isNotEmpty ? "${student.middlename!} " : ""}",
            );
        sheet.getRangeByName('D$rowIndex').setText(student.gender);
        sheet.getRangeByName('E$rowIndex').setText(student.gstscore.toString());
        sheet
            .getRangeByName('F$rowIndex')
            .setText(student.gradelevelread.toString());
        rowIndex++;
      }
    }

    sheet.getRangeByName('A1:$lastCol${rowIndex - 1}').autoFitColumns();

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    AnchorElement(
        href: 'data:application/octet-stream;base64,${base64.encode(bytes)}',
      )
      ..setAttribute('download', 'Phil-IRI_Student_List_All.xlsx')
      ..click();
  }

  // ─── Export: single section ─────────────────────────────────────────────────

  Future<void> exportSectionStudents(Section section) async {
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
    sheet
        .getRangeByName('A2')
        .setText(
          'School Year: ${widget.schoolyear.schoolyearstart} - ${widget.schoolyear.schoolyearend}',
        );
    sheet.getRangeByName('A2').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    final teacherSnap = await _firestore
        .collection('teachers')
        .doc(section.teacherid)
        .get();
    final teacherName = teacherSnap.exists
        ? "${teacherSnap['firstname']} ${teacherSnap['middlename']} ${teacherSnap['lastname']}"
        : 'Unknown';

    sheet.getRangeByName('A3:${lastCol}3').merge();
    sheet.getRangeByName('A3').setText('Teacher: $teacherName');
    sheet.getRangeByName('A3').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    sheet.getRangeByName('A4:${lastCol}4').merge();
    sheet
        .getRangeByName('A4')
        .setText(
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

  // ─── Open edit dialog/screen ───────────────────────────────────────────────

  Future<void> _openEditSection(Section section) async {
    final teacherDoc = await _firestore
        .collection('teachers')
        .doc(section.teacherid)
        .get();

    if (!mounted) return;

    final teacher = Teacher.fromMap(
      teacherDoc.id,
      teacherDoc.data() as Map<String, dynamic>,
    );

    final width = MediaQuery.of(context).size.width;
    if (width <= 320) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditSection(section: section, teacher: teacher),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => EditSectionDialog(section: section, teacher: teacher),
      );
    }
  }

  // ─── Result type toggle ────────────────────────────────────────────────────

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
          return GestureDetector(
            onTap: () => setState(() => _selectedReadType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
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

  // ─── Card helpers ──────────────────────────────────────────────────────────

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

  // ─── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
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
                  hintText: 'Search sections...',
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
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
          _buildResultToggle(),
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      AddSectionDialog(schoolyear: widget.schoolyear),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Section'),
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
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CompareSection(schoolYear: widget.schoolyear),
                  ),
                );
              },
              icon: const Icon(Icons.compare_arrows, size: 16),
              label: const Text('Compare Section'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimaryColor,
                side: const BorderSide(color: AppTheme.borderColor),
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

  // ─── Section card ──────────────────────────────────────────────────────────

  Widget _buildSectionCard(Section section) {
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
            // ── Section name + teacher ──────────────────────────────────
            Text(
              section.sectionname,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection('teachers')
                  .doc(section.teacherid)
                  .get(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  );
                }
                final d = snap.data!;
                final name = d.exists
                    ? "${d['firstname']} ${d['lastname']}"
                    : 'Unknown Teacher';
                return Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ── Donut + legend ─────────────────────────────────────────
            StreamBuilder<Map<String, int>>(
              stream: _fetchStudentReadLevels(section.id),
              builder: (context, snap) {
                final counts =
                    snap.data ??
                    {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
                final insight = generateReadingInsight(counts);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _DonutChart(counts: counts),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legendRow(
                                AppTheme.levelFrustration,
                                'Frustration',
                                counts['Frustration'] ?? 0,
                              ),
                              const SizedBox(height: 7),
                              _legendRow(
                                AppTheme.levelInstructional,
                                'Instructional',
                                counts['Instructional'] ?? 0,
                              ),
                              const SizedBox(height: 7),
                              _legendRow(
                                AppTheme.levelIndependent,
                                'Independent',
                                counts['Independent'] ?? 0,
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
                        color: AppTheme.textSecondaryColor,
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

            // ── Action buttons ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _cardButton('View Students', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageStudentScreen(
                          section: section,
                          schoolyear: widget.schoolyear,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _cardButton('Edit', () async {
                    await _openEditSection(section);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await exportSectionStudents(section);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.file_download, size: 14),
                label: const Text('Export'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimaryColor,
                  side: const BorderSide(color: AppTheme.borderColor),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
              'SY ${widget.schoolyear.schoolyearstart}–${widget.schoolyear.schoolyearend}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Text(
              'Manage Sections',
              style: TextStyle(
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
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: StreamBuilder<List<Section>>(
              stream: _fetchSections(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 52,
                          color: AppTheme.textSecondaryColor.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No sections found for this school year.',
                          style: TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  );
                }

                final query = _searchController.text.trim().toLowerCase();
                final sections = snapshot.data!.where((s) {
                  if (query.isEmpty) return true;
                  return s.sectionname.toLowerCase().contains(query);
                }).toList();

                if (sections.isEmpty) {
                  return Center(
                    child: Text(
                      'No sections match "$query".',
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: screenWidth <= 600 ? 600 : 380,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 360,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (_, index) => _buildSectionCard(sections[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Donut chart ─────────────────────────────────────────────────────────────

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
