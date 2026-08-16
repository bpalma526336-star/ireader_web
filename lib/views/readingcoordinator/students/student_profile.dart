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
import 'package:ireader_web/views/readingcoordinator/students/studentcompresultdetails.dart';

class RCStudentProfileScreen extends StatefulWidget {
  final Student student;
  final SchoolYear schoolyear;
  final Section section;

  const RCStudentProfileScreen({
    super.key,
    required this.student,
    required this.schoolyear,
    required this.section,
  });

  @override
  State<RCStudentProfileScreen> createState() => _RCStudentProfileScreenState();
}

// ─── Insight model ─────────────────────────────────────────────────────────

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

// ─── State ─────────────────────────────────────────────────────────────────

class _RCStudentProfileScreenState extends State<RCStudentProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedFilter = 0;
  int _selectedPracticeset =
      0; // 0 = Word Recognition, 1 = Phrase and Sentences, 2 = Storyline Adventure

  // ─── Avatar helpers ────────────────────────────────────────────────────────

  static const _avatarColors = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  Color _avatarColor(String name) {
    if (name.isEmpty) return _avatarColors[0];
    return _avatarColors[name.codeUnitAt(0) % _avatarColors.length];
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  // ─── Firestore helpers ─────────────────────────────────────────────────────

  Future<String> _getAssessmentName(String assessmentid) async {
    try {
      final doc = await _firestore
          .collection('assessment')
          .doc(assessmentid)
          .get();
      if (doc.exists) return doc['assessmenttitle'] ?? 'Unnamed Assessment';
      return 'Unknown Assessment';
    } catch (_) {
      return 'Unknown Assessment';
    }
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

  // ─── Profile header card ───────────────────────────────────────────────────

  Widget _buildProfileCard(Map<String, dynamic> data) {
    final firstname = data['firstname'] ?? '';
    final middlename = data['middlename'] ?? '';
    final lastname = data['lastname'] ?? '';
    final lrn = data['lrn'] ?? '';
    final gender = data['gender'] ?? '';
    final readlevel = data['readlevel'] ?? '';
    final status = data['status'] ?? '';
    final gradelevelread = data['gradelevelread'] ?? '';

    final fullName =
        '$firstname${middlename.isNotEmpty ? " $middlename" : ""} $lastname'
            .trim();
    final initial = lastname.isNotEmpty ? lastname[0].toUpperCase() : 'S';
    final avatarColor = _avatarColor(lastname);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LRN: $lrn',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _readingLevelBadge(readlevel),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'ACTIVE'
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: status == 'ACTIVE'
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF991B1B),
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
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderColor, height: 1),
          const SizedBox(height: 16),
          // Info grid
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _infoChip(Icons.wc, 'Gender', gender),
              _infoChip(
                Icons.school,
                'Grade Level',
                gradelevelread.isEmpty ? '—' : gradelevelread,
              ),
              _infoChip(Icons.class_, 'Section', widget.section.sectionname),
              _infoChip(
                Icons.calendar_today,
                'School Year',
                'SY ${widget.schoolyear.schoolyearstart}–${widget.schoolyear.schoolyearend}',
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _infoChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  // Practice Set Tab Selector

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

  // ─── Tab selector ──────────────────────────────────────────────────────────

  Widget _buildFilterButtons() {
    final filters = [
      "Reading Results",
      "Comprehension Results",
      "Overall Results",
      "Activities History",
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(filters.length, (index) {
            final isSelected = _selectedFilter == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                    ),
                  ),
                  child: Text(
                    filters[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Info row helper ───────────────────────────────────────────────────────

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
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
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

  // ─── Insight card ──────────────────────────────────────────────────────────

  Widget _buildInsightCard(CompInsights insight) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comprehension Overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow(
            icon: Icons.arrow_upward,
            label: 'Highest',
            value:
                '${insight.highestStage} (${insight.highest.toStringAsFixed(1)}%)',
            color: Colors.green,
          ),
          _infoRow(
            icon: Icons.arrow_downward,
            label: 'Lowest',
            value: insight.lowest == null || insight.lowestStage == null
                ? "No lowest score"
                : "${insight.lowestStage} (${insight.lowest!.toStringAsFixed(1)}%)",
            color: Colors.redAccent,
          ),
          _infoRow(
            icon: Icons.analytics_outlined,
            label: 'Average',
            value: '${insight.average.toStringAsFixed(1)}%',
            color: AppTheme.secondaryColor,
          ),
          _infoRow(
            icon: Icons.trending_up,
            label: 'Performance',
            value: insight.performanceLevel,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderColor, height: 1),
          const SizedBox(height: 12),
          Text(
            insight.insightMessage,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab content ───────────────────────────────────────────────────────────

  Widget _buildSelectedTab() {
    switch (_selectedFilter) {
      case 0:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('readingresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmpty('No reading results yet.');
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = results[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _getAssessmentName(item.assessmentid),
                        builder: (context, snap) {
                          return Row(
                            children: [
                              const Icon(
                                Icons.assignment_outlined,
                                size: 16,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  snap.data ?? item.assessmentid,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        icon: Icons.warning_amber_rounded,
                        label: 'Total Miscues',
                        value: item.totalmiscues.toString(),
                        color: Colors.redAccent,
                      ),
                      _infoRow(
                        icon: Icons.menu_book_outlined,
                        label: 'Total Words',
                        value: item.totalwordsread.toString(),
                        color: Colors.deepPurple,
                      ),
                      _infoRow(
                        icon: Icons.analytics_outlined,
                        label: 'Reading Result',
                        value: item.totalreadingresult.toString(),
                        color: Colors.green,
                      ),
                      _infoRow(
                        icon: Icons.trending_up,
                        label: 'Reading Level',
                        value: item.readinglevel.toString(),
                        color: Colors.orange,
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
              .collection('comprehensionresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmpty('No comprehension results yet.');
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
            final isSmall = screenWidth <= 768;

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                FutureBuilder<Map<String, String>>(
                  future: _getAssessmentTitles(results),
                  builder: (context, titlesSnap) {
                    if (!titlesSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      );
                    }
                    final titles = titlesSnap.data!;
                    final insight = buildInsights(results, titles);

                    if (isSmall) {
                      return Column(
                        children: [
                          _buildInsightCard(insight),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            child: buildQuickChart(results, titles),
                          ),
                        ],
                      );
                    } else {
                      return SizedBox(
                        height: 380,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildInsightCard(insight),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 3,
                              child: buildQuickChart(results, titles),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                ...results.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String>(
                            future: _getAssessmentName(item.assessmentid),
                            builder: (context, snap) {
                              return Text(
                                snap.data ?? item.assessmentid,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _infoRow(
                            icon: Icons.score_outlined,
                            label: 'Score',
                            value: '${item.resultpercentage}%',
                            color: AppTheme.secondaryColor,
                          ),
                          _infoRow(
                            icon: Icons.bar_chart,
                            label: 'Level',
                            value: item.result,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RCcompresultdetails(compResult: item),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('View Result'),
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

      case 2:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('overallresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmpty('No overall results yet.');
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              itemCount: histories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = histories[index];
                return FutureBuilder<String>(
                  future: _getAssessmentName(item.assessmentid),
                  builder: (context, snap) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.assignment_outlined,
                                size: 16,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  snap.data ?? 'Unknown Assessment',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _infoRow(
                            icon: Icons.menu_book_outlined,
                            label: 'Word Reading',
                            value: item.wordreadresult.toString(),
                            color: Colors.deepPurple,
                          ),
                          _infoRow(
                            icon: Icons.psychology_outlined,
                            label: 'Comprehension',
                            value: item.readcompresult.toString(),
                            color: Colors.green,
                          ),
                          _infoRow(
                            icon: Icons.trending_up,
                            label: 'Reading Level',
                            value: item.readlevel.toString(),
                            color: Colors.orange,
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

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 52,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fullName =
        '${widget.student.firstname}${widget.student.middlename != null && widget.student.middlename!.isNotEmpty ? " ${widget.student.middlename}" : ""} ${widget.student.lastname}';

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
              fullName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Text(
              'Student Profile',
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .doc(widget.student.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Student not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile card
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _buildProfileCard(data),
              ),

              const SizedBox(height: 16),

              // Tab buttons
              _buildFilterButtons(),

              const SizedBox(height: 4),

              Container(height: 1, color: AppTheme.borderColor),

              // Tab content
              Expanded(child: _buildSelectedTab()),
            ],
          );
        },
      ),
    );
  }
}
