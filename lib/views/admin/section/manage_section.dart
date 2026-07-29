import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/assessments/manage_assessment.dart';
import 'package:ireader_web/views/admin/practice_set/select_practice_set.dart';
import 'package:ireader_web/views/admin/section/add_section.dart';
import 'package:ireader_web/views/admin/section/add_section_dialog.dart';
import 'package:ireader_web/views/admin/section/edit_section.dart';
import 'package:ireader_web/views/admin/section/edit_section_dialog.dart';
import 'package:ireader_web/views/admin/student/manage_student.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row;
import 'package:universal_html/html.dart' show AnchorElement;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' show AnchorElement;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io';

class ManageSection extends StatefulWidget {
  final SchoolYear schoolyear;

  const ManageSection({super.key, required this.schoolyear});

  @override
  State<ManageSection> createState() => _ManageSectionState();
}

class _ManageSectionState extends State<ManageSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedbox = 0;
  final List<String> studentreads = ["Overall Result", "Comprehension Result"];
  String _selectedReadType = "Overall Result";

  // ✅ Fetch counts of reading levels per section

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

  String generateGenderSummary({
    required List<Section> sections,
    required Map<String, Map<String, Map<String, int>>> stats,
    required String gender,
  }) {
    int frustration = 0;
    int instructional = 0;
    int independent = 0;

    for (final s in sections) {
      frustration += stats[s.id]?['Frustration']?[gender] ?? 0;
      instructional += stats[s.id]?['Instructional']?[gender] ?? 0;
      independent += stats[s.id]?['Independent']?[gender] ?? 0;
    }

    final total = frustration + instructional + independent;

    if (total == 0) {
      return "No reading data available for $gender students.";
    }

    // ✅ weighted average
    final totalScore =
        (frustration * 1) + (instructional * 2) + (independent * 3);

    final avg = totalScore / total;
    final percent = ((avg / 3) * 100).toStringAsFixed(1);

    String performance;

    if (independent >= instructional && independent >= frustration) {
      performance =
          "high reading performance. Maintaining engaging reading activities may help sustain student's reading comprehension and fluency skills";
    } else if (instructional >= independent && instructional >= frustration) {
      performance =
          "stable reading performance. Regular reading engagement may help maintain this level of performance";
    } else {
      performance =
          "low reading performance. Additional support are recommended to help students improve their reading skills";
    }

    final frustrationPercent = (frustration / total) * 100;
    final instructionalPercent = (instructional / total) * 100;
    final independentPercent = (independent / total) * 100;

    return "$gender students have an average ${_selectedReadType} score of $percent%. "
        "${independentPercent.toStringAsFixed(1)}% Independent, "
        "${instructionalPercent.toStringAsFixed(1)}% Instructional, and "
        "${frustrationPercent.toStringAsFixed(1)}% Frustration. "
        "Most learners fall under the ${independent >= instructional && independent >= frustration
            ? "Independent"
            : instructional >= frustration
            ? "Instructional"
            : "Frustration"} level, "
        "indicating $performance.";

    // return "$gender students have an average ${_selectedReadType} score of $percent%. "
    //     "Most learners fall under the ${independent >= instructional && independent >= frustration
    //         ? "Independent"
    //         : instructional >= frustration
    //         ? "Instructional"
    //         : "Frustration"} level, "
    //     "indicating $performance.";
  }

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

  String _buildSectionChart(
    List<Section> sections,
    Map<String, Map<String, Map<String, int>>> stats,
    String? gender,
  ) {
    final labels = <String>[];

    final frustration = <int>[];
    final instructional = <int>[];
    final independent = <int>[];

    for (final s in sections) {
      labels.add(s.sectionname);

      if (gender == null) {
        frustration.add(
          (stats[s.id]?['Frustration']?['Male'] ?? 0) +
              (stats[s.id]?['Frustration']?['Female'] ?? 0),
        );

        instructional.add(
          (stats[s.id]?['Instructional']?['Male'] ?? 0) +
              (stats[s.id]?['Instructional']?['Female'] ?? 0),
        );

        independent.add(
          (stats[s.id]?['Independent']?['Male'] ?? 0) +
              (stats[s.id]?['Independent']?['Female'] ?? 0),
        );
      } else {
        frustration.add(stats[s.id]?['Frustration']?[gender] ?? 0);
        instructional.add(stats[s.id]?['Instructional']?[gender] ?? 0);
        independent.add(stats[s.id]?['Independent']?[gender] ?? 0);
      }
    }

    final config = {
      "type": "bar",
      "data": {
        "labels": labels, // ✅ section names on X axis
        "datasets": [
          {
            "label": "Frustration",
            "data": frustration,
            "backgroundColor": "rgb(255, 140, 0)",
          },
          {
            "label": "Instructional",
            "data": instructional,
            "backgroundColor": "rgb(255, 215, 128)",
          },
          {
            "label": "Independent",
            "data": independent,
            "backgroundColor": "rgb(144, 238, 144)",
          },
        ],
      },
      "options": {
        "plugins": {
          "legend": {
            "labels": {
              "font": {"size": 14},
            },
          },
          "title": {
            "display": true,
            "text": gender == null
                ? "All Sections Overview"
                : "$gender Students by Section",
            "font": {"size": 18},
          },
        },
        "scales": {
          "x": {
            "ticks": {
              "font": {"size": 14},
            },
          },
          "y": {
            "beginAtZero": true,
            "ticks": {
              "font": {"size": 14},
            },
          },
        },
      },
    };

    return "https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(config))}&width=900&height=600&devicePixelRatio=3";
  }

  Future<Map<String, Map<String, Map<String, int>>>>
  _computeSectionGenderStats() async {
    final Map<String, Map<String, Map<String, int>>> result = {};

    // Fetch sections
    final sectionsSnap = await _firestore
        .collection('sections')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .get();

    for (final sec in sectionsSnap.docs) {
      result[sec.id] = {
        'Frustration': {'Male': 0, 'Female': 0},
        'Instructional': {'Male': 0, 'Female': 0},
        'Independent': {'Male': 0, 'Female': 0},
      };

      // Fetch students per section
      final studentsSnap = await _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .where('sectionid', isEqualTo: sec.id)
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      for (final doc in studentsSnap.docs) {
        final student = Student.fromMap(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );

        final level = _selectedReadType == "Overall Result"
            ? student.readlevel
            : student.comprehensionresult;
        // final level = student.readlevel;
        final gender = student.gender;

        // ✅ strict validation
        if (level.isEmpty) continue;
        if (gender != 'Male' && gender != 'Female') continue;

        if (result[sec.id]!.containsKey(level)) {
          result[sec.id]![level]![gender] =
              result[sec.id]![level]![gender]! + 1;
        }
      }
    }

    return result;
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

  Widget _buildSectionInsightsCard({
    required List<Section> sections,
    required Map<String, Map<String, Map<String, int>>> stats,
    required String? gender,
    required String title,
  }) {
    final levels = ['Frustration', 'Instructional', 'Independent'];

    int totalStudents = 0;
    final Map<String, int> levelTotals = {
      'Frustration': 0,
      'Instructional': 0,
      'Independent': 0,
    };

    /// compute totals
    for (final s in sections) {
      for (final level in levels) {
        final count = gender == null
            ? (stats[s.id]?[level]?['Male'] ?? 0) +
                  (stats[s.id]?[level]?['Female'] ?? 0)
            : stats[s.id]?[level]?[gender] ?? 0;

        levelTotals[level] = levelTotals[level]! + count;
        totalStudents += count;
      }
    }

    double percent(String level) {
      if (totalStudents == 0) return 0;
      return (levelTotals[level]! / totalStudents) * 100;
    }

    final f = percent('Frustration');
    final i = percent('Instructional');
    final ind = percent('Independent');

    String trend;
    if (ind > f && ind > i) {
      trend =
          "increasing reading proficiency. Maintaining engaging reading activities and continuous exposure to varied texts may help sustain and further enhance student's reading comprehension and fluency skills";
    } else if (f > ind && f > i) {
      trend =
          "declining reading performance. Additional targeted support may help improve literacy outcomes";
    } else {
      trend =
          "relatively stable reading performance. Continued enrichment activities and regular reading engagement may help sustain this stability while encouraging further improvement in literacy performance";
    }

    // Find winning section for each level
    String getWinner(String level) {
      int max = 0;
      String winner = "(No records)";

      for (final s in sections) {
        final value = gender == null
            ? (stats[s.id]?[level]?['Male'] ?? 0) +
                  (stats[s.id]?[level]?['Female'] ?? 0)
            : stats[s.id]?[level]?[gender] ?? 0;

        if (value > max) {
          max = value;
          winner = s.sectionname;
        }
      }

      return winner;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              "This shows which section has the most students per ${_selectedReadType} level.",
            ),

            const SizedBox(height: 16),

            // Text("Frustration → ${f.toStringAsFixed(1)}%"),
            // Text("Instructional → ${i.toStringAsFixed(1)}%"),
            // Text("Independent → ${ind.toStringAsFixed(1)}%"),
            Text("Frustration → Most students in ${getWinner('Frustration')}"),
            Text(
              "Instructional → Most students in ${getWinner('Instructional')}",
            ),
            Text("Independent → Most students in ${getWinner('Independent')}"),

            const Divider(height: 28),

            const Text(
              "Overall Insights",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              "Across all sections, students average "
              "${ind.toStringAsFixed(1)}% Independent, "
              "${i.toStringAsFixed(1)}% Instructional, and "
              "${f.toStringAsFixed(1)}% Frustration. "
              "This indicates $trend across the section.",
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> exportStudents() async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    // Define last column (A=1, B=2, C=3, D=4, E=5, F=6 → so F is column 6)
    const String lastCol = 'F';

    // ==== HEADER 1: TITLE ====
    sheet
        .getRangeByName(
          'A1:$lastCol'
          '1',
        )
        .merge();
    sheet.getRangeByName('A1').setText('STUDENT LIST FOR PHIL-IRI');
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

    // ==== HEADER 3: DESCRIPTION LINE ====
    sheet
        .getRangeByName(
          'A3:$lastCol'
          '3',
        )
        .merge();
    sheet
        .getRangeByName('A3')
        .setText('All Students enrolled in Phil-IRI for the School Year');
    sheet.getRangeByName('A3').cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center;

    // ==== COLUMN HEADERS ====
    sheet.getRangeByName('A4').setText('SECTION');
    sheet.getRangeByName('B4').setText('TEACHER');
    sheet.getRangeByName('C4').setText('NAME');
    sheet.getRangeByName('D4').setText('GENDER');
    sheet.getRangeByName('E4').setText('GST SCORE');
    sheet.getRangeByName('F4').setText('START LEVEL OF GRADE PASSAGE');
    sheet
        .getRangeByName(
          'A4:$lastCol'
          '4',
        )
        .cellStyle
      ..bold = true;

    // ==== STUDENT DATA ====
    int rowIndex = 5;

    // Fetch all sections for the school year
    final sectionsSnap = await _firestore
        .collection('sections')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .get();

    for (var sectionDoc in sectionsSnap.docs) {
      final section = Section.fromMap(
        sectionDoc.id,
        sectionDoc.data() as Map<String, dynamic>,
      );

      // Fetch teacher
      final teacherSnap = await _firestore
          .collection('teachers')
          .doc(section.teacherid)
          .get();
      final teacherName = teacherSnap.exists
          ? "${teacherSnap['firstname']} ${teacherSnap['lastname']}"
          : 'Unknown';

      // Fetch students for this section
      final studentsSnap = await _firestore
          .collection('students')
          .where('sectionid', isEqualTo: section.id)
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .get();

      for (var studentDoc in studentsSnap.docs) {
        final student = Student.fromMap(
          studentDoc.id,
          studentDoc.data() as Map<String, dynamic>,
        );

        sheet.getRangeByName('A$rowIndex').setText(section.sectionname);
        sheet.getRangeByName('B$rowIndex').setText(teacherName);
        sheet
            .getRangeByName('C$rowIndex')
            .setText(
              "${student.lastname}, ${student.firstname} ${student.middlename != null && student.middlename!.isNotEmpty ? student.middlename! + " " : ""}",
            );
        sheet.getRangeByName('D$rowIndex').setText(student.gender);
        sheet.getRangeByName('E$rowIndex').setText(student.gstscore.toString());
        sheet
            .getRangeByName('F$rowIndex')
            .setText(student.gradelevelread.toString());
        rowIndex++;
      }
    }

    // Auto-fit columns
    sheet.getRangeByName('A1:$lastCol${rowIndex - 1}').autoFitColumns();

    // ==== EXPORT FILE ====
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    AnchorElement(
        href: 'data:application/octet-stream;base64,${base64.encode(bytes)}',
      )
      ..setAttribute('download', 'Phil-IRI_Student_List_All.xlsx')
      ..click();
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

  Widget _buildSelectButtons() {
    final filters = ["Overview", "Sections"];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(filters.length, (index) {
        final isSelected = _selectedbox == index;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected
                  ? AppTheme.primaryColor
                  : Colors.grey.shade200,
              foregroundColor: isSelected ? Colors.white : Colors.black87,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              setState(() => _selectedbox = index);
            },
            child: Text(
              filters[index],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedButton() {
    switch (_selectedbox) {
      case 0:
        return FutureBuilder<Map<String, Map<String, Map<String, int>>>>(
          future: _computeSectionGenderStats(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = snap.data!;

            return FutureBuilder<QuerySnapshot>(
              future: _firestore
                  .collection('sections')
                  .where('schoolyearid', isEqualTo: widget.schoolyear.id)
                  .get(),
              builder: (context, secSnap) {
                if (!secSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sections = secSnap.data!.docs
                    .map(
                      (d) => Section.fromMap(
                        d.id,
                        d.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      /// ==============================
                      /// OVERALL (LIKE YOUR IMAGE)
                      /// ==============================
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final isMobile = width <= 480;

                          return isMobile
                              ? Column(
                                  children: [
                                    _buildSectionInsightsCard(
                                      sections: sections,
                                      stats: stats,
                                      gender: null,
                                      title: "${_selectedReadType} Overview",
                                    ),
                                    const SizedBox(height: 20),
                                    _buildOverviewChart(
                                      sections,
                                      stats,
                                      isMobile,
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildSectionInsightsCard(
                                        sections: sections,
                                        stats: stats,
                                        gender: null,
                                        title: "${_selectedReadType} Overview",
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 3,
                                      child: _buildOverviewChart(
                                        sections,
                                        stats,
                                        isMobile,
                                      ),
                                    ),
                                  ],
                                );
                        },
                      ),

                      const SizedBox(height: 30),

                      /// Male / Female charts below
                      /// Male / Female charts below
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final isMobile = width <= 600;

                          return isMobile
                              // 🔥 MOBILE = STACKED (Scrollable)
                              ? Column(
                                  children: [
                                    _buildGenderSectionCard(
                                      title: "Male Students",
                                      gender: 'Male',
                                      sections: sections,
                                      stats: stats,
                                      isMobile: true,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildGenderSectionCard(
                                      title: "Female Students",
                                      gender: 'Female',
                                      sections: sections,
                                      stats: stats,
                                      isMobile: true,
                                    ),
                                  ],
                                )
                              // 🔥 DESKTOP = SIDE BY SIDE
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildGenderSectionCard(
                                        title: "Male Students",
                                        gender: 'Male',
                                        sections: sections,
                                        stats: stats,
                                        isMobile: false,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _buildGenderSectionCard(
                                        title: "Female Students",
                                        gender: 'Female',
                                        sections: sections,
                                        stats: stats,
                                        isMobile: false,
                                      ),
                                    ),
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

      case 1:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('sections')
              .where('schoolyearid', isEqualTo: widget.schoolyear.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
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
                double mainAxisExtent;

                if (width <= 480) {
                  crossAxisCount = 1; // 🔥 Mobile S
                  mainAxisExtent = 520; // taller card
                } else if (width <= 900) {
                  crossAxisCount = 2; // tablet
                  mainAxisExtent = 520;
                } else {
                  crossAxisCount = 3; // desktop
                  mainAxisExtent = 520;
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: screenWidth <= 600 ? 600 : 500,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: screenWidth <= 360
                            ? 540 // Mobile S (320px)
                            : screenWidth <= 600
                            ? 560 // Mobile
                            : 580, // Desktop
                      ),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];

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
                                /// SECTION TITLE
                                Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      section.sectionname,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                /// TEACHER
                                FutureBuilder<DocumentSnapshot>(
                                  future: _firestore
                                      .collection("teachers")
                                      .doc(section.teacherid)
                                      .get(),
                                  builder: (context, snap) {
                                    if (!snap.hasData) {
                                      return const Center(
                                        child: Text("Loading teacher..."),
                                      );
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

                                /// STUDENT COUNT
                                FutureBuilder<QuerySnapshot>(
                                  future: _firestore
                                      .collection('students')
                                      .where(
                                        'schoolyearid',
                                        isEqualTo: widget.schoolyear.id,
                                      )
                                      .where('sectionid', isEqualTo: section.id)
                                      .where('status', isEqualTo: 'ACTIVE')
                                      .get(),
                                  builder: (context, countSnap) {
                                    if (!countSnap.hasData) {
                                      return const Center(
                                        child: Text("Counting students..."),
                                      );
                                    }
                                    final count = countSnap.data!.docs.length;
                                    return Center(
                                      child: Text(
                                        "Total Students: $count",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 10),

                                /// RESPONSIVE CHART (LIKE SCHOOLYEAR)
                                SizedBox(
                                  height: screenWidth <= 360
                                      ? 200
                                      : screenWidth <= 600
                                      ? 230
                                      : 300,
                                  child: StreamBuilder<Map<String, int>>(
                                    stream: _fetchStudentReadLevels(section.id),
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

                                      final insight =
                                          "${_selectedReadType}: ${generateReadingInsight(counts)}";

                                      // final insight = generateReadingInsight(
                                      //   counts,
                                      // );

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
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 10),

                                /// FULL WIDTH BUTTONS (LIKE SCHOOLYEAR)
                                Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: _viewStudentsButton(section),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _selectpracticeset(section),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: editSectionButton(section),
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
            );
          },
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildGenderSectionCard({
    required String title,
    required String gender,
    required List<Section> sections,
    required Map<String, Map<String, Map<String, int>>> stats,
    required bool isMobile,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Image.network(
              _buildSectionChart(sections, stats, gender),
              height: isMobile ? 260 : 350,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 16),
            const Divider(height: 24),

            const Center(
              child: Text(
                "Insights",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            _buildSectionWinners(
              title: "",
              sections: sections,
              stats: stats,
              gender: gender,
            ),
            const SizedBox(height: 12),

            Text(
              generateGenderSummary(
                sections: sections,
                stats: stats,
                gender: gender,
              ),
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewStudentsButton(Section section) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.people),
      label: const Text('View Students'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManageStudentScreen(
              section: section,
              schoolyear: widget.schoolyear,
            ),
          ),
        );
      },
    );
  }

  Widget _selectpracticeset(Section section) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.menu_book),
      label: const Text('View Practice Sets'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
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

  void openEditSection({
    required BuildContext context,
    required Section section,
    required Teacher teacher,
  }) {
    final width = MediaQuery.of(context).size.width;

    // 🔥 MOBILE S 320 AND BELOW → SCREEN
    if (width <= 320) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditSection(section: section, teacher: teacher),
        ),
      );
    }
    // 🔥 ABOVE 320 → DIALOG
    else {
      showDialog(
        context: context,
        builder: (_) => EditSectionDialog(section: section, teacher: teacher),
      );
    }
  }

  Widget editSectionButton(Section section) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('teachers')
          .doc(section.teacherid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final teacher = Teacher.fromMap(
          snapshot.data!.id,
          snapshot.data!.data() as Map<String, dynamic>,
        );

        return ElevatedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('Edit Section'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => openEditSection(
            context: context,
            section: section,
            teacher: teacher,
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

  Future<void> _EditSection(Section section) async {
    final teacherDoc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(section.teacherid)
        .get();

    final teacher = Teacher.fromMap(
      teacherDoc.id,
      teacherDoc.data() as Map<String, dynamic>,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSection(section: section, teacher: teacher),
      ),
    );
  }

  Future<Map<String, Map<String, int>>> _computeSectionReadLevels() async {
    // sectionId -> readLevel -> count
    final Map<String, Map<String, int>> result = {};

    final sectionsSnap = await _firestore
        .collection('sections')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .get();

    for (final secDoc in sectionsSnap.docs) {
      final sectionId = secDoc.id;

      result[sectionId] = {
        'Frustration': 0,
        'Instructional': 0,
        'Independent': 0,
      };

      final studentsSnap = await _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .where('sectionid', isEqualTo: sectionId)
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      for (final s in studentsSnap.docs) {
        final level = s['readlevel'];
        if (result[sectionId]!.containsKey(level)) {
          result[sectionId]![level] = result[sectionId]![level]! + 1;
        }
      }
    }

    return result;
  }

  Widget _buildSectionWinners({
    required String title,
    required List<Section> sections,
    required Map<String, Map<String, Map<String, int>>> stats,
    required String? gender, // null = overall
  }) {
    final levels = ['Frustration', 'Instructional', 'Independent'];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...levels.map((level) {
              int max = 0;
              Section? winner;

              for (final s in sections) {
                final value = gender == null
                    ? (stats[s.id]?[level]?['Male'] ?? 0) +
                          (stats[s.id]?[level]?['Female'] ?? 0)
                    : stats[s.id]?[level]?[gender] ?? 0;

                if (value > max) {
                  max = value;
                  winner = s;
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  (winner == null || max == 0)
                      ? "$level → No records yet"
                      : "$level → Most students in ${winner.sectionname}",
                  style: const TextStyle(fontSize: 15),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewChart(
    List<Section> sections,
    Map<String, Map<String, Map<String, int>>> stats,
    bool isMobile,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Image.network(
          _buildSectionChart(sections, stats, null),
          height: isMobile ? 280 : 420,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
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
                        tooltip: "Create Section",
                        onPressed: () async {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                AddSectionScreen(schoolyear: widget.schoolyear),
                          );
                        },
                      )
                    // 🔥 ICON + LABEL (Tablet/Desktop)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create Section'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                AddSectionDialog(schoolyear: widget.schoolyear),
                          );
                        },
                      ),
              );
            },
          ),
        ],
      ),

      // ✅ Display sections
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: AutoSizeText(
                      "Sections - School Year: ${widget.schoolyear.schoolyearstart}-${widget.schoolyear.schoolyearend}",
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1, // Limit to 1 line
                      overflow: TextOverflow.ellipsis,
                      minFontSize: 12, // Optional, minimum font size
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSelectButtons(),
            const SizedBox(height: 12),
            _buildResultToggle(),
            const SizedBox(height: 12),
            Expanded(child: _buildSelectedButton()),
          ],
        ),
      ),
    );
  }
}
