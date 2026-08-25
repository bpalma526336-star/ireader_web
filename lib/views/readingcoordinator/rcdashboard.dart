import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/widgets/rc_sidebar.dart';

class RCDashboard extends StatefulWidget {
  final String? divisionId;
  const RCDashboard({super.key, this.divisionId});

  @override
  State<RCDashboard> createState() => _RCDashboardState();
}

class _RCDashboardState extends State<RCDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Range selection
  SchoolYear? _startYear;
  SchoolYear? _endYear;
  String? _startYearId;
  String? _endYearId;

  // Analysis state
  bool _loadingAnalysis = false;

  // yearId -> counts
  final Map<String, Map<String, int>> _rangeCounts = {};
  List<SchoolYear> _selectedRangeYears = [];

  // yearId -> level -> gender -> count
  final Map<String, Map<String, Map<String, int>>> _genderCounts = {};

  String _selectedReadType = 'Overall Result';
  final List<String> studentreads = ['Overall Result', 'Comprehension Result'];

  // Cached chart URLs — only rebuilt when _analyzeRange completes
  String? _cachedMultiYearUrl;
  String? _cachedMaleUrl;
  String? _cachedFemaleUrl;
  String? _cachedGradeUrl;

  // yearId -> gradeLevel -> readingLevel -> count
  final Map<String, Map<String, Map<String, int>>> _gradeCounts = {};

  static const List<String> _chartColors = [
    '#6366F1',
    '#3B82F6',
    '#10B981',
    '#F59E0B',
    '#EC4899',
    '#8B5CF6',
    '#14B8A6',
    '#F97316',
  ];

  @override
  void initState() {
    super.initState();
    _autoLoadDashboard();
  }

  // =========================================================
  // FETCH SCHOOL YEARS
  // =========================================================
  Stream<List<SchoolYear>> _fetchSchoolYears() {
    return _firestore
        .collection('schoolyears')
        .orderBy('schoolyearstart')
        .snapshots()
        .map(
          (s) => s.docs.map((d) => SchoolYear.fromMap(d.id, d.data())).toList(),
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
      (a, b) => (int.tryParse(a.schoolyearstart) ?? 0).compareTo(
        int.tryParse(b.schoolyearstart) ?? 0,
      ),
    );
    _startYear = years.first;
    _endYear = years.last;
    _startYearId = _startYear!.id;
    _endYearId = _endYear!.id;
    await _analyzeRange(years);
    setState(() => _loadingAnalysis = false);
  }

  // =========================================================
  // COUNT STUDENTS PER LEVEL
  // =========================================================
  Future<Map<String, int>> _computeCounts(String schoolyearId) async {
    final snap = await _firestore
        .collection('students')
        .where('schoolyearid', isEqualTo: schoolyearId)
        .where('status', isEqualTo: 'ACTIVE')
        .get();

    int frustration = 0, instructional = 0, independent = 0;

    _genderCounts[schoolyearId] = {
      'Frustration': {'Male': 0, 'Female': 0},
      'Instructional': {'Male': 0, 'Female': 0},
      'Independent': {'Male': 0, 'Female': 0},
    };
    _gradeCounts[schoolyearId] = {};

    for (final doc in snap.docs) {
      final student = Student.fromMap(doc.id, doc.data());
      final level = _selectedReadType == 'Overall Result'
          ? student.readlevel
          : student.comprehensionresult;
      final gender = student.gender;

      if (!_genderCounts[schoolyearId]!.containsKey(level)) continue;
      if (!_genderCounts[schoolyearId]![level]!.containsKey(gender)) continue;

      if (level == 'Frustration') frustration++;
      if (level == 'Instructional') instructional++;
      if (level == 'Independent') independent++;

      _genderCounts[schoolyearId]![level]![gender] =
          (_genderCounts[schoolyearId]![level]![gender] ?? 0) + 1;

      final grade = student.gradelevelread;
      if (grade.isNotEmpty) {
        _gradeCounts[schoolyearId]!.putIfAbsent(
          grade,
          () => {'Frustration': 0, 'Instructional': 0, 'Independent': 0},
        );
        _gradeCounts[schoolyearId]![grade]![level] =
            (_gradeCounts[schoolyearId]![grade]![level] ?? 0) + 1;
      }
    }

    return {
      'Frustration': frustration,
      'Instructional': instructional,
      'Independent': independent,
    };
  }

  // =========================================================
  // ANALYZE RANGE
  // =========================================================
  Future<void> _analyzeRange(List<SchoolYear> years) async {
    _rangeCounts.clear();
    _genderCounts.clear();
    _gradeCounts.clear();
    await Future.wait(
      years.map(
        (y) => _computeCounts(y.id).then((c) => _rangeCounts[y.id] = c),
      ),
    );
    _selectedRangeYears = years;
    _cachedMultiYearUrl = _buildMultiYearChartUrl();
    _cachedMaleUrl = _buildGenderChartUrl('Male');
    _cachedFemaleUrl = _buildGenderChartUrl('Female');
    _cachedGradeUrl = _buildGradeChartUrl();
    if (mounted) setState(() {});
  }

  // =========================================================
  // BUILD BAR CHART URLs
  // =========================================================
  String _buildMultiYearChartUrl() {
    final labels = ['Frustration', 'Instructional', 'Independent'];
    final datasets = <Map<String, dynamic>>[];

    for (int i = 0; i < _selectedRangeYears.length; i++) {
      final y = _selectedRangeYears[i];
      final counts = _rangeCounts[y.id] ?? {};
      final color = _chartColors[i % _chartColors.length];
      datasets.add({
        'label': '${y.schoolyearstart}-${y.schoolyearend}',
        'data': labels.map((l) => counts[l] ?? 0).toList(),
        'backgroundColor': color,
        'borderWidth': 0,
        'borderRadius': 4,
        'borderSkipped': false,
      });
    }

    final chart = {
      'type': 'bar',
      'data': {'labels': labels, 'datasets': datasets},
      'options': {
        'backgroundColor': '#FFFFFF',
        'plugins': {
          'legend': {
            'position': 'top',
            'labels': {
              'font': {'size': 12, 'family': 'Inter, sans-serif'},
              'usePointStyle': true,
              'pointStyle': 'circle',
              'padding': 20,
            },
          },
          'datalabels': {
            'anchor': 'end',
            'align': 'top',
            'font': {'size': 11, 'weight': 'bold'},
            'color': '#374151',
            'formatter': "function(v){return v>0?v:'';}",
          },
        },
        'scales': {
          'x': {
            'grid': {'display': false},
            'ticks': {
              'font': {'size': 12},
              'color': '#64748B',
            },
          },
          'y': {
            'beginAtZero': true,
            'grid': {'color': '#F1F5F9'},
            'ticks': {
              'font': {'size': 11},
              'color': '#94A3B8',
              'stepSize': 1,
            },
            'border': {
              'dash': [4, 4],
            },
          },
        },
        'barPercentage': 0.7,
        'categoryPercentage': 0.8,
      },
    };
    return 'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chart))}&width=1000&height=400&backgroundColor=white';
  }

  String _buildGenderChartUrl(String gender) {
    final labels = ['Frustration', 'Instructional', 'Independent'];
    final datasets = <Map<String, dynamic>>[];

    for (int i = 0; i < _selectedRangeYears.length; i++) {
      final y = _selectedRangeYears[i];
      final counts = _genderCounts[y.id] ?? {};
      final color = _chartColors[i % _chartColors.length];
      datasets.add({
        'label': '${y.schoolyearstart}-${y.schoolyearend}',
        'data': labels.map((l) => counts[l]?[gender] ?? 0).toList(),
        'backgroundColor': color,
        'borderWidth': 0,
        'borderRadius': 4,
        'borderSkipped': false,
      });
    }

    final chart = {
      'type': 'bar',
      'data': {'labels': labels, 'datasets': datasets},
      'options': {
        'backgroundColor': '#FFFFFF',
        'plugins': {
          'legend': {
            'position': 'top',
            'labels': {
              'font': {'size': 11, 'family': 'Inter, sans-serif'},
              'usePointStyle': true,
              'pointStyle': 'circle',
              'padding': 16,
            },
          },
          'datalabels': {
            'anchor': 'end',
            'align': 'top',
            'font': {'size': 10, 'weight': 'bold'},
            'color': '#374151',
            'formatter': "function(v){return v>0?v:'';}",
          },
        },
        'scales': {
          'x': {
            'grid': {'display': false},
            'ticks': {
              'font': {'size': 11},
              'color': '#64748B',
            },
          },
          'y': {
            'beginAtZero': true,
            'grid': {'color': '#F1F5F9'},
            'ticks': {
              'font': {'size': 10},
              'color': '#94A3B8',
              'stepSize': 1,
            },
            'border': {
              'dash': [4, 4],
            },
          },
        },
        'barPercentage': 0.7,
        'categoryPercentage': 0.8,
      },
    };
    return 'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chart))}&width=700&height=340&backgroundColor=white';
  }

  // =========================================================
  // HELPERS
  // =========================================================
  double _percent(int value, int total) =>
      total == 0 ? 0 : (value / total) * 100;

  int _total(Map<String, int> counts) =>
      (counts['Frustration'] ?? 0) +
      (counts['Instructional'] ?? 0) +
      (counts['Independent'] ?? 0);

  // =========================================================
  // STAT CARDS (StreamBuilder pattern)
  // =========================================================
  Widget _buildStatCards(List<SchoolYear> allYears) {
    int totalStudents = 0;
    int totalIndependent = 0;
    String topYear = '—';
    int topCount = 0;

    for (final y in _selectedRangeYears) {
      final counts = _rangeCounts[y.id] ?? {};
      totalStudents += _total(counts);
      totalIndependent += counts['Independent'] ?? 0;
      final ind = counts['Independent'] ?? 0;
      if (ind > topCount) {
        topCount = ind;
        topYear = '${y.schoolyearstart}-${y.schoolyearend}';
      }
    }

    final indRate = totalStudents == 0
        ? 0.0
        : (totalIndependent / totalStudents) * 100;
    final yearsTracked = _selectedRangeYears.length;
    final rangeLabel = yearsTracked == 0
        ? '—'
        : '${_selectedRangeYears.first.schoolyearstart}-${_selectedRangeYears.last.schoolyearend}';

    final cards = [
      (
        label: 'Total Students Assessed',
        value: '$totalStudents',
        sub: '$yearsTracked school ${yearsTracked == 1 ? 'year' : 'years'}',
        color: const Color(0xFF6366F1),
      ),
      (
        label: 'Independent Reading Rate',
        value: '${indRate.toStringAsFixed(1)}%',
        sub: 'across selected range',
        color: const Color(0xFF10B981),
      ),
      (
        label: 'Top Performing Year',
        value: topYear,
        sub: 'highest Independent count',
        color: const Color(0xFF3B82F6),
      ),
      (
        label: 'Years Tracked',
        value: '$yearsTracked',
        sub: rangeLabel,
        color: const Color(0xFFF59E0B),
      ),
    ];

    return Row(
      children: List.generate(cards.length, (i) {
        final c = cards[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < cards.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  c.value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: c.color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.sub,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // =========================================================
  // WINNERS / INSIGHT WIDGET
  // =========================================================
  Widget _buildWinnersWidget() {
    final labels = ['Frustration', 'Instructional', 'Independent'];
    final levelColors = {
      'Frustration': AppTheme.levelFrustration,
      'Instructional': AppTheme.levelInstructional,
      'Independent': AppTheme.levelIndependent,
    };
    final List<Widget> children = [];

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
      final text = winner == null || max == 0
          ? 'No records yet'
          : 'Most students in ${winner.schoolyearstart}-${winner.schoolyearend}';

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: levelColors[level],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (winner != null)
                Text(
                  '$max',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: levelColors[level],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_selectedRangeYears.length >= 2) {
      final first = _selectedRangeYears.first;
      final last = _selectedRangeYears.last;
      final firstCounts = _rangeCounts[first.id] ?? {};
      final lastCounts = _rangeCounts[last.id] ?? {};
      final firstTotal = _total(firstCounts);
      final lastTotal = _total(lastCounts);
      final firstIndP = _percent(firstCounts['Independent'] ?? 0, firstTotal);
      final lastIndP = _percent(lastCounts['Independent'] ?? 0, lastTotal);
      final firstFruP = _percent(firstCounts['Frustration'] ?? 0, firstTotal);
      final lastFruP = _percent(lastCounts['Frustration'] ?? 0, lastTotal);
      final avgInd =
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
            'Independent performance leads at ${lastIndP.toStringAsFixed(1)}% of the selected population, '
            'reflecting an increase compared to the initial period.';
      } else if (lastFruP > firstFruP) {
        insight =
            'Frustration level students increased from ${firstFruP.toStringAsFixed(1)}% to ${lastFruP.toStringAsFixed(1)}%, '
            'highlighting a growth in this student segment over the selected timeframe.';
      } else {
        insight =
            'Performance remains stable, with independent readers averaging ${avgInd.toStringAsFixed(1)}% across the selected years '
            'and showing minimal variance.';
      }

      children.add(const SizedBox(height: 14));
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INSIGHT',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                insight,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimaryColor,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildGenderWinnersWidget(String gender) {
    final labels = ['Frustration', 'Instructional', 'Independent'];
    final List<Widget> children = [];

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
      final text = winner == null || max == 0
          ? '$level → No records'
          : '$level → ${winner.schoolyearstart}-${winner.schoolyearend} ($max)';
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    if (_selectedRangeYears.length >= 2) {
      final first = _selectedRangeYears.first;
      final last = _selectedRangeYears.last;
      final firstCounts = _genderCounts[first.id] ?? {};
      final lastCounts = _genderCounts[last.id] ?? {};
      final firstTotal =
          (firstCounts['Frustration']?[gender] ?? 0) +
          (firstCounts['Instructional']?[gender] ?? 0) +
          (firstCounts['Independent']?[gender] ?? 0);
      final lastTotal =
          (lastCounts['Frustration']?[gender] ?? 0) +
          (lastCounts['Instructional']?[gender] ?? 0) +
          (lastCounts['Independent']?[gender] ?? 0);
      final firstIndP = _percent(
        firstCounts['Independent']?[gender] ?? 0,
        firstTotal,
      );
      final lastIndP = _percent(
        lastCounts['Independent']?[gender] ?? 0,
        lastTotal,
      );
      final avgInd =
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
            'Improving trend — Independent readers increased from ${firstIndP.toStringAsFixed(1)}% to ${lastIndP.toStringAsFixed(1)}%, '
            'averaging ${avgInd.toStringAsFixed(1)}%.';
      } else if (lastIndP < firstIndP) {
        insight =
            'Slight decline — Independent readers decreased from ${firstIndP.toStringAsFixed(1)}% to ${lastIndP.toStringAsFixed(1)}%. '
            'Targeted support may help.';
      } else {
        insight =
            'Stable performance — Independent readers average ${avgInd.toStringAsFixed(1)}% with minimal change.';
      }

      children.add(const SizedBox(height: 10));
      children.add(
        Text(
          insight,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppTheme.textSecondaryColor,
            height: 1.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // =========================================================
  // RESULT TOGGLE
  // =========================================================
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
            onTap: () async {
              if (_selectedReadType == type) return;
              setState(() {
                _selectedReadType = type;
                _loadingAnalysis = true;
              });
              if (_selectedRangeYears.isNotEmpty)
                await _analyzeRange(_selectedRangeYears);
              if (mounted) setState(() => _loadingAnalysis = false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.textPrimaryColor
                      : AppTheme.textSecondaryColor,
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

  // =========================================================
  // YEAR DROPDOWN
  // =========================================================
  Widget _yearDropdown({
    required String label,
    required String? value,
    required List<SchoolYear> years,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondaryColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 42,
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
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
              filled: true,
              fillColor: Colors.white,
            ),
            items: years
                .map(
                  (sy) => DropdownMenuItem(
                    value: sy.id,
                    child: Text(
                      '${sy.schoolyearstart}-${sy.schoolyearend}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CHART CARD
  // =========================================================
  Widget _buildChartCard(String title, String? url, double height) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          if (url == null)
            SizedBox(
              height: height,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          else
            Image.network(
              url,
              height: height,
              width: double.infinity,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  height: height,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => SizedBox(
                height: height,
                child: const Center(
                  child: Text(
                    'Unable to load chart',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // OVERVIEW (LEFT) CARD
  // =========================================================
  Widget _buildLeftOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_selectedReadType Overview',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This shows which school year has the most students per $_selectedReadType level'
            '${_selectedRangeYears.isNotEmpty ? ", from ${_selectedRangeYears.first.schoolyearstart}-${_selectedRangeYears.first.schoolyearend} to ${_selectedRangeYears.last.schoolyearstart}-${_selectedRangeYears.last.schoolyearend}" : ""}.',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildWinnersWidget(),
        ],
      ),
    );
  }

  // =========================================================
  // GENDER CARD
  // =========================================================
  Widget _buildGenderCard(String gender) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$gender Students',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildChartFromCache(
            gender == 'Male' ? _cachedMaleUrl : _cachedFemaleUrl,
            280,
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 8),
          _buildGenderWinnersWidget(gender),
        ],
      ),
    );
  }

  Widget _buildChartFromCache(String? url, double height) {
    if (url == null) {
      return SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: height,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Unable to load chart',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
        ),
      ),
    );
  }

  // ─── PHIL-IRI 2018 DESCRIPTIVE ANALYTICS ─────────────────────────────────

  String _buildGradeChartUrl() {
    final Map<String, Map<String, int>> aggregated = {};
    for (final y in _selectedRangeYears) {
      final yearGrades = _gradeCounts[y.id] ?? {};
      for (final entry in yearGrades.entries) {
        final grade = entry.key;
        final lvls = entry.value;
        aggregated.putIfAbsent(
          grade,
          () => {'Frustration': 0, 'Instructional': 0, 'Independent': 0},
        );
        for (final lEntry in lvls.entries) {
          aggregated[grade]![lEntry.key] =
              (aggregated[grade]![lEntry.key] ?? 0) + lEntry.value;
        }
      }
    }

    final gradeOrder = [
      'Pre-reading',
      'Kinder',
      'Grade 1',
      'Grade 2',
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
    ];
    final labels = aggregated.keys.toList()
      ..sort((a, b) {
        final ai = gradeOrder.indexWhere(
          (g) => g.toLowerCase() == a.toLowerCase(),
        );
        final bi = gradeOrder.indexWhere(
          (g) => g.toLowerCase() == b.toLowerCase(),
        );
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    if (labels.isEmpty) return '';

    final datasets = [
      {
        'label': 'Frustration',
        'data': labels.map((g) => aggregated[g]?['Frustration'] ?? 0).toList(),
        'backgroundColor': '#FF8C00',
        'borderWidth': 0,
        'borderRadius': 4,
        'borderSkipped': false,
      },
      {
        'label': 'Instructional',
        'data': labels
            .map((g) => aggregated[g]?['Instructional'] ?? 0)
            .toList(),
        'backgroundColor': '#FFB347',
        'borderWidth': 0,
        'borderRadius': 4,
        'borderSkipped': false,
      },
      {
        'label': 'Independent',
        'data': labels.map((g) => aggregated[g]?['Independent'] ?? 0).toList(),
        'backgroundColor': '#22C55E',
        'borderWidth': 0,
        'borderRadius': 4,
        'borderSkipped': false,
      },
    ];

    final chart = {
      'type': 'bar',
      'data': {'labels': labels, 'datasets': datasets},
      'options': {
        'backgroundColor': '#FFFFFF',
        'plugins': {
          'legend': {
            'position': 'top',
            'labels': {
              'font': {'size': 11, 'family': 'Inter, sans-serif'},
              'usePointStyle': true,
              'pointStyle': 'circle',
              'padding': 16,
            },
          },
          'datalabels': {
            'anchor': 'end',
            'align': 'top',
            'font': {'size': 10, 'weight': 'bold'},
            'color': '#374151',
            'formatter': "function(v){return v>0?v:'';}",
          },
        },
        'scales': {
          'x': {
            'grid': {'display': false},
            'ticks': {
              'font': {'size': 11},
              'color': '#64748B',
            },
          },
          'y': {
            'beginAtZero': true,
            'grid': {'color': '#F1F5F9'},
            'ticks': {
              'font': {'size': 11},
              'color': '#94A3B8',
              'stepSize': 1,
            },
            'border': {
              'dash': [4, 4],
            },
          },
        },
        'barPercentage': 0.7,
        'categoryPercentage': 0.8,
      },
    };
    return 'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chart))}&width=1000&height=380&backgroundColor=white';
  }

  Widget _buildPhilIriSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Phil-IRI 2018 Descriptive Analytics',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Based on DepEd\'s Philippine Informal Reading Inventory (Phil-IRI) 2018 framework',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 16),
        isMobile
            ? Column(
                children: [
                  _buildFrequencyTable(),
                  const SizedBox(height: 16),
                  _buildDescriptiveStats(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildFrequencyTable()),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: _buildDescriptiveStats()),
                ],
              ),
        if (_cachedGradeUrl != null && _cachedGradeUrl!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildChartCard(
            'Grade Level Reading Distribution',
            _cachedGradeUrl,
            340,
          ),
        ],
      ],
    );
  }

  Widget _buildFrequencyTable() {
    final levels = ['Frustration', 'Instructional', 'Independent'];
    final levelColors = {
      'Frustration': AppTheme.levelFrustration,
      'Instructional': AppTheme.levelInstructional,
      'Independent': AppTheme.levelIndependent,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Frequency Distribution Table',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$_selectedReadType · Count (n) and percentage (%) per reading level',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildTableContent(levels, levelColors),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContent(
    List<String> levels,
    Map<String, Color> levelColors,
  ) {
    final years = _selectedRangeYears;

    Widget hCell(Widget child, double w) => SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: child,
      ),
    );

    Widget dCell(Widget child, double w) => SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: child,
      ),
    );

    final headerRow = Row(
      children: [
        hCell(
          const Text(
            'Reading Level',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondaryColor,
              letterSpacing: 0.3,
            ),
          ),
          130,
        ),
        ...years.map(
          (y) => hCell(
            Column(
              children: [
                Text(
                  '${y.schoolyearstart}–${y.schoolyearend}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'n            %',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            160,
          ),
        ),
      ],
    );

    final dataRows = levels.asMap().entries.map((entry) {
      final level = entry.value;
      return Container(
        color: entry.key % 2 == 0 ? const Color(0xFFFAFAFC) : Colors.white,
        child: Row(
          children: [
            dCell(
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: levelColors[level],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    level,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              130,
            ),
            ...years.map((y) {
              final counts = _rangeCounts[y.id] ?? {};
              final total = _total(counts);
              final count = counts[level] ?? 0;
              final pct = _percent(count, total);
              return dCell(
                Text(
                  '$count            ${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: levelColors[level],
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                160,
              );
            }),
          ],
        ),
      );
    }).toList();

    final totalRow = Row(
      children: [
        dCell(
          const Text(
            'Total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          130,
        ),
        ...years.map((y) {
          final counts = _rangeCounts[y.id] ?? {};
          final total = _total(counts);
          return dCell(
            Text(
              '$total            100.0%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            160,
          );
        }),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        const Divider(color: AppTheme.borderColor, height: 12),
        ...dataRows,
        const Divider(color: AppTheme.borderColor, height: 12),
        totalRow,
      ],
    );
  }

  Widget _buildDescriptiveStats() {
    int totalFrustration = 0, totalInstructional = 0, totalIndependent = 0;
    for (final y in _selectedRangeYears) {
      final counts = _rangeCounts[y.id] ?? {};
      totalFrustration += counts['Frustration'] ?? 0;
      totalInstructional += counts['Instructional'] ?? 0;
      totalIndependent += counts['Independent'] ?? 0;
    }
    final grandTotal = totalFrustration + totalInstructional + totalIndependent;

    String mode = 'N/A';
    int modeCount = 0;
    if (grandTotal > 0) {
      if (totalFrustration >= totalInstructional &&
          totalFrustration >= totalIndependent) {
        mode = 'Frustration';
        modeCount = totalFrustration;
      } else if (totalInstructional >= totalIndependent) {
        mode = 'Instructional';
        modeCount = totalInstructional;
      } else {
        mode = 'Independent';
        modeCount = totalIndependent;
      }
    }

    final modeColor = {
      'Frustration': AppTheme.levelFrustration,
      'Instructional': AppTheme.levelInstructional,
      'Independent': AppTheme.levelIndependent,
      'N/A': AppTheme.textSecondaryColor,
    }[mode]!;

    final frustPct = _percent(totalFrustration, grandTotal);
    final instrPct = _percent(totalInstructional, grandTotal);
    final indPct = _percent(totalIndependent, grandTotal);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descriptive Measures',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Summary statistics across selected range',
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: modeColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MODE (DOMINANT LEVEL)',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mode,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: modeColor,
                  ),
                ),
                if (grandTotal > 0)
                  Text(
                    '$modeCount students · ${_percent(modeCount, grandTotal).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _philIriStatRow(
            'Frustration',
            totalFrustration,
            frustPct,
            AppTheme.levelFrustration,
          ),
          const SizedBox(height: 8),
          _philIriStatRow(
            'Instructional',
            totalInstructional,
            instrPct,
            AppTheme.levelInstructional,
          ),
          const SizedBox(height: 8),
          _philIriStatRow(
            'Independent',
            totalIndependent,
            indPct,
            AppTheme.levelIndependent,
          ),
          const Divider(color: AppTheme.borderColor, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total N',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              Text(
                '$grandTotal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _philIriStatRow(String label, int count, double pct, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '${pct.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // INLINE TOP HEADER (RC variant)
  // =========================================================
  Widget _buildTopHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email ?? '';
    final parts = name.trim().split(RegExp(r'[\s@.]+'));
    String initials = 'RC';
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      initials = name[0].toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'iReader RC',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dashboard Analytics',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'School-year performance and reading level trends at a glance',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 480;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      drawer: isDesktop
          ? null
          : Drawer(child: RCSidebar(activeRoute: RCRoute.dashboard)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const RCSidebar(activeRoute: RCRoute.dashboard),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopHeader(),
                Expanded(
                  child: StreamBuilder<List<SchoolYear>>(
                    stream: _fetchSchoolYears(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        );
                      }

                      final schoolYears = snapshot.data!;

                      if (_startYear == null && schoolYears.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _autoLoadDashboard(),
                        );
                      }

                      return SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Year range selectors + Generate
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: _yearDropdown(
                                    label: 'START YEAR',
                                    value: _startYearId,
                                    years: schoolYears,
                                    onChanged: (v) => setState(() {
                                      _startYearId = v;
                                      _startYear = schoolYears.firstWhere(
                                        (s) => s.id == v,
                                        orElse: () => schoolYears.first,
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _yearDropdown(
                                    label: 'END YEAR',
                                    value: _endYearId,
                                    years: schoolYears,
                                    onChanged: (v) => setState(() {
                                      _endYearId = v;
                                      _endYear = schoolYears.firstWhere(
                                        (s) => s.id == v,
                                        orElse: () => schoolYears.last,
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 42,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (_startYear == null ||
                                          _endYear == null)
                                        return;
                                      final startVal =
                                          int.tryParse(
                                            _startYear!.schoolyearstart,
                                          ) ??
                                          0;
                                      final endVal =
                                          int.tryParse(
                                            _endYear!.schoolyearstart,
                                          ) ??
                                          0;
                                      if (startVal >= endVal) {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Invalid range'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() => _loadingAnalysis = true);
                                      final years = schoolYears.where((y) {
                                        final yVal =
                                            int.tryParse(y.schoolyearstart) ??
                                            0;
                                        return yVal >= startVal &&
                                            yVal <= endVal;
                                      }).toList();
                                      await _analyzeRange(years);
                                      setState(() => _loadingAnalysis = false);
                                    },
                                    child: const Text('Generate'),
                                  ),
                                ),
                                const Spacer(),
                                if (_selectedRangeYears.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.borderColor,
                                      ),
                                    ),
                                    child: Text(
                                      'Showing ${_selectedRangeYears.first.schoolyearstart}-${_selectedRangeYears.first.schoolyearend}'
                                      ' → ${_selectedRangeYears.last.schoolyearstart}-${_selectedRangeYears.last.schoolyearend}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            _buildResultToggle(),
                            const SizedBox(height: 20),

                            // Stat cards
                            if (!_loadingAnalysis) _buildStatCards(schoolYears),
                            if (!_loadingAnalysis) const SizedBox(height: 16),

                            // Charts / loading
                            if (_loadingAnalysis)
                              const SizedBox(
                                height: 300,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              )
                            else ...[
                              isMobile
                                  ? Column(
                                      children: [
                                        _buildLeftOverviewCard(),
                                        const SizedBox(height: 16),
                                        _buildChartCard(
                                          'All Students — Reading Levels',
                                          _cachedMultiYearUrl,
                                          300,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: _buildLeftOverviewCard(),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: _buildChartCard(
                                            'All Students — Reading Levels',
                                            _cachedMultiYearUrl,
                                            340,
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 16),
                              isMobile
                                  ? Column(
                                      children: [
                                        _buildGenderCard('Male'),
                                        const SizedBox(height: 16),
                                        _buildGenderCard('Female'),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildGenderCard('Male'),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildGenderCard('Female'),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 24),
                              _buildPhilIriSection(isMobile),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
