import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/division.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';

class CompareSchool extends StatefulWidget {
  final Division division;

  const CompareSchool({super.key, required this.division});

  @override
  State<CompareSchool> createState() => _CompareSchoolState();
}

class _CompareSchoolState extends State<CompareSchool> {
  final _firestore = FirebaseFirestore.instance;
  final _comparisonTypes = const [
    'Stage 2 - Pre-Test',
    'Stage 3 - Midway/Mid-test',
    'Stage 4 - Post-Test',
  ];
  String _selectedType = 'Stage 2 - Pre-Test';
  String? _selectedSchoolId;
  String? _selectedSchoolId2;
  bool _loading = true;
  bool _comparing = false;
  String? _error;
  String? _chartUrl;
  List<School> _schools = [];
  final _schoolCounts = <String, Map<String, int>>{};

  Map<String, int> _emptyCounts() => {
    'Frustration': 0,
    'Instructional': 0,
    'Independent': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _firestore
          .collection('schools')
          .where('divisionid', isEqualTo: widget.division.id)
          .get();
      final schools =
          snapshot.docs
              .map((doc) => School.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _schools = schools;
        _selectedSchoolId = schools.isEmpty ? null : schools.first.id;
        _selectedSchoolId2 = schools.length > 1 ? schools[1].id : null;
      });
      if (_selectedSchoolId != null) {
        await _runComparison();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load schools: $e';
      });
    }
  }

  Future<void> _runComparison() async {
    if (_selectedSchoolId == null) {
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
      final sectionSchoolMap = <String, String>{};
      final sectionsSnapshot = await _firestore
          .collection('sections')
          .where('divisionid', isEqualTo: widget.division.id)
          .get();
      for (final doc in sectionsSnapshot.docs) {
        final section = Section.fromMap(doc.id, doc.data());
        final schoolId = section.schoolid;
        if (schoolId != null && schoolId.isNotEmpty) {
          sectionSchoolMap[section.id] = schoolId;
        }
      }

      final studentSectionMap = <String, String>{};
      final students = await _firestore
          .collection('students')
          .where('divisionid', isEqualTo: widget.division.id)
          .where('status', isEqualTo: 'ACTIVE')
          .get();
      for (final doc in students.docs) {
        final student = Student.fromMap(doc.id, doc.data());
        studentSectionMap[student.id] = student.sectionid;
      }

      final assessments = await _firestore
          .collection('assessment')
          .where('divisionid', isEqualTo: widget.division.id)
          .where('assessmenttitle', isEqualTo: _selectedType)
          .get();
      final assessmentIds = assessments.docs.map((doc) => doc.id).toList();
      final counts = <String, Map<String, int>>{
        for (final school in _schools) school.id: _emptyCounts(),
      };

      for (var i = 0; i < assessmentIds.length; i += 10) {
        final ids = assessmentIds.sublist(
          i,
          math.min(i + 10, assessmentIds.length),
        );
        final results = await _firestore
            .collection('overallresult')
            .where('assessmentid', whereIn: ids)
            .get();
        for (final doc in results.docs) {
          final result = doc.data();
          final studentId = (result['studentid'] ?? '').toString();
          final sectionId = studentSectionMap[studentId];
          final schoolId = sectionId == null
              ? null
              : sectionSchoolMap[sectionId];
          final level = (result['readlevel'] ?? '').toString();
          if (schoolId != null &&
              counts[schoolId]?.containsKey(level) == true) {
            counts[schoolId]![level] = counts[schoolId]![level]! + 1;
          }
        }
      }

      _schoolCounts
        ..clear()
        ..addAll(counts);
      final labels = _schools.map((school) => school.name).toList();
      final chartData = {
        'type': 'bar',
        'data': {
          'labels': labels,
          'datasets': [
            _dataset('Frustration', 'F59E0B'),
            _dataset('Instructional', '3B82F6'),
            _dataset('Independent', '22C55E'),
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
              'ticks': {'stepSize': 1},
            },
          },
          'barPercentage': 0.7,
          'categoryPercentage': 0.8,
        },
      };
      if (!mounted) return;
      setState(() {
        _chartUrl =
            'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chartData))}&width=800&height=340&backgroundColor=white';
        _loading = false;
        _comparing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _comparing = false;
        _error = 'Unable to compare schools: $e';
      });
    }
  }

  Map<String, dynamic> _dataset(String label, String color) => {
    'label': label,
    'data': _schools
        .map((school) => _schoolCounts[school.id]?[label] ?? 0)
        .toList(),
    'backgroundColor': '#$color',
    'borderWidth': 0,
    'borderRadius': 4,
  };

  Map<String, int> _countsFor(String? id) =>
      _schoolCounts[id] ?? _emptyCounts();

  School? _schoolFor(String? id) {
    for (final school in _schools) {
      if (school.id == id) return school;
    }
    return null;
  }

  Widget _insightBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsInsight(String subject, Map<String, int> counts) {
    final total = counts.values.fold(0, (sum, value) => sum + value);
    if (total == 0) {
      return _insightBox(
        'No assessment results are available for $subject in this stage.',
      );
    }
    final levels = ['Frustration', 'Instructional', 'Independent']
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    final leadingLevel = levels.first;
    final leadingCount = counts[leadingLevel] ?? 0;
    final interpretation = switch (leadingLevel) {
      'Independent' => 'most learners can work with minimal support',
      'Instructional' => 'many learners may benefit from guided support',
      _ => 'many learners may need targeted intervention',
    };
    return _insightBox(
      '$subject has mostly $leadingLevel readers ($leadingCount of $total, '
      '${(leadingCount / total * 100).round()}%); $interpretation.',
    );
  }

  Widget _metricRow(String label, int value, Color color, int total) {
    final percent = total > 0 ? (value / total * 100).round() : 0;
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
                '$percent%',
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

  Widget _dropdown(
    String? value,
    String hint,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          items: _schools
              .map(
                (school) => DropdownMenuItem(
                  value: school.id,
                  child: Text(school.name),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _card(
    School school,
    Map<String, int> counts,
    Color color,
    String label,
  ) {
    final total = counts.values.fold(0, (sum, value) => sum + value);
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'School $label',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          school.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          style: TextStyle(fontSize: 9, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _metricRow(
                    'Frustration',
                    counts['Frustration'] ?? 0,
                    AppTheme.levelFrustration,
                    total,
                  ),
                  const SizedBox(height: 10),
                  _metricRow(
                    'Instructional',
                    counts['Instructional'] ?? 0,
                    AppTheme.levelInstructional,
                    total,
                  ),
                  const SizedBox(height: 10),
                  _metricRow(
                    'Independent',
                    counts['Independent'] ?? 0,
                    AppTheme.levelIndependent,
                    total,
                  ),
                  const SizedBox(height: 14),
                  _analyticsInsight(school.name, counts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final school1 = _schoolFor(_selectedSchoolId);
    final school2 = _schoolFor(_selectedSchoolId2);
    final canCompare =
        !_comparing &&
        _selectedSchoolId != null &&
        _selectedSchoolId2 != null &&
        _selectedSchoolId != _selectedSchoolId2;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compare School',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(widget.division.name, style: const TextStyle(fontSize: 11)),
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
          : _schools.isEmpty
          ? const Center(child: Text('No schools found for this division.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                final pair = Row(
                                  children: [
                                    Expanded(
                                      child: _dropdown(
                                        _selectedSchoolId,
                                        'School A',
                                        (value) => setState(
                                          () => _selectedSchoolId = value,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.borderColor,
                                          ),
                                        ),
                                        child: Text(
                                          'vs',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _dropdown(
                                        _selectedSchoolId2,
                                        'School B',
                                        (value) => setState(
                                          () => _selectedSchoolId2 = value,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 42,
                                      child: ElevatedButton(
                                        onPressed: canCompare
                                            ? _runComparison
                                            : null,
                                        child: _comparing
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text('Compare'),
                                      ),
                                    ),
                                  ],
                                );
                                if (constraints.maxWidth >= 600) return pair;
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _dropdown(
                                            _selectedSchoolId,
                                            'School A',
                                            (value) => setState(
                                              () => _selectedSchoolId = value,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: Text(
                                            'vs',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _dropdown(
                                            _selectedSchoolId2,
                                            'School B',
                                            (value) => setState(
                                              () => _selectedSchoolId2 = value,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: canCompare
                                            ? _runComparison
                                            : null,
                                        child: const Text('Compare'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (_selectedSchoolId != null &&
                                _selectedSchoolId2 != null &&
                                _selectedSchoolId == _selectedSchoolId2)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Please select two different schools.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade400,
                                  ),
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
                                      onTap: () async {
                                        if (selected) return;
                                        setState(() => _selectedType = type);
                                        await _runComparison();
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
                  if (school1 != null || school2 != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'School Comparison',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (school1 != null)
                                _card(
                                  school1,
                                  _countsFor(school1.id),
                                  AppTheme.primaryColor,
                                  'A',
                                ),
                              if (school1 != null && school2 != null)
                                const SizedBox(width: 12),
                              if (school2 != null)
                                _card(
                                  school2,
                                  _countsFor(school2.id),
                                  const Color(0xFF3B82F6),
                                  'B',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'School Summary',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('School')),
                              DataColumn(label: Text('Frustration')),
                              DataColumn(label: Text('Instructional')),
                              DataColumn(label: Text('Independent')),
                              DataColumn(label: Text('Total')),
                            ],
                            rows: _schools.map((school) {
                              final counts = _countsFor(school.id);
                              final total = counts.values.fold(
                                0,
                                (sum, value) => sum + value,
                              );
                              return DataRow(
                                cells: [
                                  DataCell(Text(school.name)),
                                  DataCell(Text('${counts['Frustration']}')),
                                  DataCell(Text('${counts['Instructional']}')),
                                  DataCell(Text('${counts['Independent']}')),
                                  DataCell(Text('$total')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_chartUrl != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reading Level Comparison by School',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: Image.network(
                              _chartUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Text('Unable to load chart.'),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
