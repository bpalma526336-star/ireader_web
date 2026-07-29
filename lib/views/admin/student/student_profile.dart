import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentassessmentresult.dart';
import 'package:ireader_web/model/studentoverallresult.dart';
import 'package:ireader_web/model/studentreadingresult.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/student/add_student_read_record.dart';
import 'package:ireader_web/views/admin/student/add_student_read_record_dialog.dart';
import 'package:ireader_web/views/admin/student/studentcompresultdetails.dart';

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
  final double lowest;
  final String highestStage;
  final String lowestStage;
  final bool improving;

  CompInsights({
    required this.average,
    required this.highest,
    required this.lowest,
    required this.highestStage,
    required this.lowestStage,
    required this.improving,
  });

  /// Rubric classification
  String get performanceLevel {
    if (average >= 80) {
      return "High / Increasing";
    } else if (average >= 59) {
      return "Moderate / Stable";
    } else {
      return "Low / Declining";
    }
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
      lowest: 0,
      highestStage: "-",
      lowestStage: "-",
      improving: false,
    );
  }

  final scores = results
      .map((e) => double.tryParse(e.resultpercentage) ?? 0)
      .toList();

  // Same idea as buildQuickChart labels
  final stages = results
      .map((e) => assessmentTitles[e.assessmentid] ?? "")
      .toList();

  double highest = scores.first;
  double lowest = scores.first;

  int highestIndex = 0;
  int lowestIndex = 0;

  for (int i = 0; i < scores.length; i++) {
    if (scores[i] > highest) {
      highest = scores[i];
      highestIndex = i;
    }

    if (scores[i] < lowest) {
      lowest = scores[i];
      lowestIndex = i;
    }
  }

  final average = scores.reduce((a, b) => a + b) / scores.length;

  return CompInsights(
    average: average,
    highest: highest,
    lowest: lowest,
    highestStage: stages[highestIndex],
    lowestStage: stages[lowestIndex],
    improving: scores.last >= scores.first,
  );
}

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

  @override
  void initState() {
    super.initState();
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
              "Lowest Score → ${insight.lowestStage} (${insight.lowest.toStringAsFixed(1)}%)",
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

      default:
        return const SizedBox();
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
