import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/division.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';

class CompareDivision extends StatefulWidget {
  const CompareDivision({super.key});

  @override
  State<CompareDivision> createState() => _CompareDivisionState();
}

class _CompareDivisionState extends State<CompareDivision> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _comparisonTypes = const [
    'Stage 2 - Pre-Test',
    'Stage 3 - Midway/Mid-test',
    'Stage 4 - Post-Test',
  ];

  String _selectedType = 'Stage 2 - Pre-Test';
  String? _selectedSchoolYearId;
  String? _selectedDivisionId;
  String? _selectedDivisionId2;
  bool _loading = true;
  bool _comparing = false;
  String? _error;
  String? _chartUrl;
  List<Division> _divisions = [];
  List<SchoolYear> _schoolYears = [];
  final Map<String, Map<String, int>> _divisionCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _firestore.collection('divisions').get(),
        _firestore.collection('schoolyears').orderBy('schoolyearstart').get(),
      ]);
      final divisions =
          results[0].docs
              .map((doc) => Division.fromMap(doc.id, doc.data()))
              .where((division) => division.status.toUpperCase() == 'ACTIVE')
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final schoolYears =
          results[1].docs
              .map((doc) => SchoolYear.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.schoolyearstart.compareTo(b.schoolyearstart));

      if (!mounted) return;
      setState(() {
        _divisions = divisions;
        _schoolYears = schoolYears;
        _selectedSchoolYearId = schoolYears.isEmpty
            ? null
            : schoolYears.last.id;
        _selectedDivisionId = divisions.isEmpty ? null : divisions.first.id;
        _selectedDivisionId2 = divisions.length < 2 ? null : divisions[1].id;
      });

      if (_selectedSchoolYearId != null && _selectedDivisionId != null) {
        await _runComparison();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load divisions: $e';
      });
    }
  }

  Future<void> _runComparison() async {
    final schoolYearId = _selectedSchoolYearId;
    if (schoolYearId == null || _selectedDivisionId == null) {
      setState(() {
        _loading = false;
        _comparing = false;
      });
      return;
    }

    setState(() {
      _comparing = true;
      _error = null;
    });

    try {
      final studentDivisionMap = <String, String>{};
      final studentSnapshot = await _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: schoolYearId)
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      for (final doc in studentSnapshot.docs) {
        final student = Student.fromMap(doc.id, doc.data());
        final divisionId = student.divisionid;
        if (divisionId != null && divisionId.isNotEmpty) {
          studentDivisionMap[student.id] = divisionId;
        }
      }

      final assessmentSnapshot = await _firestore
          .collection('assessment')
          .where('schoolyearid', isEqualTo: schoolYearId)
          .where('assessmenttitle', isEqualTo: _selectedType)
          .get();
      final assessmentIds = assessmentSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      final counts = <String, Map<String, int>>{
        for (final division in _divisions)
          division.id: {'Frustration': 0, 'Instructional': 0, 'Independent': 0},
      };

      for (var index = 0; index < assessmentIds.length; index += 10) {
        final end = math.min(index + 10, assessmentIds.length);
        final resultsSnapshot = await _firestore
            .collection('overallresult')
            .where('assessmentid', whereIn: assessmentIds.sublist(index, end))
            .get();

        for (final resultDoc in resultsSnapshot.docs) {
          final result = resultDoc.data();
          final studentId = (result['studentid'] ?? '').toString();
          final divisionId = studentDivisionMap[studentId];
          final level = (result['readlevel'] ?? '').toString();
          if (divisionId == null || !counts.containsKey(divisionId)) continue;
          if (counts[divisionId]!.containsKey(level)) {
            counts[divisionId]![level] = (counts[divisionId]![level] ?? 0) + 1;
          }
        }
      }

      final labels = _divisions.map((division) => division.name).toList();
      final chartData = {
        'type': 'bar',
        'data': {
          'labels': labels,
          'datasets': [
            _chartDataset('Frustration', '#F59E0B', 'Frustration', counts),
            _chartDataset('Instructional', '#3B82F6', 'Instructional', counts),
            _chartDataset('Independent', '#22C55E', 'Independent', counts),
          ],
        },
        'options': {
          'responsive': true,
          'plugins': {
            'legend': {'position': 'top'},
            'tooltip': {'enabled': true},
          },
          'scales': {
            'x': {
              'grid': {'display': false},
            },
            'y': {
              'beginAtZero': true,
              'grid': {'color': '#E2E8F0'},
              'ticks': {'stepSize': 1},
            },
          },
          'barPercentage': 0.7,
          'categoryPercentage': 0.8,
        },
      };

      if (!mounted) return;
      setState(() {
        _divisionCounts
          ..clear()
          ..addAll(counts);
        _chartUrl =
            'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chartData))}&width=900&height=380&backgroundColor=white';
        _loading = false;
        _comparing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _comparing = false;
        _error = 'Unable to compare divisions: $e';
      });
    }
  }

  Map<String, dynamic> _chartDataset(
    String label,
    String color,
    String level,
    Map<String, Map<String, int>> counts,
  ) {
    return {
      'label': label,
      'data': _divisions
          .map((division) => counts[division.id]?[level] ?? 0)
          .toList(),
      'backgroundColor': color,
      'borderWidth': 0,
      'borderRadius': 4,
      'borderSkipped': false,
    };
  }

  Map<String, int> _countsFor(String? divisionId) =>
      _divisionCounts[divisionId] ??
      {'Frustration': 0, 'Instructional': 0, 'Independent': 0};

  int _total(Map<String, int> counts) =>
      (counts['Frustration'] ?? 0) +
      (counts['Instructional'] ?? 0) +
      (counts['Independent'] ?? 0);

  Division? _divisionById(String? id) {
    for (final division in _divisions) {
      if (division.id == id) return division;
    }
    return null;
  }

  Widget _metric(String label, int value, Color color, {int total = 0}) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? value / total : 0,
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _divisionCard(Division division, Color color, {String label = 'A'}) {
    final counts = _countsFor(division.id);
    final total = _total(counts);
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Division $label',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          division.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'total',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Metrics body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _metric(
                    'Frustration',
                    counts['Frustration'] ?? 0,
                    AppTheme.levelFrustration,
                    total: total,
                  ),
                  const SizedBox(height: 10),
                  _metric(
                    'Instructional',
                    counts['Instructional'] ?? 0,
                    AppTheme.levelInstructional,
                    total: total,
                  ),
                  const SizedBox(height: 10),
                  _metric(
                    'Independent',
                    counts['Independent'] ?? 0,
                    AppTheme.levelIndependent,
                    total: total,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _summaryTable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Division Summary',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimaryColor,
              ),
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
              horizontalMargin: 12,
              columnSpacing: 24,
              columns: [
                const DataColumn(label: Text('Division')),
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.levelFrustration,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('Frustration'),
                    ],
                  ),
                ),
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.levelInstructional,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('Instructional'),
                    ],
                  ),
                ),
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.levelIndependent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('Independent'),
                    ],
                  ),
                ),
                const DataColumn(label: Text('Total')),
              ],
              rows: _divisions.map((division) {
                final counts = _countsFor(division.id);
                final isA = division.id == _selectedDivisionId;
                final isB = division.id == _selectedDivisionId2;
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (isA)
                      return AppTheme.primaryColor.withValues(alpha: 0.08);
                    if (isB)
                      return const Color(0xFF3B82F6).withValues(alpha: 0.08);
                    return null;
                  }),
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            division.name,
                            style: TextStyle(
                              fontWeight: (isA || isB)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isA
                                  ? AppTheme.primaryColor
                                  : isB
                                  ? const Color(0xFF3B82F6)
                                  : AppTheme.textPrimaryColor,
                            ),
                          ),
                          if (isA) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                          if (isB) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF3B82F6,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'B',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DataCell(Text('${counts['Frustration'] ?? 0}')),
                    DataCell(Text('${counts['Instructional'] ?? 0}')),
                    DataCell(Text('${counts['Independent'] ?? 0}')),
                    DataCell(Text('${_total(counts)}')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final division1 = _divisionById(_selectedDivisionId);
    final division2 = _divisionById(_selectedDivisionId2);
    final canCompare =
        !_comparing &&
        _selectedSchoolYearId != null &&
        _selectedDivisionId != null &&
        _selectedDivisionId2 != null &&
        _selectedDivisionId != _selectedDivisionId2;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compare Division'),
            Text(
              'Reading level comparison',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _divisions.isEmpty
          ? const Center(child: Text('No active divisions found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Filter + Stage Toggle Card ──────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 4,
                            ),
                            right: BorderSide(color: AppTheme.borderColor),
                            top: BorderSide(color: AppTheme.borderColor),
                            bottom: BorderSide(color: AppTheme.borderColor),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.tune,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Comparison Settings',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;
                                final schoolYearDd = _dropdown<String>(
                                  value: _selectedSchoolYearId,
                                  hint: 'School year',
                                  items: _schoolYears
                                      .map(
                                        (year) => DropdownMenuItem(
                                          value: year.id,
                                          child: Text(
                                            '${year.schoolyearstart}–${year.schoolyearend}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(
                                    () => _selectedSchoolYearId = value,
                                  ),
                                );
                                final divADd = _dropdown<String>(
                                  value: _selectedDivisionId,
                                  hint: 'Division A',
                                  items: _divisions
                                      .map(
                                        (division) => DropdownMenuItem(
                                          value: division.id,
                                          child: Text(
                                            division.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(
                                    () => _selectedDivisionId = value,
                                  ),
                                );
                                final vsBadge = Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.borderColor,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'vs',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ),
                                );
                                final divBDd = _dropdown<String>(
                                  value: _selectedDivisionId2,
                                  hint: 'Division B',
                                  items: _divisions
                                      .map(
                                        (division) => DropdownMenuItem(
                                          value: division.id,
                                          child: Text(
                                            division.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(
                                    () => _selectedDivisionId2 = value,
                                  ),
                                );
                                final compareBtn = SizedBox(
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: canCompare
                                        ? _runComparison
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _comparing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Compare',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      schoolYearDd,
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(child: divADd),
                                          vsBadge,
                                          Expanded(child: divBDd),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      compareBtn,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: schoolYearDd),
                                    const SizedBox(width: 8),
                                    Expanded(child: divADd),
                                    vsBadge,
                                    Expanded(child: divBDd),
                                    const SizedBox(width: 8),
                                    compareBtn,
                                  ],
                                );
                              },
                            ),
                            if (_selectedDivisionId == _selectedDivisionId2 &&
                                _selectedDivisionId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 12,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Please select two different divisions.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _comparisonTypes.map((type) {
                                    final selected = _selectedType == type;
                                    return GestureDetector(
                                      onTap: selected
                                          ? null
                                          : () async {
                                              setState(
                                                () => _selectedType = type,
                                              );
                                              await _runComparison();
                                              if (!mounted) return;
                                            },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          boxShadow: selected
                                              ? [
                                                  BoxShadow(
                                                    color: AppTheme.primaryColor
                                                        .withValues(
                                                          alpha: 0.25,
                                                        ),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : AppTheme.textSecondaryColor,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Side-by-side Division Cards ─────────────────────────
                  if (division1 != null || division2 != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Division Comparison',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedType,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (division1 != null)
                                _divisionCard(
                                  division1,
                                  AppTheme.primaryColor,
                                  label: 'A',
                                ),
                              if (division1 != null && division2 != null)
                                const SizedBox(width: 12),
                              if (division2 != null)
                                _divisionCard(
                                  division2,
                                  const Color(0xFF3B82F6),
                                  label: 'B',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ── Dashboard: summary left, chart right ────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chartCard = _chartUrl == null
                          ? const SizedBox.shrink()
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.bar_chart_rounded,
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'Reading Level Comparison by Division',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 260,
                                    child: Image.network(
                                      _chartUrl!,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                color: AppTheme.primaryColor,
                                              ),
                                            );
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Text(
                                                  'Unable to load chart.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                      if (constraints.maxWidth < 800) {
                        return Column(
                          children: [
                            _summaryTable(),
                            if (_chartUrl != null) ...[
                              const SizedBox(height: 16),
                              chartCard,
                            ],
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: _summaryTable()),
                          if (_chartUrl != null) ...[
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: chartCard),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
