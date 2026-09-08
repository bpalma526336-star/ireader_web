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

  Widget _metric(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _divisionCard(Division division, Color color) {
    final counts = _countsFor(division.id);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              division.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            _metric(
              'Frustration',
              counts['Frustration'] ?? 0,
              AppTheme.levelFrustration,
            ),
            const SizedBox(height: 6),
            _metric(
              'Instructional',
              counts['Instructional'] ?? 0,
              AppTheme.levelInstructional,
            ),
            const SizedBox(height: 6),
            _metric(
              'Independent',
              counts['Independent'] ?? 0,
              AppTheme.levelIndependent,
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  '${_total(counts)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
    return Expanded(
      child: Container(
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
      ),
    );
  }

  Widget _summaryTable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Division')),
            DataColumn(label: Text('Frustration')),
            DataColumn(label: Text('Instructional')),
            DataColumn(label: Text('Independent')),
            DataColumn(label: Text('Total')),
          ],
          rows: _divisions.map((division) {
            final counts = _countsFor(division.id);
            final selected =
                division.id == _selectedDivisionId ||
                division.id == _selectedDivisionId2;
            return DataRow(
              color: WidgetStatePropertyAll<Color?>(
                selected ? AppTheme.primaryColor.withValues(alpha: 0.08) : null,
              ),
              cells: [
                DataCell(
                  Text(
                    division.name,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select a school year and two divisions to compare',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _dropdown<String>(
                              value: _selectedSchoolYearId,
                              hint: 'School year',
                              items: _schoolYears
                                  .map(
                                    (year) => DropdownMenuItem(
                                      value: year.id,
                                      child: Text(
                                        '${year.schoolyearstart}-${year.schoolyearend}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedSchoolYearId = value),
                            ),
                            const SizedBox(width: 8),
                            _dropdown<String>(
                              value: _selectedDivisionId,
                              hint: 'Division A',
                              items: _divisions
                                  .map(
                                    (division) => DropdownMenuItem(
                                      value: division.id,
                                      child: Text(division.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedDivisionId = value),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('vs'),
                            ),
                            _dropdown<String>(
                              value: _selectedDivisionId2,
                              hint: 'Division B',
                              items: _divisions
                                  .map(
                                    (division) => DropdownMenuItem(
                                      value: division.id,
                                      child: Text(division.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedDivisionId2 = value),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: canCompare ? _runComparison : null,
                              child: _comparing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Compare'),
                            ),
                          ],
                        ),
                        if (_selectedDivisionId == _selectedDivisionId2 &&
                            _selectedDivisionId != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Please select two different divisions.',
                              style: TextStyle(fontSize: 11, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _comparisonTypes.map((type) {
                          final selected = _selectedType == type;
                          return GestureDetector(
                            onTap: selected
                                ? null
                                : () async {
                                    setState(() => _selectedType = type);
                                    await _runComparison();
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (division1 != null || division2 != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Division Comparison',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedType,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (division1 != null)
                                _divisionCard(division1, AppTheme.primaryColor),
                              if (division1 != null && division2 != null)
                                const SizedBox(width: 10),
                              if (division2 != null)
                                _divisionCard(
                                  division2,
                                  const Color(0xFF3B82F6),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_chartUrl != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reading Level Comparison by Division',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Image.network(_chartUrl!, fit: BoxFit.contain),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _summaryTable(),
                ],
              ),
            ),
    );
  }
}
