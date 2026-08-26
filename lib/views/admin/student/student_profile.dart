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

// ── Domain helpers ─────────────────────────────────────────────────────────────

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
          "With an average score of ${average.toStringAsFixed(1)}%, the student's performance reflects strong and consistent progress in literacy skills.";
    } else if (average >= 59) {
      return "The student demonstrates a moderate level of reading comprehension. "
          "With an average score of ${average.toStringAsFixed(1)}%, the student's performance remains stable and reflects steady reading capabilities.";
    } else {
      return "The student demonstrates a low level of reading comprehension. "
          "With an average score of ${average.toStringAsFixed(1)}%, the student's performance indicates ongoing challenges and a need for further support in text comprehension.";
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

Widget buildQuickChart(
  List<CompAssessmentResult> results,
  Map<String, String> titles,
) {
  final labels = results.map((e) => titles[e.assessmentid] ?? "").toList();
  final scores = results
      .map((e) => double.tryParse(e.resultpercentage) ?? 0.0)
      .toList();

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

// ── Screen ─────────────────────────────────────────────────────────────────────

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedFilter =
      0; // 0 = Reading Results, 1 = Comprehension, 2 = Overall, 3 = Activities History
  int _selectedPracticeset =
      0; // 0 = Word Recognition, 1 = Phrase and Sentences, 2 = Storyline Adventure

  @override
  void initState() {
    super.initState();
  }

  // ── Data helpers ─────────────────────────────────────────────────────────────

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

  // ── UI helpers ───────────────────────────────────────────────────────────────

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
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            "$label:",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readingLevelBadge(String level) {
    Color color;
    switch (level.toLowerCase()) {
      case 'frustration':
        color = AppTheme.levelFrustration;
        break;
      case 'instructional':
        color = AppTheme.levelInstructional;
        break;
      case 'independent':
        color = AppTheme.levelIndependent;
        break;
      default:
        color = AppTheme.textSecondaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    final color = isActive ? Colors.green : AppTheme.textSecondaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Card wrapper shared across the screen
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

  Widget buildInsightCard(CompInsights insight) {
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Comprehension Overview"),
          const SizedBox(height: 16),
          _infoRow(
            icon: Icons.arrow_upward,
            label: "Highest Score",
            value:
                "${insight.highestStage} (${insight.highest.toStringAsFixed(1)}%)",
            color: Colors.green,
          ),
          _infoRow(
            icon: Icons.arrow_downward,
            label: "Lowest Score",
            value: insight.lowest == null || insight.lowestStage == null
                ? "No lowest score"
                : "${insight.lowestStage} (${insight.lowest!.toStringAsFixed(1)}%)",
            color: Colors.redAccent,
          ),
          _infoRow(
            icon: Icons.analytics_outlined,
            label: "Average Score",
            value: "${insight.average.toStringAsFixed(1)}%",
            color: AppTheme.secondaryColor,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Performance:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 8),
              _readingLevelBadge(insight.performanceLevel),
            ],
          ),
          const Divider(height: 28),
          _sectionHeader("Insights"),
          const SizedBox(height: 8),
          Text(
            insight.insightMessage,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // -- Practice Set filter Buttons
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

  // ── Filter chips ─────────────────────────────────────────────────────────────

  Widget _buildFilterButtons() {
    final filters = [
      "Reading Results",
      "Comprehension Results",
      "Overall Results",
      "Activities History",
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilter == index;
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
              onPressed: () => setState(() => _selectedFilter = index),
              child: Text(filters[index]),
            ),
          );
        }),
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────────

  Widget _buildSelectedTab() {
    switch (_selectedFilter) {
      // Reading Results
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
              return _emptyState("No reading results yet");
            }

            final results = snapshot.data!.docs
                .map(
                  (doc) => StudentReadingresult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = results[index];
                return _cardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _getAssessmentName(item.assessmentid),
                        builder: (context, snap) {
                          final title = snap.data ?? item.assessmentid;
                          return Row(
                            children: [
                              const Icon(
                                Icons.assignment_outlined,
                                size: 18,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                              _readingLevelBadge(item.readinglevel.toString()),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          _statChip(
                            Icons.warning_amber_rounded,
                            "Miscues",
                            item.totalmiscues.toString(),
                            Colors.redAccent,
                          ),
                          _statChip(
                            Icons.menu_book_outlined,
                            "Words",
                            item.totalwordsread.toString(),
                            Colors.deepPurple,
                          ),
                          _statChip(
                            Icons.analytics_outlined,
                            "Score",
                            item.totalreadingresult.toString(),
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

      // Comprehension Results
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
              return _emptyState("No comprehension results yet");
            }

            final results = snapshot.data!.docs
                .map(
                  (doc) => CompAssessmentResult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth <= 768;

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // Insight + chart section
                FutureBuilder<Map<String, String>>(
                  future: _getAssessmentTitles(results),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final titles = snap.data!;
                    final insight = buildInsights(results, titles);

                    if (isSmallScreen) {
                      return Column(
                        children: [
                          buildInsightCard(insight),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: buildQuickChart(results, titles),
                          ),
                        ],
                      );
                    }
                    return SizedBox(
                      height: 420,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: buildInsightCard(insight)),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: buildQuickChart(results, titles),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                _sectionHeader("Assessment Records"),
                const SizedBox(height: 10),

                ...results.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _cardBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String>(
                            future: _getAssessmentName(item.assessmentid),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Text(
                                  "Loading…",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                );
                              }
                              final title = snap.data ?? item.assessmentid;
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                    ),
                                  ),
                                  _readingLevelBadge(item.result),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.score,
                                size: 16,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Score: ${item.resultpercentage}%",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${item.correctitems}/${item.totalitems} correct",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CompResultDetails(compResult: item),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
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
                            child: const Text("View Details"),
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

      // Overall Results
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
              return _emptyState("No overall results yet");
            }

            final histories = snapshot.data!.docs
                .map(
                  (doc) => studentoverallresult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: histories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = histories[index];
                return FutureBuilder<String>(
                  future: _getAssessmentName(item.assessmentid),
                  builder: (context, snap) {
                    final assessmentTitle = snap.data ?? "Unknown Assessment";
                    return _cardBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.assignment_outlined,
                                size: 18,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  assessmentTitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                              _readingLevelBadge(item.readlevel.toString()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: [
                              _statChip(
                                Icons.menu_book_outlined,
                                "Word Reading",
                                item.wordreadresult.toString(),
                                Colors.deepPurple,
                              ),
                              _statChip(
                                Icons.psychology_outlined,
                                "Comprehension",
                                item.readcompresult.toString(),
                                Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );

      case 3:
        return _buildSelectedPracticeSet();

      default:
        return const SizedBox();
    }
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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_outlined,
            color: AppTheme.textPrimaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.student.firstname} ${widget.student.lastname}",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
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
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('Add Read Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: onPressed,
                      ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile header card ─────────────────────────────────────────
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .doc(widget.student.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
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
                final initial = firstname.isNotEmpty
                    ? firstname[0].toUpperCase()
                    : '?';

                return _cardBox(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar circle
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    "$firstname ${middlename.isNotEmpty ? "$middlename " : ""}$lastname",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _statusBadge(status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                _metaChip(Icons.badge_outlined, "LRN: $lrn"),
                                _metaChip(Icons.wc_outlined, gender),
                                _metaChip(
                                  Icons.class_outlined,
                                  widget.section.sectionname,
                                ),
                                _metaChip(
                                  Icons.calendar_today_outlined,
                                  "${widget.schoolyear.schoolyearstart}–${widget.schoolyear.schoolyearend}",
                                ),
                              ],
                            ),
                            if (readlevel.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text(
                                    "Reading Level: ",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  _readingLevelBadge(readlevel),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ── Filter tabs ─────────────────────────────────────────────────
            _buildFilterButtons(),

            const SizedBox(height: 16),

            // ── Tab content ─────────────────────────────────────────────────
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildSelectedTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}
