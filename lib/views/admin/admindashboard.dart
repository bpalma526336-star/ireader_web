import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/practice_set/select_practice_set.dart';
import 'package:ireader_web/views/admin/readingcoordinator/manage_rc.dart';
import 'package:ireader_web/views/admin/schoolyear/manage_schoolyear.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';
import 'package:ireader_web/model/student.dart';
import 'dart:html' as html;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Range selection
  SchoolYear? _startYear;
  SchoolYear? _endYear;
  String? _startYearId;
  String? _endYearId;

  /// 🔹 Analysis state
  bool _loadingAnalysis = false;

  /// yearId -> counts
  Map<String, Map<String, int>> _rangeCounts = {};
  List<SchoolYear> _selectedRangeYears = [];

  /// yearId -> level -> gender -> count
  Map<String, Map<String, Map<String, int>>> _genderCounts = {};

  /// 🔹 Stream subscriptions for real-time updates
  List<StreamSubscription> _subscriptions = [];
  final List<String> studentreads = ["Overall Result", "Comprehension Result"];
  String _selectedReadType = "Overall Result";

  // =========================================================
  // FETCH SCHOOL YEARS
  // =========================================================

  @override
  void initState() {
    super.initState();
    _autoLoadDashboard();
    _setupRealTimeSync();
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _setupRealTimeSync() {
    // Listen to students collection for real-time updates
    final studentsStream = _firestore.collection('students').snapshots();

    final studentsSubscription = studentsStream.listen(
      (snapshot) {
        // When students data changes, refresh the analysis
        if (_selectedRangeYears.isNotEmpty) {
          _refreshAnalysis();
        }
      },
      onError: (error) {
        debugPrint("Real-time sync error: $error");
      },
    );

    _subscriptions.add(studentsSubscription);

    // Also listen to schoolyears changes
    final schoolYearsStream = _firestore.collection('schoolyears').snapshots();

    final schoolYearsSubscription = schoolYearsStream.listen(
      (snapshot) {
        // When school years change, refresh the entire dashboard
        _autoLoadDashboard();
      },
      onError: (error) {
        debugPrint("School years sync error: $error");
      },
    );

    _subscriptions.add(schoolYearsSubscription);
  }

  Future<void> _refreshAnalysis() async {
    if (_selectedRangeYears.isNotEmpty) {
      await _analyzeRange(_selectedRangeYears);
      if (mounted) {
        setState(() {}); // Trigger UI rebuild with new data
      }
    }
  }

  Stream<List<SchoolYear>> _fetchSchoolYears() {
    return _firestore
        .collection('schoolyears')
        .orderBy('schoolyearstart')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SchoolYear.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> _autoLoadDashboard() async {
    setState(() => _loadingAnalysis = true);

    final snap = await _firestore
        .collection('schoolyears')
        .orderBy('schoolyearstart')
        .get();

    if (snap.docs.isEmpty) {
      setState(() => _loadingAnalysis = false);
      return;
    }

    final years = snap.docs
        .map((d) => SchoolYear.fromMap(d.id, d.data()))
        .toList();

    years.sort(
      (a, b) =>
          int.parse(a.schoolyearstart).compareTo(int.parse(b.schoolyearstart)),
    );

    _startYear = years.first;
    _endYear = years.last;

    _startYearId = _startYear!.id;
    _endYearId = _endYear!.id;

    await _analyzeRange(years);

    setState(() => _loadingAnalysis = false);
  }

  // =========================================================
  // COUNT STUDENTS PER LEVEL WITH REAL-TIME STREAM
  // =========================================================
  Future<Map<String, int>> _computeCounts(String schoolyearId) async {
    // Use a more efficient query
    final snap = await _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearId)
        .where('status', isEqualTo: 'ACTIVE')
        .get();

    int frustration = 0;
    int instructional = 0;
    int independent = 0;

    // Initialize gender counts if not exists
    if (!_genderCounts.containsKey(schoolyearId)) {
      _genderCounts[schoolyearId] = {
        'Frustration': {'Male': 0, 'Female': 0},
        'Instructional': {'Male': 0, 'Female': 0},
        'Independent': {'Male': 0, 'Female': 0},
      };
    } else {
      // Reset gender counts for this school year
      _genderCounts[schoolyearId] = {
        'Frustration': {'Male': 0, 'Female': 0},
        'Instructional': {'Male': 0, 'Female': 0},
        'Independent': {'Male': 0, 'Female': 0},
      };
    }

    for (final doc in snap.docs) {
      final student = Student.fromMap(doc.id, doc.data());

      String level = '';

      if (_selectedReadType == "Overall Result") {
        level = student.readlevel;
      } else {
        level = student.comprehensionresult;
      }
      final gender = student.gender ?? '';

      /// 🔥 skip bad data
      if (!_genderCounts[schoolyearId]!.containsKey(level)) continue;
      if (!_genderCounts[schoolyearId]![level]!.containsKey(gender)) continue;

      if (level == 'Frustration') frustration++;
      if (level == 'Instructional') instructional++;
      if (level == 'Independent') independent++;

      _genderCounts[schoolyearId]![level]![gender] =
          (_genderCounts[schoolyearId]![level]![gender] ?? 0) + 1;
    }

    return {
      'Frustration': frustration,
      'Instructional': instructional,
      'Independent': independent,
    };
  }

  // =========================================================
  // ANALYZE RANGE WITH OPTIMIZED BATCH PROCESSING
  // =========================================================
  Future<void> _analyzeRange(List<SchoolYear> years) async {
    _rangeCounts.clear();
    _genderCounts.clear();

    try {
      // Process years in parallel for better performance
      final List<Future> futures = [];

      for (final y in years) {
        futures.add(
          _computeCounts(y.id).then((counts) {
            _rangeCounts[y.id] = counts;
          }),
        );
      }

      await Future.wait(futures);

      _selectedRangeYears = years;

      // Trigger UI update
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("ANALYZE ERROR: $e");
    }
  }

  // =========================================================
  // BUILD BAR CHART
  // =========================================================
  String _buildMultiYearChartUrl(bool isMobile) {
    final labels = ['Frustration', 'Instructional', 'Independent'];
    final datasets = <Map<String, dynamic>>[];

    // Color palette (no red or pink shades)
    final colors = [
      '#4285F4', // Blue
      '#34A853', // Green
      '#7E57C2', // Purple
      '#FBBC05', // Orange
      '#26A69A', // Teal
      '#8D6E63', // Brown
      '#00ACC1', // Cyan
      '#7CB342', // Lime
    ];

    for (int i = 0; i < _selectedRangeYears.length; i++) {
      final y = _selectedRangeYears[i];
      final counts = _rangeCounts[y.id] ?? {};
      final color = colors[i % colors.length];

      datasets.add({
        'label': '${y.schoolyearstart}-${y.schoolyearend}',
        'data': labels.map((l) => counts[l] ?? 0).toList(),
        'backgroundColor': '${color}CC',
        'borderColor': color,
        'borderWidth': 2,
      });
    }

    final chart = {
      'type': 'bar',
      'data': {'labels': labels, 'datasets': datasets},
      'options': {
        'plugins': {
          'legend': {
            'labels': {
              'font': {'size': isMobile ? 16 : 14},
            },
          },
        },
        'scales': {
          'x': {
            'ticks': {
              'font': {'size': isMobile ? 16 : 12},
            },
          },
          'y': {
            'beginAtZero': true,
            'ticks': {
              'font': {'size': isMobile ? 16 : 12},
            },
          },
        },
      },
    };

    final width = isMobile ? 900 : 1000;
    final height = isMobile ? 600 : 420;

    return 'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chart))}&width=$width&height=$height';
  }

  String _buildGenderChartUrl(String gender, bool isMobile) {
    final labels = ['Frustration', 'Instructional', 'Independent'];
    final datasets = <Map<String, dynamic>>[];

    // Color palette (no red or pink shades)
    final colors = [
      '#4285F4', // Blue
      '#34A853', // Green
      '#7E57C2', // Purple
      '#FBBC05', // Orange
      '#26A69A', // Teal
      '#8D6E63', // Brown
      '#00ACC1', // Cyan
      '#7CB342', // Lime
    ];

    for (int i = 0; i < _selectedRangeYears.length; i++) {
      final y = _selectedRangeYears[i];
      final counts = _genderCounts[y.id] ?? {};
      final color = colors[i % colors.length];

      datasets.add({
        'label': '${y.schoolyearstart}-${y.schoolyearend}',
        'data': labels.map((l) => counts[l]?[gender] ?? 0).toList(),
        'backgroundColor': '${color}CC', // Slight transparency
        'borderColor': color,
        'borderWidth': 2,
      });
    }

    final chart = {
      'type': 'bar',
      'data': {'labels': labels, 'datasets': datasets},
      'options': {
        'plugins': {
          'legend': {
            'labels': {
              'font': {'size': isMobile ? 16 : 12},
            },
          },
        },
        'scales': {
          'x': {
            'ticks': {
              'font': {'size': isMobile ? 16 : 12},
            },
          },
          'y': {
            'beginAtZero': true,
            'ticks': {
              'font': {'size': isMobile ? 16 : 12},
            },
          },
        },
      },
    };

    final width = isMobile ? 800 : 600;
    final height = isMobile ? 550 : 350;

    return 'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chart))}&width=$width&height=$height';
  }

  // =========================================================
  // WINNERS TEXT
  // =========================================================
  Widget _buildWinnersWidget() {
    final labels = ['Frustration', 'Instructional', 'Independent'];

    List<Widget> children = [];

    // =========================================================
    // 1️⃣ WINNERS PER LEVEL (your existing logic improved)
    // =========================================================
    for (final level in labels) {
      int max = 0;
      SchoolYear? winner;

      for (final y in _selectedRangeYears) {
        final value = _rangeCounts[y.id]?[level] ?? 0;

        if (value > max) {
          max = value;
          winner = y;
        }
      }

      String text;

      if (winner == null || max == 0) {
        text = "$level → No records yet";
      } else {
        text =
            "$level → Most students in ${winner.schoolyearstart}-${winner.schoolyearend}";
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    // =========================================================
    // 2️⃣ 🔥 NEW TREND ANALYTICS SECTION
    // =========================================================

    // =========================================================
    // 🔥 NEW DESCRIPTIVE TREND ANALYTICS
    // =========================================================
    if (_selectedRangeYears.length >= 2) {
      final first = _selectedRangeYears.first;
      final last = _selectedRangeYears.last;

      final firstCounts = _rangeCounts[first.id] ?? {};
      final lastCounts = _rangeCounts[last.id] ?? {};

      int firstTotal = _total(firstCounts);
      int lastTotal = _total(lastCounts);

      int firstInd = firstCounts['Independent'] ?? 0;
      int lastInd = lastCounts['Independent'] ?? 0;

      int firstFru = firstCounts['Frustration'] ?? 0;
      int lastFru = lastCounts['Frustration'] ?? 0;

      // percentages
      double firstIndP = _percent(firstInd, firstTotal);
      double lastIndP = _percent(lastInd, lastTotal);

      double firstFruP = _percent(firstFru, firstTotal);
      double lastFruP = _percent(lastFru, lastTotal);

      // average independent across years
      double avgIndependent =
          _selectedRangeYears
              .map((y) {
                final c = _rangeCounts[y.id] ?? {};
                return _percent(c['Independent'] ?? 0, _total(c));
              })
              .reduce((a, b) => a + b) /
          _selectedRangeYears.length;

      String insight;

      if (lastIndP > firstIndP) {
        insight =
            "$_selectedReadType performance shows an improving trend. Independent readers increased from "
            "${firstIndP.toStringAsFixed(1)}% to ${lastIndP.toStringAsFixed(1)}%, averaging "
            "${avgIndependent.toStringAsFixed(1)}% across the selected school years. "
            "This suggests that more students are reaching higher reading proficiency levels over time. Sustaining this positive trend may require continued reading support programs, increased access to engaging reading materials, and consistent practice opportunities for learners.";
      } else if (lastFruP < firstFruP) {
        insight =
            "$_selectedReadType performance shows a declining trend. Frustration level students increased from "
            "${firstFruP.toStringAsFixed(1)}% to ${lastFruP.toStringAsFixed(1)}%, indicating learning difficulties. "
            "The rise in struggling readers suggests the need for additional instructional support and intervention.";
      } else {
        insight =
            "$_selectedReadType performance remains relatively stable across the selected years. Independent readers average "
            "${avgIndependent.toStringAsFixed(1)}% of the population with minimal variation. "
            "This indicates consistent but limited improvement in overall reading proficiency. Continued enrichment activities and regular reading engagement may help sustain this stability while encouraging further improvement in literacy performance.";
      }

      children.add(const SizedBox(height: 20));
      children.add(const Divider());

      children.add(
        Text(
          "Overall Insights",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );

      children.add(const SizedBox(height: 8));

      children.add(
        Text(
          insight,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.justify,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  double _percent(int value, int total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  int _total(Map<String, int> counts) {
    return (counts['Frustration'] ?? 0) +
        (counts['Instructional'] ?? 0) +
        (counts['Independent'] ?? 0);
  }

  Widget _buildGenderWinnersWidget(String gender) {
    final labels = ['Frustration', 'Instructional', 'Independent'];

    List<Widget> children = [];

    // =========================================================
    // 1️⃣ WINNERS PER LEVEL (existing behavior)
    // =========================================================
    for (final level in labels) {
      int max = 0;
      SchoolYear? winner;

      for (final y in _selectedRangeYears) {
        final value = _genderCounts[y.id]?[level]?[gender] ?? 0;

        if (value > max) {
          max = value;
          winner = y;
        }
      }

      String text;

      if (winner == null || max == 0) {
        text = "$level → No $gender records yet";
      } else {
        text =
            "$level → Most $gender students in ${winner.schoolyearstart}-${winner.schoolyearend}";
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      );
    }

    // =========================================================
    // 2️⃣ 🔥 NEW GENDER TREND ANALYTICS
    // =========================================================
    if (_selectedRangeYears.length >= 2) {
      final first = _selectedRangeYears.first;
      final last = _selectedRangeYears.last;

      final firstCounts = _genderCounts[first.id] ?? {};
      final lastCounts = _genderCounts[last.id] ?? {};

      int firstTotal =
          (firstCounts['Frustration']?[gender] ?? 0) +
          (firstCounts['Instructional']?[gender] ?? 0) +
          (firstCounts['Independent']?[gender] ?? 0);

      int lastTotal =
          (lastCounts['Frustration']?[gender] ?? 0) +
          (lastCounts['Instructional']?[gender] ?? 0) +
          (lastCounts['Independent']?[gender] ?? 0);

      double firstIndP = _percent(
        firstCounts['Independent']?[gender] ?? 0,
        firstTotal,
      );
      double lastIndP = _percent(
        lastCounts['Independent']?[gender] ?? 0,
        lastTotal,
      );

      double avgInd =
          _selectedRangeYears
              .map((y) {
                final c = _genderCounts[y.id] ?? {};
                final total =
                    (c['Frustration']?[gender] ?? 0) +
                    (c['Instructional']?[gender] ?? 0) +
                    (c['Independent']?[gender] ?? 0);

                return _percent(c['Independent']?[gender] ?? 0, total);
              })
              .reduce((a, b) => a + b) /
          _selectedRangeYears.length;

      String insight;

      if (lastIndP > firstIndP) {
        insight =
            "$gender students show an improving reading trend. Independent readers increased from "
            "${firstIndP.toStringAsFixed(1)}% to ${lastIndP.toStringAsFixed(1)}%, with an average of "
            "${avgInd.toStringAsFixed(1)}% across the selected years. This indicates steady progress in reading ability for this group. Sustaining this positive trend may require continued reading support programs, increased access to engaging reading materials, and consistent practice opportunities for learners.";
      } else if (lastIndP < firstIndP) {
        insight =
            "$gender students show a slight decline in performance. Independent readers decreased from "
            "${firstIndP.toStringAsFixed(1)}% to ${lastIndP.toStringAsFixed(1)}%. Additional targeted support may help improve literacy outcomes.";
      } else {
        insight =
            "$gender students maintain a stable performance. Independent readers average "
            "${avgInd.toStringAsFixed(1)}% with minimal fluctuation across the years, indicating consistent achievement levels. Continued enrichment activities and regular reading engagement may help sustain this stability while encouraging further improvement in literacy performance.";
      }

      children.add(const SizedBox(height: 10));
      children.add(const Divider());

      children.add(
        Text(
          insight,
          style: const TextStyle(fontSize: 13),
          textAlign: TextAlign.justify,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildstartDropdown(List<SchoolYear> schoolYears) {
    return DropdownButtonFormField<String>(
      value: _startYearId,
      decoration: const InputDecoration(
        labelText: 'Start Year',
        border: OutlineInputBorder(),
      ),
      items: schoolYears
          .map(
            (sy) => DropdownMenuItem(
              value: sy.id,
              child: Text('${sy.schoolyearstart}-${sy.schoolyearend}'),
            ),
          )
          .toList(),
      onChanged: (v) {
        setState(() {
          _startYearId = v;
          _startYear = schoolYears.firstWhere((s) => s.id == v);
        });
      },
    );
  }

  Widget _buildendDropdown(List<SchoolYear> schoolYears) {
    return DropdownButtonFormField<String>(
      value: _endYearId,
      decoration: const InputDecoration(
        labelText: 'End Year',
        border: OutlineInputBorder(),
      ),
      items: schoolYears
          .map(
            (sy) => DropdownMenuItem(
              value: sy.id,
              child: Text('${sy.schoolyearstart}-${sy.schoolyearend}'),
            ),
          )
          .toList(),
      onChanged: (v) {
        setState(() {
          _endYearId = v;
          _endYear = schoolYears.firstWhere((s) => s.id == v);
        });
      },
    );
  }

  Widget _generateButton(List<SchoolYear> schoolYears) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () async {
        if (_startYear == null || _endYear == null) return;

        setState(() => _loadingAnalysis = true);

        final startVal = int.parse(_startYear!.schoolyearstart);
        final endVal = int.parse(_endYear!.schoolyearstart);

        final years = schoolYears.where((y) {
          final yVal = int.parse(y.schoolyearstart);
          return yVal >= startVal && yVal <= endVal;
        }).toList();

        await _analyzeRange(years);

        setState(() => _loadingAnalysis = false);
      },
      child: const Text(
        "Generate Results",
        style: TextStyle(color: AppTheme.backgroundColor),
      ),
    );
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
              onTap: () async {
                setState(() {
                  _selectedReadType = type;
                  _loadingAnalysis = true;
                });

                if (_selectedRangeYears.isNotEmpty) {
                  await _analyzeRange(_selectedRangeYears);
                }

                if (mounted) {
                  setState(() {
                    _loadingAnalysis = false;
                  });
                }
              },
              // onTap: () {
              //   setState(() {
              //     _selectedReadType = type;
              //   });
              // },
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

  // Widget _buildResultDropdown() {
  //   return DropdownButtonFormField<String>(
  //     value: _selectedReadType,
  //     decoration: const InputDecoration(
  //       labelText: "Result Type",
  //       border: OutlineInputBorder(),
  //     ),
  //     items: studentreads
  //         .map((type) => DropdownMenuItem(value: type, child: Text(type)))
  //         .toList(),
  //     onChanged: (value) {
  //       setState(() {
  //         _selectedReadType = value!;
  //       });

  //       if (_selectedRangeYears.isNotEmpty) {
  //         _refreshAnalysis();
  //       }
  //     },
  //   );
  // }

  Widget _buildOverviewCard(bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedReadType == "Overall Result"
                  ? "Reading Level Overview"
                  : "Comprehension Level Overview",
              style: TextStyle(
                fontSize: isMobile ? 20 : 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "This shows which school year has the most students per reading level.",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            _buildWinnersWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllStudentsCard(bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "All Students",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Image.network(
              _buildMultiYearChartUrl(isMobile),
              height: isMobile ? 260 : 420,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: isMobile ? 260 : 420,
                  color: Colors.grey[200],
                  child: const Center(child: Text('Chart loading...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard(String gender, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "$gender Students",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Image.network(
              _buildGenderChartUrl(gender, isMobile),
              height: isMobile ? 220 : 350,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: isMobile ? 220 : 350,
                  color: Colors.grey[200],
                  child: const Center(child: Text('Chart loading...')),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(height: 24),
            const Center(
              child: Text(
                "Insights",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _buildGenderWinnersWidget(gender),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final isMobile = screenWidth <= 480;
    final isTablet = screenWidth > 480 && screenWidth <= 900;

    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.backgroundColor),

      // =====================================================
      // 🔥 NEW ANALYTICS BODY
      // =====================================================
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.backgroundColor),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Image.asset(
                      'assets/images/Department-of-Education-DepEd-Seal-300x300.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'iReader',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard,
                color: AppTheme.primaryColor,
              ),
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(fontSize: 20, color: AppTheme.primaryColor),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboard(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Set Up',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageSchoolyearScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageAdminScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.integration_instructions,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Reading Coordinators',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageRcScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Teachers',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageTeacherScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Log Out',
                style: TextStyle(fontSize: 20, color: Colors.redAccent),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                html.window.history.pushState(null, '', '');
                html.window.onPopState.listen((event) {
                  html.window.history.pushState(null, '', '');
                });
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: StreamBuilder<List<SchoolYear>>(
          stream: _fetchSchoolYears(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            final schoolYears = snapshot.data!;

            // Auto-update dropdown values if they're not set
            if (_startYear == null && schoolYears.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _autoLoadDashboard();
              });
            }

            return Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 24),

              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Dashboard Analytics",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      // Real-time indicator
                    ],
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // YEAR SELECTORS
                  // =================================================
                  isMobile
                      ? Column(
                          children: [
                            // _buildResultDropdown(),
                            // const SizedBox(height: 12),
                            _buildstartDropdown(schoolYears),
                            const SizedBox(height: 12),
                            _buildendDropdown(schoolYears),
                            const SizedBox(height: 12),
                            _generateButton(schoolYears),

                            const SizedBox(height: 16),
                            _buildResultToggle(),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                // Expanded(child: _buildResultDropdown()),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _startYearId,
                                    decoration: const InputDecoration(
                                      labelText: 'Start Year',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: schoolYears
                                        .map(
                                          (sy) => DropdownMenuItem(
                                            value: sy.id,
                                            child: Text(
                                              '${sy.schoolyearstart}-${sy.schoolyearend}',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        _startYearId = v;
                                        _startYear = schoolYears.firstWhere(
                                          (s) => s.id == v,
                                        );
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _endYearId,
                                    decoration: const InputDecoration(
                                      labelText: 'End Year',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: schoolYears
                                        .map(
                                          (sy) => DropdownMenuItem(
                                            value: sy.id,
                                            child: Text(
                                              '${sy.schoolyearstart}-${sy.schoolyearend}',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        _endYearId = v;
                                        _endYear = schoolYears.firstWhere(
                                          (s) => s.id == v,
                                        );
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(width: 12),

                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                  ),
                                  onPressed: () async {
                                    if (_startYear == null || _endYear == null)
                                      return;

                                    final int startVal =
                                        int.tryParse(
                                          _startYear!.schoolyearstart,
                                        ) ??
                                        0;
                                    final int endVal =
                                        int.tryParse(
                                          _endYear!.schoolyearstart,
                                        ) ??
                                        0;

                                    // 🔥 INVALID RANGE CHECK
                                    if (startVal >= endVal) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Invalid Range"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return; // ⛔ stop execution
                                    }

                                    setState(() => _loadingAnalysis = true);

                                    final years = schoolYears.where((y) {
                                      final yVal =
                                          int.tryParse(y.schoolyearstart) ?? 0;
                                      return yVal >= startVal && yVal <= endVal;
                                    }).toList();

                                    await _analyzeRange(years);

                                    setState(() => _loadingAnalysis = false);
                                  },

                                  child: const Text(
                                    "Generate Results",
                                    style: TextStyle(
                                      color: AppTheme.backgroundColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildResultToggle(),
                          ],
                        ),

                  const SizedBox(height: 28),

                  // =================================================
                  // RESULTS
                  // =================================================
                  Expanded(
                    child: _loadingAnalysis
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                /// =========================================
                                /// 🔥 HERO SECTION (LEFT TEXT | RIGHT CHART)
                                /// =========================================
                                /// isMobile
                                isMobile
                                    ? Column(
                                        children: [
                                          _buildOverviewCard(isMobile),
                                          const SizedBox(height: 16),
                                          _buildAllStudentsCard(isMobile),
                                        ],
                                      )
                                    : Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          /// LEFT SIDE (Header + Winners)
                                          Expanded(
                                            flex: 1,
                                            child: Card(
                                              elevation: 3,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                  isMobile ? 12 : 24,
                                                ),

                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${_selectedReadType} Overview",
                                                      style: const TextStyle(
                                                        fontSize: 26,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppTheme
                                                            .primaryColor,
                                                      ),
                                                    ),

                                                    const SizedBox(height: 8),

                                                    Text(
                                                      "This shows which school year has the most students per ${_selectedReadType} level.",
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),

                                                    const SizedBox(height: 24),

                                                    _buildWinnersWidget(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 20),

                                          /// RIGHT SIDE (BIG ALL STUDENTS CHART)
                                          Expanded(
                                            flex: 2,
                                            child: Card(
                                              elevation: 3,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                  isMobile ? 12 : 24,
                                                ),

                                                child: Column(
                                                  children: [
                                                    const Text(
                                                      "All Students",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Image.network(
                                                      _buildMultiYearChartUrl(
                                                        isMobile,
                                                      ),
                                                      height: isMobile
                                                          ? 320
                                                          : 420,
                                                      fit: BoxFit.contain,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Container(
                                                              height: isMobile
                                                                  ? 320
                                                                  : 420,
                                                              color: Colors
                                                                  .grey[200],
                                                              child: const Center(
                                                                child: Text(
                                                                  'Chart loading...',
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                const SizedBox(height: 24),

                                /// =========================================
                                /// 🔥 GENDER SECTION
                                /// =========================================
                                /// isMobile
                                isMobile
                                    ? Column(
                                        children: [
                                          _buildGenderCard('Male', isMobile),
                                          const SizedBox(height: 16),
                                          _buildGenderCard('Female', isMobile),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: Card(
                                              elevation: 3,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                  isMobile ? 12 : 24,
                                                ),

                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Center(
                                                      child: const Text(
                                                        "Male Students",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),

                                                    const SizedBox(height: 10),

                                                    Image.network(
                                                      _buildGenderChartUrl(
                                                        'Male',
                                                        isMobile,
                                                      ),
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Container(
                                                              height: 350,
                                                              color: Colors
                                                                  .grey[200],
                                                              child: const Center(
                                                                child: Text(
                                                                  'Chart loading...',
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                    ),

                                                    const SizedBox(height: 16),
                                                    const Divider(height: 24),
                                                    Center(
                                                      child: const Text(
                                                        "Insights",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),

                                                    const SizedBox(height: 8),

                                                    _buildGenderWinnersWidget(
                                                      'Male',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 16),

                                          Expanded(
                                            child: Card(
                                              elevation: 3,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                  isMobile ? 12 : 24,
                                                ),

                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Center(
                                                      child: const Text(
                                                        "Female Students",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),

                                                    const SizedBox(height: 10),

                                                    Image.network(
                                                      _buildGenderChartUrl(
                                                        'Female',
                                                        isMobile,
                                                      ),
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Container(
                                                              height: 350,
                                                              color: Colors
                                                                  .grey[200],
                                                              child: const Center(
                                                                child: Text(
                                                                  'Chart loading...',
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                    ),

                                                    const SizedBox(height: 16),
                                                    const Divider(height: 24),

                                                    Center(
                                                      child: const Text(
                                                        "Insights",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),

                                                    const SizedBox(height: 8),

                                                    _buildGenderWinnersWidget(
                                                      'Female',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
