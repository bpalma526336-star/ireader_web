import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';

class CompareSection extends StatefulWidget {
  final SchoolYear schoolYear;

  const CompareSection({super.key, required this.schoolYear});

  @override
  State<CompareSection> createState() => _CompareSectionState();
}

class _CompareSectionState extends State<CompareSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _comparisonTypes = const ['Pre-test', 'Post-test'];

  String _selectedType = 'Pre-test';
  String? _selectedSectionId;
  bool _loading = true;
  bool _comparing = false;
  String? _error;
  String? _chartUrl;

  List<Section> _sections = [];
  final Map<String, Map<String, int>> _sectionCounts = {};
  final Map<String, String> _sectionTeacherNames = {};

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sectionsSnapshot = await _firestore
          .collection('sections')
          .where('schoolyearid', isEqualTo: widget.schoolYear.id)
          .get();

      final sections = sectionsSnapshot.docs
          .map((doc) => Section.fromMap(doc.id, doc.data()))
          .toList();
      sections.sort((a, b) => a.sectionname.compareTo(b.sectionname));

      final teacherNames = <String, String>{};
      for (final section in sections) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(section.teacherid)
            .get();

        if (teacherDoc.exists) {
          final data = teacherDoc.data() ?? {};
          final first = (data['firstname'] ?? '').toString();
          final middle = (data['middlename'] ?? '').toString();
          final last = (data['lastname'] ?? '').toString();
          final fullName = [
            first,
            middle,
            last,
          ].where((value) => value.trim().isNotEmpty).join(' ');
          teacherNames[section.id] = fullName.isEmpty
              ? 'Unknown Teacher'
              : fullName;
        } else {
          teacherNames[section.id] = 'Unknown Teacher';
        }
      }

      final selectedId = sections.isEmpty ? null : sections.first.id;

      if (!mounted) return;

      setState(() {
        _sections = sections;
        _selectedSectionId = selectedId;
        _sectionTeacherNames.clear();
        _sectionTeacherNames.addAll(teacherNames);
      });

      if (_selectedSectionId != null) {
        await _runComparison();
      } else {
        setState(() {
          _loading = false;
          _chartUrl = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load sections: $e';
      });
    }
  }

  Future<void> _runComparison() async {
    if (_selectedSectionId == null) {
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
      final studentSectionMap = <String, String>{};
      final studentSnapshot = await _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: widget.schoolYear.id)
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      for (final doc in studentSnapshot.docs) {
        final student = Student.fromMap(doc.id, doc.data());
        studentSectionMap[student.id] = student.sectionid;
      }

      final assessmentSnapshot = await _firestore
          .collection('assessment')
          .where('schoolyearid', isEqualTo: widget.schoolYear.id)
          .where('testtype', isEqualTo: _selectedType)
          .get();

      final assessmentIds = assessmentSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      final countsBySection = <String, Map<String, int>>{};

      for (final section in _sections) {
        countsBySection[section.id] = {
          'Frustration': 0,
          'Instructional': 0,
          'Independent': 0,
        };
      }

      if (assessmentIds.isNotEmpty) {
        for (int i = 0; i < assessmentIds.length; i += 10) {
          final end = math.min(i + 10, assessmentIds.length);
          final chunk = assessmentIds.sublist(i, end);

          final resultsSnapshot = await _firestore
              .collection('overallresult')
              .where('assessmentid', whereIn: chunk)
              .get();

          for (final resultDoc in resultsSnapshot.docs) {
            final result = resultDoc.data();
            final studentId = (result['studentid'] ?? '').toString();
            final sectionId = studentSectionMap[studentId];
            final level = (result['readlevel'] ?? '').toString();

            if (sectionId == null || !countsBySection.containsKey(sectionId)) {
              continue;
            }

            if (countsBySection[sectionId]!.containsKey(level)) {
              countsBySection[sectionId]![level] =
                  (countsBySection[sectionId]![level] ?? 0) + 1;
            }
          }
        }
      }

      _sectionCounts.clear();
      _sectionCounts.addAll(countsBySection);

      final labels = _sections.map((section) => section.sectionname).toList();
      final chartData = {
        'type': 'bar',
        'data': {
          'labels': labels,
          'datasets': [
            {
              'label': 'Frustration',
              'data': List.generate(labels.length, (index) {
                final section = _sections[index];
                return _sectionCounts[section.id]?['Frustration'] ?? 0;
              }),
              'backgroundColor': '#F59E0B',
              'borderWidth': 0,
              'borderRadius': 4,
              'borderSkipped': false,
            },
            {
              'label': 'Instructional',
              'data': List.generate(labels.length, (index) {
                final section = _sections[index];
                return _sectionCounts[section.id]?['Instructional'] ?? 0;
              }),
              'backgroundColor': '#3B82F6',
              'borderWidth': 0,
              'borderRadius': 4,
              'borderSkipped': false,
            },
            {
              'label': 'Independent',
              'data': List.generate(labels.length, (index) {
                final section = _sections[index];
                return _sectionCounts[section.id]?['Independent'] ?? 0;
              }),
              'backgroundColor': '#22C55E',
              'borderWidth': 0,
              'borderRadius': 4,
              'borderSkipped': false,
            },
          ],
        },
        'options': {
          'responsive': true,
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
            'tooltip': {'enabled': true},
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
              'grid': {'color': '#E2E8F0'},
              'ticks': {
                'font': {'size': 11},
                'color': '#64748B',
                'stepSize': 1,
              },
            },
          },
          'barPercentage': 0.7,
          'categoryPercentage': 0.8,
        },
      };

      final url =
          'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chartData))}&width=1000&height=420&backgroundColor=white';

      if (!mounted) return;

      setState(() {
        _chartUrl = url;
        _loading = false;
        _comparing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _comparing = false;
        _error = 'Unable to compare sections: $e';
      });
    }
  }

  Map<String, int> _countsForSelectedSection() {
    if (_selectedSectionId == null) {
      return {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
    }

    return _sectionCounts[_selectedSectionId!] ??
        {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
  }

  Widget _buildMetricCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCounts = _countsForSelectedSection();
    final selectedSection = _sections.isEmpty
        ? null
        : _sections.firstWhere(
            (section) => section.id == _selectedSectionId,
            orElse: () => _sections.first,
          );

    final totals = {
      'Frustration': selectedCounts['Frustration'] ?? 0,
      'Instructional': selectedCounts['Instructional'] ?? 0,
      'Independent': selectedCounts['Independent'] ?? 0,
    };
    final totalResults = totals.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SY ${widget.schoolYear.schoolyearstart}–${widget.schoolYear.schoolyearend}',
            ),
            const Text(
              'Compare Section',
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
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textPrimaryColor),
                ),
              ),
            )
          : _sections.isEmpty
          ? const Center(child: Text('No sections found for this school year.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSectionId,
                                isExpanded: true,
                                hint: const Text('Select Section'),
                                items: _sections
                                    .map(
                                      (section) => DropdownMenuItem(
                                        value: section.id,
                                        child: Text(section.sectionname),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _selectedSectionId = value);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _comparing || _selectedSectionId == null
                                ? null
                                : _runComparison,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _comparing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Compare'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                          final isSelected = _selectedType == type;
                          return GestureDetector(
                            onTap: () async {
                              if (isSelected) return;
                              setState(() => _selectedType = type);
                              await _runComparison();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isSelected
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
                  const SizedBox(height: 20),
                  if (selectedSection != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Section',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedSection.sectionname,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _sectionTeacherNames[selectedSection.id] ??
                                'Unknown Teacher',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Frustration',
                                  totals['Frustration'] ?? 0,
                                  AppTheme.levelFrustration,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Instructional',
                                  totals['Instructional'] ?? 0,
                                  AppTheme.levelInstructional,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Independent',
                                  totals['Independent'] ?? 0,
                                  AppTheme.levelIndependent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            totalResults == 0
                                ? 'No ${_selectedType} assessment results found for this section.'
                                : 'Total ${_selectedType} results: $totalResults',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_chartUrl != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reading Level Comparison by Section',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Image.network(
                            _chartUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: Text('Unable to load chart.'),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
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
                          'Section Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                            ),
                            columns: const [
                              DataColumn(label: Text('Section')),
                              DataColumn(label: Text('Frustration')),
                              DataColumn(label: Text('Instructional')),
                              DataColumn(label: Text('Independent')),
                              DataColumn(label: Text('Total')),
                            ],
                            rows: _sections.map((section) {
                              final counts =
                                  _sectionCounts[section.id] ??
                                  {
                                    'Frustration': 0,
                                    'Instructional': 0,
                                    'Independent': 0,
                                  };
                              final total =
                                  (counts['Frustration'] ?? 0) +
                                  (counts['Instructional'] ?? 0) +
                                  (counts['Independent'] ?? 0);
                              final isSelected =
                                  section.id == _selectedSectionId;

                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                  (_) => isSelected
                                      ? AppTheme.primaryColor.withValues(
                                          alpha: 0.08,
                                        )
                                      : null,
                                ),
                                cells: [
                                  DataCell(
                                    Text(
                                      section.sectionname,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.textPrimaryColor,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text('${counts['Frustration'] ?? 0}'),
                                  ),
                                  DataCell(
                                    Text('${counts['Instructional'] ?? 0}'),
                                  ),
                                  DataCell(
                                    Text('${counts['Independent'] ?? 0}'),
                                  ),
                                  DataCell(Text('$total')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
