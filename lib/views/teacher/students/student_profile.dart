import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/ps_record.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/sl_record.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentassessmentresult.dart';
import 'package:ireader_web/model/studentoverallresult.dart';
import 'package:ireader_web/model/studentreadingresult.dart';
import 'package:ireader_web/model/wr_record.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/teacher/students/add_student_read_record.dart';
import 'package:ireader_web/views/teacher/students/add_student_read_record_dialog.dart';
import 'package:ireader_web/views/teacher/students/studentcompresultdetails.dart';

class StudentProfileScreen extends StatefulWidget {
  final Student student;
  final SchoolYear schoolyear;
  final Section section;

  const StudentProfileScreen({
    super.key,
    required this.student,
    required this.schoolyear,
    required this.section,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class CompInsights {
  final double average;
  final double highest;
  final double? lowest;
  final String highestStage;
  final String? lowestStage;
  final bool improving;

  CompInsights({
    required this.average,
    required this.highest,
    required this.lowest,
    required this.highestStage,
    required this.lowestStage,
    required this.improving,
  });

  String get performanceLevel {
    if (average >= 80) return "High / Increasing";
    if (average >= 59) return "Moderate / Stable";
    return "Low / Declining";
  }

  String get insightMessage {
    if (average >= 80) {
      return "The student demonstrates a high level of reading comprehension. "
          "With an average score of ${average.toStringAsFixed(1)}%, the student's performance is considered increasing/high. Continue providing challenging reading activities to sustain progress.";
    } else if (average >= 59) {
      return "The student demonstrates a moderate level of reading comprehension. "
          "With an average score of ${average.toStringAsFixed(1)}%, the student's performance is considered stable. Continued guided reading and comprehension practice are recommended to improve performance.";
    } else {
      return "The student demonstrates a low level of reading comprehension. "
          "With an average score of ${average.toStringAsFixed(1)}%, the student's performance is considered declining/low. Additional interventions, guided reading, and targeted comprehension support are recommended.";
    }
  }
}

CompInsights buildInsights(
  List<CompAssessmentResult> results,
  Map<String, String> assessmentTitles,
) {
  if (results.isEmpty) {
    return CompInsights(
      average: 0,
      highest: 0,
      lowest: null,
      highestStage: "-",
      lowestStage: null,
      improving: false,
    );
  }

  final scores = results
      .map((e) => double.tryParse(e.resultpercentage) ?? 0)
      .toList();

  final stages = results
      .map((e) => assessmentTitles[e.assessmentid] ?? "")
      .toList();

  // Find highest score
  double highest = scores.first;
  int highestIndex = 0;

  for (int i = 1; i < scores.length; i++) {
    if (scores[i] > highest) {
      highest = scores[i];
      highestIndex = i;
    }
  }

  // Find the lowest score that is STRICTLY lower than the highest.
  double? lowest;
  int? lowestIndex;

  for (int i = 0; i < scores.length; i++) {
    if (scores[i] < highest) {
      if (lowest == null || scores[i] < lowest!) {
        lowest = scores[i];
        lowestIndex = i;
      }
    }
  }

  final average = scores.reduce((a, b) => a + b) / scores.length;

  return CompInsights(
    average: average,
    highest: highest,
    lowest: lowest,
    highestStage: stages[highestIndex],
    lowestStage: lowestIndex != null ? stages[lowestIndex] : null,
    improving: scores.last >= scores.first,
  );
}

// class CompInsights {
//   final double average;
//   final double highest;
//   final double lowest;
//   final String highestStage;
//   final String lowestStage;
//   final bool improving;

//   CompInsights({
//     required this.average,
//     required this.highest,
//     required this.lowest,
//     required this.highestStage,
//     required this.lowestStage,
//     required this.improving,
//   });
// }

// CompInsights buildInsights(
//   List<CompAssessmentResult> results,
//   Map<String, String> assessmentTitles,
// ) {
//   if (results.isEmpty) {
//     return CompInsights(
//       average: 0,
//       highest: 0,
//       lowest: 0,
//       highestStage: "-",
//       lowestStage: "-",
//       improving: false,
//     );
//   }

//   final scores = results
//       .map((e) => double.tryParse(e.resultpercentage) ?? 0)
//       .toList();

//   double highest = scores.first;
//   double lowest = scores.first;

//   int highestIndex = 0;
//   int lowestIndex = 0;

//   for (int i = 0; i < scores.length; i++) {
//     if (scores[i] > highest) {
//       highest = scores[i];
//       highestIndex = i;
//     }

//     if (scores[i] < lowest) {
//       lowest = scores[i];
//       lowestIndex = i;
//     }
//   }

//   final average = scores.reduce((a, b) => a + b) / scores.length;

//   return CompInsights(
//     average: average,
//     highest: highest,
//     lowest: lowest,
//     highestStage:
//         assessmentTitles[results[highestIndex].assessmentid] ?? "Unknown",
//     lowestStage:
//         assessmentTitles[results[lowestIndex].assessmentid] ?? "Unknown",
//     improving: scores.last >= scores.first,
//   );
// }

Widget buildQuickChart(
  List<CompAssessmentResult> results,
  Map<String, String> titles,
) {
  final labels = results.map((e) => titles[e.assessmentid] ?? "").toList();

  final scores = results.map((e) => double.parse(e.resultpercentage)).toList();

  final chart = {
    "type": "bar",
    "data": {
      "labels": labels,
      "datasets": [
        {
          "label": "Comprehension Score",
          "data": scores,
          "backgroundColor": [
            "#3B82F6",
            "#60A5FA",
            "#93C5FD",
            "#BFDBFE",
            "#DBEAFE",
          ],
          "borderColor": "#1D4ED8",
          "borderWidth": 1,
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
        "title": {"display": true, "text": "Student Comprehension Progress"},
      },
      "scales": {
        "x": {
          "ticks": {
            "font": {"size": 12},
          },
        },
        "y": {
          "beginAtZero": true,
          "max": 100,
          "ticks": {
            "font": {"size": 12},
          },
        },
      },
    },
  };

  final url =
      "https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chart))}";

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(url, fit: BoxFit.contain),
  );
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<StudentReadingresult> studentprofilereadingresult = [];
  List<CompAssessmentResult> studentassessmentresult = [];
  List<studentoverallresult> levelhistory = [];

  int _selectedFilter =
      0; // 0 = Profile, 1 = ReadLevel, 2 = ReadingResult, 3 = Assessment, 4 = History

  int _selectedPracticeset =
      0; // 0 = Word Recognition, 1 = Phrase and Sentences, 2 = Storyline Adventure

  @override
  void initState() {
    super.initState();
  }

  Widget _cardBox({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeSetButtons() {
    final practiceSets = [
      "Word Recognition",
      "Phrase and Sentences",
      "Storyline Adventure",
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(practiceSets.length, (index) {
          final isSelected = _selectedPracticeset == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? AppTheme.primaryColor
                    : Colors.white,
                foregroundColor: isSelected
                    ? Colors.white
                    : AppTheme.textSecondaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => setState(() => _selectedPracticeset = index),
              child: Text(practiceSets[index]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedPracticeSet() {
    final practiceSets = [
      "Word Recognition",
      "Phrase and Sentences",
      "Storyline Adventure",
    ];

    Widget buildPracticeCard({
      required String title,
      required String subtitle,
      required List<Widget> stats,
      required String badge,
      required Color badgeColor,
    }) {
      return _cardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 8, children: stats),
          ],
        ),
      );
    }

    Widget buildResultList<T>(
      Stream<QuerySnapshot> stream,
      T Function(DocumentSnapshot doc) converter,
      Widget Function(T item) builder,
      String emptyMessage,
    ) {
      return StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState(emptyMessage);
          }

          final results = snapshot.data!.docs.map(converter).toList();

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => builder(results[index]),
          );
        },
      );
    }

    switch (_selectedPracticeset) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Activities History"),
            const SizedBox(height: 12),
            _buildPracticeSetButtons(),
            const SizedBox(height: 16),
            Expanded(
              child: buildResultList<wr_record>(
                _firestore
                    .collection('wr_record_results')
                    .where('studentid', isEqualTo: widget.student.id)
                    .snapshots(),
                (doc) => wr_record.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
                (item) => buildPracticeCard(
                  title: "Word Recognition Practice",
                  subtitle: "Completed: ${item.timestamp}",
                  badge: "${item.resultpercentage}%",
                  badgeColor: Colors.green,
                  stats: [
                    _statChip(
                      Icons.check_circle_outlined,
                      "Correct",
                      item.correctitems,
                      Colors.green,
                    ),
                    _statChip(
                      Icons.cancel_outlined,
                      "Incorrect",
                      item.incorrectitems,
                      Colors.redAccent,
                    ),
                    _statChip(
                      Icons.list_alt,
                      "Total",
                      item.totalitems,
                      AppTheme.secondaryColor,
                    ),
                  ],
                ),
                "No word recognition activities yet",
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Activities History"),
            const SizedBox(height: 12),
            _buildPracticeSetButtons(),
            const SizedBox(height: 16),
            Expanded(
              child: buildResultList<ps_record>(
                _firestore
                    .collection('ps_record_results')
                    .where('studentid', isEqualTo: widget.student.id)
                    .snapshots(),
                (doc) => ps_record.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
                (item) => buildPracticeCard(
                  title: "Phrase & Sentences Practice",
                  subtitle: "Completed: ${item.timestamp}",
                  badge: "${item.resultpercentage}%",
                  badgeColor: Colors.blue,
                  stats: [
                    _statChip(
                      Icons.check_circle_outlined,
                      "Correct",
                      item.correctitems,
                      Colors.green,
                    ),
                    _statChip(
                      Icons.cancel_outlined,
                      "Incorrect",
                      item.incorrectitems,
                      Colors.redAccent,
                    ),
                    _statChip(
                      Icons.list_alt,
                      "Total",
                      item.totalitems,
                      AppTheme.secondaryColor,
                    ),
                  ],
                ),
                "No phrase and sentence activities yet",
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Activities History"),
            const SizedBox(height: 12),
            _buildPracticeSetButtons(),
            const SizedBox(height: 16),
            Expanded(
              child: buildResultList<sl_record>(
                _firestore
                    .collection('sl_record_results')
                    .where('studentid', isEqualTo: widget.student.id)
                    .snapshots(),
                (doc) => sl_record.fromMap(
                  doc.data() as Map<String, dynamic>,
                  id: doc.id,
                ),
                (item) => buildPracticeCard(
                  title: item.readingpassagetitle.isNotEmpty
                      ? item.readingpassagetitle
                      : "Storyline Adventure Practice",
                  subtitle: "Completed: ${item.timestamp}",
                  badge: "${item.resultpercentage}%",
                  badgeColor: Colors.purple,
                  stats: [
                    _statChip(
                      Icons.check_circle_outlined,
                      "Correct",
                      item.correctitems,
                      Colors.green,
                    ),
                    _statChip(
                      Icons.cancel_outlined,
                      "Incorrect",
                      item.incorrectitems,
                      Colors.redAccent,
                    ),
                    _statChip(
                      Icons.list_alt,
                      "Total",
                      item.totalitems,
                      AppTheme.secondaryColor,
                    ),
                  ],
                ),
                "No storyline adventure activities yet",
              ),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color color = Colors.blueGrey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value),
        ],
      ),
    );
  }

  Widget buildInsightCard(CompInsights insight) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Comprehension Overview",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Text(
              "Highest Score → ${insight.highestStage} (${insight.highest.toStringAsFixed(1)}%)",
            ),

            const SizedBox(height: 10),

            Text(
              insight.lowest == null || insight.lowestStage == null
                  ? "Lowest Score → No lowest score"
                  : "Lowest Score → ${insight.lowestStage} "
                        "(${insight.lowest!.toStringAsFixed(1)}%)",
            ),

            const SizedBox(height: 10),

            Text("Average Score → ${insight.average.toStringAsFixed(1)}%"),

            const SizedBox(height: 10),

            Text(
              "Performance Level → ${insight.performanceLevel}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const Divider(height: 40),

            const Text(
              "Insights",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            Text(insight.insightMessage),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>> _getAssessmentTitles(
    List<CompAssessmentResult> results,
  ) async {
    final Map<String, String> titles = {};

    for (final result in results) {
      titles[result.assessmentid] = await _getAssessmentName(
        result.assessmentid,
      );
    }

    return titles;
  }

  Future<String> _getAssessmentName(String assessmentid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('assessment')
          .doc(assessmentid)
          .get();
      if (doc.exists) {
        return doc['assessmenttitle'] ?? 'Unnamed Assessment';
      }
      return 'Unknown Assessment';
    } catch (e) {
      return 'Unknown Assessment';
    }
  }

  //  Future<String> _getCompResultDetails(String compresultid) async {
  //   try {
  //     final doc = await FirebaseFirestore.instance
  //         .collection('compresultdetails')
  //         .doc(compresultid)
  //         .get();
  //     if (doc.exists) {
  //       final total = doc['totalitems'] ?? 0;
  //       final correct = doc['correctitems'] ?? 0;
  //       return '$correct / $total Correct';
  //     }
  //     return 'Unknown Result';
  //   } catch (e) {
  //     return 'Unknown Result';
  //   }
  // }

  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchStudentReadingResult(),
      _fetchStudentAssessmentResult(),
      _fetchStudentReadHistory(),
    ]);
  }

  Future<void> _fetchStudentReadingResult() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('readingresult')
        .where('studentid', isEqualTo: widget.student.id)
        .get();

    setState(() {
      studentprofilereadingresult = snapshot.docs
          .map((d) => StudentReadingresult.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> _fetchStudentAssessmentResult() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('comprehensionresult')
        .where('studentid', isEqualTo: widget.student.id)
        .get();

    setState(() {
      studentassessmentresult = snapshot.docs
          .map((d) => CompAssessmentResult.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> _fetchStudentReadHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('overallresult')
        .where('studentid', isEqualTo: widget.student.id)
        .get();

    setState(() {
      levelhistory = snapshot.docs
          .map((d) => studentoverallresult.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Widget _buildFilterButtons() {
    final filters = [
      "Reading Results",
      "Comprehension Results",
      "Overall Results",
      "Recommendations",
      "Activities History",
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilter == index;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey.shade200,
                foregroundColor: isSelected ? Colors.white : Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() => _selectedFilter = index);
              },
              child: Text(
                filters[index],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildList<T>({
    required List<T> data,
    required String title,
    required Widget Function(T item) itemBuilder,
  }) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          "No records yet",
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: itemBuilder(data[index]),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedFilter) {
      // 🔹 Reading Results Stream
      case 0:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('readingresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No Reading Results yet"));
            }

            final results = snapshot.data!.docs
                .map(
                  (doc) => StudentReadingresult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Assessment Title
                        FutureBuilder<String>(
                          future: _getAssessmentName(item.assessmentid),
                          builder: (context, snap) {
                            final title = snap.data ?? item.assessmentid;
                            return Row(
                              children: [
                                const Icon(
                                  Icons.assignment,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        _infoRow(
                          icon: Icons.warning_amber_rounded,
                          label: "Total Miscues",
                          value: item.totalmiscues.toString(),
                          color: Colors.redAccent,
                        ),
                        _infoRow(
                          icon: Icons.menu_book,
                          label: "Total Words",
                          value: item.totalwordsread.toString(),
                          color: Colors.deepPurple,
                        ),
                        _infoRow(
                          icon: Icons.analytics,
                          label: "Reading Result",
                          value: item.totalreadingresult.toString(),
                          color: Colors.green,
                        ),
                        _infoRow(
                          icon: Icons.trending_up,
                          label: "Reading Level",
                          value: item.readinglevel.toString(),
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

      // 🔹 Assessment Results Stream
      case 1:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('comprehensionresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text("Something went wrong"));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "No Assessment Results Yet",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              );
            }

            final results = snapshot.data!.docs
                .map(
                  (doc) => CompAssessmentResult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            // final insight = buildInsights(results, {
            //   for (var result in results)
            //     result.assessmentid: result.readingpassagetitle,
            // });

            // final assessmentTitles = {
            //   for (var result in results)
            //     result.assessmentid: result.readingpassagetitle,
            // };

            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth <= 768;

            final results1 = snapshot.data!.docs
                .map(
                  (doc) => CompAssessmentResult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // For very small screens stack the insight card and chart vertically
                if (isSmallScreen) ...[
                  FutureBuilder<Map<String, String>>(
                    future: _getAssessmentTitles(results1),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final assessmentTitles = snapshot.data!;
                      final insight = buildInsights(results, assessmentTitles);

                      return Column(
                        children: [
                          buildInsightCard(insight),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: buildQuickChart(results, assessmentTitles),
                          ),
                        ],
                      );
                    },
                  ),
                  // buildInsightCard(insight),
                  // const SizedBox(height: 12),
                  // SizedBox(
                  //   height: 200,
                  //   child: FutureBuilder<Map<String, String>>(
                  //     future: _getAssessmentTitles(results),
                  //     builder: (context, snapshot) {
                  //       if (!snapshot.hasData) {
                  //         return const Center(
                  //           child: CircularProgressIndicator(),
                  //         );
                  //       }
                  //       return buildQuickChart(results, snapshot.data!);
                  //     },
                  //   ),
                  // ),
                ] else ...[
                  FutureBuilder<Map<String, String>>(
                    future: _getAssessmentTitles(results1),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final assessmentTitles = snapshot.data!;
                      final insight = buildInsights(results1, assessmentTitles);

                      return SizedBox(
                        height: 420,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 2, child: buildInsightCard(insight)),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 3,
                              child: buildQuickChart(
                                results1,
                                assessmentTitles,
                              ),
                            ),
                            const SizedBox(width: 20),
                          ],
                        ),
                      );
                    },
                  ),
                  // SizedBox(
                  //   height: 420,
                  //   child: Row(
                  //     crossAxisAlignment: CrossAxisAlignment.stretch,
                  //     children: [
                  //       Expanded(flex: 2, child: buildInsightCard(insight)),
                  //       const SizedBox(width: 20),
                  //       Expanded(
                  //         flex: 3,
                  //         child: FutureBuilder<Map<String, String>>(
                  //           future: _getAssessmentTitles(results),
                  //           builder: (context, snapshot) {
                  //             if (!snapshot.hasData) {
                  //               return const Center(
                  //                 child: CircularProgressIndicator(),
                  //               );
                  //             }
                  //             return buildQuickChart(results, snapshot.data!);
                  //           },
                  //         ),
                  //       ),
                  //       const SizedBox(width: 20),
                  //     ],
                  //   ),
                  // ),
                ],

                const SizedBox(height: 20),

                ...results.map(
                  (item) => Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Assessment Title
                          FutureBuilder<String>(
                            future: _getAssessmentName(item.assessmentid),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Text(
                                  "Loading assessment...",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                );
                              }

                              final title = snap.data ?? item.assessmentid;

                              return Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          /// Score Row
                          Row(
                            children: [
                              const Icon(
                                Icons.score,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Score: ${item.resultpercentage}%",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          /// Comprehension Level Row
                          Row(
                            children: [
                              const Icon(
                                Icons.bar_chart,
                                size: 18,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Level: ${item.result}",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          /// View Result Button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        compresultdetails(compResult: item),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: AppTheme.primaryColor,
                              ),
                              child: const Text(
                                "View Result",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );

      // 🔹 Level History Stream (with async data fetch)
      case 2:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('overallresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No Overall Result yet"));
            }

            final histories = snapshot.data!.docs
                .map(
                  (doc) => studentoverallresult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.builder(
              itemCount: histories.length,
              itemBuilder: (context, index) {
                final item = histories[index];

                return FutureBuilder<String>(
                  future: _getAssessmentName(item.assessmentid),
                  builder: (context, snapshot) {
                    final assessmentTitle =
                        snapshot.data ?? "Unknown Assessment";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// Assessment Title
                            Row(
                              children: [
                                const Icon(
                                  Icons.assignment,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    assessmentTitle,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            _infoRow(
                              icon: Icons.menu_book,
                              label: "Word Reading",
                              value: item.wordreadresult.toString(),
                              color: Colors.deepPurple,
                            ),
                            _infoRow(
                              icon: Icons.psychology,
                              label: "Comprehension",
                              value: item.readcompresult.toString(),
                              color: Colors.green,
                            ),
                            _infoRow(
                              icon: Icons.trending_up,
                              label: "Reading Level",
                              value: item.readlevel.toString(),
                              color: Colors.orange,
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

      case 3:
        return _buildRecommendationsTab();

      case 4:
        return _buildSelectedPracticeSet();

      default:
        return const SizedBox();
    }
  }

  // ── Phil-IRI recommendation helpers ──────────────────────────────────────

  Color _levelColor(String level) {
    switch (level) {
      case 'Frustration':
        return AppTheme.levelFrustration;
      case 'Instructional':
        return AppTheme.levelInstructional;
      case 'Independent':
        return AppTheme.levelIndependent;
      default:
        return Colors.grey;
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'Frustration':
        return Icons.warning_amber_rounded;
      case 'Instructional':
        return Icons.school;
      case 'Independent':
        return Icons.star;
      default:
        return Icons.info_outline;
    }
  }

  String _wordReadingGuidance(String level) {
    switch (level) {
      case 'Frustration':
        return 'This student reads below 90% word accuracy. Phil-IRI recommends '
            'intensive intervention with Frustration-level word recognition drills '
            'to build foundational decoding and sight-word skills.';
      case 'Instructional':
        return 'This student reads at 90–95% word accuracy. Phil-IRI recommends '
            'Instructional-level word recognition practice with teacher guidance '
            'to improve reading fluency and accuracy.';
      case 'Independent':
        return 'This student reads at 96–100% word accuracy. Phil-IRI recommends '
            'Independent-level enrichment activities to expand vocabulary '
            'and reading stamina.';
      default:
        return 'No word reading assessment has been recorded yet.';
    }
  }

  String _comprehensionGuidance(String level) {
    switch (level) {
      case 'Frustration':
        return 'This student comprehends below 50% of reading material. Phil-IRI '
            'recommends Frustration-level passages and sentence exercises '
            'to build comprehension foundations through structured, supported reading.';
      case 'Instructional':
        return 'This student comprehends 50–74% of reading material. Phil-IRI '
            'recommends Instructional-level reading passages and sentences '
            'with guided comprehension support to strengthen understanding.';
      case 'Independent':
        return 'This student comprehends 75% or more of reading material. Phil-IRI '
            'recommends Independent-level stories and enrichment reading '
            'to develop higher-order comprehension and critical thinking.';
      default:
        return 'No comprehension assessment has been recorded yet.';
    }
  }

  Widget _levelBadge(String level) {
    final color = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_levelIcon(level), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            level.isEmpty ? 'Not assessed' : level,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _guidanceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _practiceSetChip({
    required String title,
    required String gradelevel,
    required String category,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimaryColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _smallTag(gradelevel, Colors.blueGrey),
              _smallTag(category, color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPracticeSetSection({
    required String sectionTitle,
    required IconData icon,
    required Color color,
    required Future<List<Map<String, String>>> future,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              sectionTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, String>>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final sets = snap.data ?? [];

            if (sets.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No published practice sets available for this level.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
              ),
              itemCount: sets.length,
              itemBuilder: (context, i) => _practiceSetChip(
                title: sets[i]['title'] ?? '',
                gradelevel: sets[i]['gradelevel'] ?? '',
                category: sets[i]['category'] ?? '',
                color: color,
              ),
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, String>>> _fetchRecommendedWR(String category) async {
    if (category.isEmpty) return [];
    final snap = await _firestore
        .collection('wordrecognitionpracticeset')
        .where('sectionid', isEqualTo: widget.section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'View to Students')
        .get();
    return snap.docs.map((d) {
      final m = d.data();
      return {
        'title': (m['title'] ?? '') as String,
        'gradelevel': (m['gradelevel'] ?? '') as String,
        'category': (m['category'] ?? '') as String,
      };
    }).toList();
  }

  Future<List<Map<String, String>>> _fetchRecommendedSentences(
    String category,
  ) async {
    if (category.isEmpty) return [];
    final snap = await _firestore
        .collection('phrasesentencespracticeset')
        .where('sectionid', isEqualTo: widget.section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'View to Students')
        .get();
    return snap.docs.map((d) {
      final m = d.data();
      return {
        'title': (m['title'] ?? '') as String,
        'gradelevel': (m['gradelevel'] ?? '') as String,
        'category': (m['category'] ?? '') as String,
      };
    }).toList();
  }

  Future<List<Map<String, String>>> _fetchRecommendedStoryline(
    String category,
  ) async {
    if (category.isEmpty) return [];
    final snap = await _firestore
        .collection('storylinepracticeset')
        .where('sectionid', isEqualTo: widget.section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'View to Students')
        .get();
    return snap.docs.map((d) {
      final m = d.data();
      return {
        'title': (m['practicesettitle'] ?? '') as String,
        'gradelevel': (m['gradelevel'] ?? '') as String,
        'category': (m['category'] ?? '') as String,
      };
    }).toList();
  }

  Widget _buildRecommendationsTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('students')
          .doc(widget.student.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = (snapshot.data?.data() as Map<String, dynamic>?) ?? {};
        final readlevel = (data['readlevel'] ?? '') as String;
        final comprehensionresult =
            (data['comprehensionresult'] ?? '') as String;
        final gradelevelread = (data['gradelevelread'] ?? '') as String;

        final wrColor = _levelColor(readlevel);
        final compColor = _levelColor(comprehensionresult);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Level Summary ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phil-IRI Reading Level Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  if (gradelevelread.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Grade Level Read: $gradelevelread',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Word Recognition',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                      _levelBadge(
                        readlevel.isEmpty ? 'Not assessed' : readlevel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Comprehension',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                      _levelBadge(
                        comprehensionresult.isEmpty
                            ? 'Not assessed'
                            : comprehensionresult,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Phil-IRI Guidance ─────────────────────────────────────────
            if (readlevel.isNotEmpty)
              _guidanceCard(
                icon: _levelIcon(readlevel),
                color: wrColor,
                title: 'Word Recognition — ${_wrTitle(readlevel)}',
                body: _wordReadingGuidance(readlevel),
              ),

            if (readlevel.isNotEmpty) const SizedBox(height: 10),

            if (comprehensionresult.isNotEmpty)
              _guidanceCard(
                icon: _levelIcon(comprehensionresult),
                color: compColor,
                title: 'Comprehension — ${_compTitle(comprehensionresult)}',
                body: _comprehensionGuidance(comprehensionresult),
              ),

            const SizedBox(height: 20),

            // ── Recommended Practice Sets ────────────────────────────────
            const Text(
              'Recommended Practice Sets',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Published sets in this section that match this student\'s reading level.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),

            const SizedBox(height: 16),

            _buildPracticeSetSection(
              sectionTitle:
                  'Word Recognition (${readlevel.isEmpty ? "Not assessed" : readlevel})',
              icon: Icons.spellcheck,
              color: wrColor,
              future: _fetchRecommendedWR(readlevel),
            ),

            const SizedBox(height: 16),

            _buildPracticeSetSection(
              sectionTitle:
                  'Phrases & Sentences (${comprehensionresult.isEmpty ? "Not assessed" : comprehensionresult})',
              icon: Icons.short_text,
              color: compColor,
              future: _fetchRecommendedSentences(comprehensionresult),
            ),

            const SizedBox(height: 16),

            _buildPracticeSetSection(
              sectionTitle:
                  'Storyline (${comprehensionresult.isEmpty ? "Not assessed" : comprehensionresult})',
              icon: Icons.menu_book,
              color: compColor,
              future: _fetchRecommendedStoryline(comprehensionresult),
            ),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  String _wrTitle(String level) {
    switch (level) {
      case 'Frustration':
        return 'Intensive Intervention';
      case 'Instructional':
        return 'Guided Practice';
      case 'Independent':
        return 'Enrichment';
      default:
        return '';
    }
  }

  String _compTitle(String level) {
    switch (level) {
      case 'Frustration':
        return 'Comprehension Intervention';
      case 'Instructional':
        return 'Guided Reading Support';
      case 'Independent':
        return 'Independent Enrichment';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Student Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundColor,
        centerTitle: true,
        elevation: 0,
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobile = screenWidth <= 768;

              void onPressed() {
                if (isMobile) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddStudentReadRecordScreen(student: widget.student),
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        AddStudentReadRecordDialog(student: widget.student),
                  );
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobile
                    ? IconButton(
                        icon: const Icon(Icons.upload),
                        tooltip: 'Add Read Record',
                        onPressed: onPressed,
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.upload, size: 20),
                        label: const Text('Add Read Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        onPressed: onPressed,
                      ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('students')
                    .doc(widget.student.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text("Student not found");
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;

                  final firstname = data['firstname'] ?? '';
                  final middlename = data['middlename'] ?? '';
                  final lastname = data['lastname'] ?? '';
                  final lrn = data['lrn'] ?? '';
                  final gender = data['gender'] ?? '';
                  final readlevel = data['readlevel'] ?? '';
                  final status = data['status'] ?? '';

                  return Column(
                    children: [
                      // 🧑‍🎓 Student Name
                      Text(
                        "$firstname $middlename $lastname",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // 📘 Student LRN
                      Text(
                        lrn,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // 🚻 Student Gender
                      Text(
                        gender,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // 📊 Reading Level
                      Text(
                        readlevel,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // 🧾 Student Status
                      Text(
                        status,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 🧩 Choice Chips for Tabs
            _buildFilterButtons(),
            const SizedBox(height: 16),

            // 🪶 Selected Tab Content (uses StreamBuilder too)
            Expanded(child: _buildSelectedTab()),
          ],
        ),
      ),
    );
  }
}
