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
  String? _selectedSectionId2;
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
      final selectedId2 = sections.length >= 2 ? sections[1].id : null;

      if (!mounted) return;

      setState(() {
        _sections = sections;
        _selectedSectionId = selectedId;
        _selectedSectionId2 = selectedId2;
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
          'https://quickchart.io/chart?c=${Uri.encodeComponent(jsonEncode(chartData))}&width=800&height=340&backgroundColor=white';

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

  Map<String, int> _countsForSection(String? sectionId) {
    if (sectionId == null) {
      return {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
    }
    return _sectionCounts[sectionId] ??
        {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
  }

  Widget _buildSectionCompareCard(Section section, Map<String, int> counts, Color accentColor) {
    final total = (counts['Frustration'] ?? 0) +
        (counts['Instructional'] ?? 0) +
        (counts['Independent'] ?? 0);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                section.sectionname,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _sectionTeacherNames[section.id] ?? 'Unknown Teacher',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 10),
            _buildMetricRow('Frustration', counts['Frustration'] ?? 0, AppTheme.levelFrustration),
            const SizedBox(height: 6),
            _buildMetricRow('Instructional', counts['Instructional'] ?? 0, AppTheme.levelInstructional),
            const SizedBox(height: 6),
            _buildMetricRow('Independent', counts['Independent'] ?? 0, AppTheme.levelIndependent),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, int value, Color color) {
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String? value, String hint, void Function(String?) onChanged) {
    return Expanded(
      child: Container(
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
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
            items: _sections
                .map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text(section.sectionname),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final section1 = _selectedSectionId == null || _sections.isEmpty
        ? null
        : _sections.firstWhere(
            (s) => s.id == _selectedSectionId,
            orElse: () => _sections.first,
          );
    final section2 = _selectedSectionId2 == null || _sections.isEmpty
        ? null
        : _sections.firstWhere(
            (s) => s.id == _selectedSectionId2,
            orElse: () => _sections.first,
          );

    final counts1 = _countsForSection(_selectedSectionId);
    final counts2 = _countsForSection(_selectedSectionId2);

    final canCompare = !_comparing &&
        _selectedSectionId != null &&
        _selectedSectionId2 != null &&
        _selectedSectionId != _selectedSectionId2;

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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter bar — two dropdowns with vs label
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
                          'Select two sections to compare',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildDropdown(
                              _selectedSectionId,
                              'Section A',
                              (value) {
                                if (value == null) return;
                                setState(() => _selectedSectionId = value);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'vs',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            _buildDropdown(
                              _selectedSectionId2,
                              'Section B',
                              (value) {
                                if (value == null) return;
                                setState(() => _selectedSectionId2 = value);
                              },
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: canCompare ? _runComparison : null,
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
                                    : const Text('Compare', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedSectionId != null &&
                            _selectedSectionId2 != null &&
                            _selectedSectionId == _selectedSectionId2)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Please select two different sections.',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pre-test / Post-test toggle
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
                  const SizedBox(height: 12),

                  // Side-by-side comparison cards
                  if (section1 != null || section2 != null)
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
                                'Section Comparison',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _selectedType,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (section1 != null)
                                _buildSectionCompareCard(
                                  section1,
                                  counts1,
                                  AppTheme.primaryColor,
                                ),
                              if (section1 != null && section2 != null)
                                const SizedBox(width: 10),
                              if (section2 != null)
                                _buildSectionCompareCard(
                                  section2,
                                  counts2,
                                  const Color(0xFF3B82F6),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Chart — all sections overview
                  if (_chartUrl != null) ...[
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
                            'Reading Level Comparison by Section',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Image.network(
                            _chartUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 140,
                                  child: Center(
                                    child: Text(
                                      'Unable to load chart.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Section Summary table
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
                        const Text(
                          'Section Summary',
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
                              final isA = section.id == _selectedSectionId;
                              final isB = section.id == _selectedSectionId2;

                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                  (_) {
                                    if (isA) {
                                      return AppTheme.primaryColor.withValues(alpha: 0.08);
                                    }
                                    if (isB) {
                                      return const Color(0xFF3B82F6).withValues(alpha: 0.08);
                                    }
                                    return null;
                                  },
                                ),
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          section.sectionname,
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
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
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
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
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
