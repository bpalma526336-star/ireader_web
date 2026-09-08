import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ireader_web/model/division.dart';
import 'package:ireader_web/model/readingcoordinator.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/readingcoordinator/sections/compare_section.dart';

class CompareSection extends StatefulWidget {
  final RC rc;
  final SchoolYear schoolYear;

  const CompareSection({super.key, required this.rc, required this.schoolYear});

  @override
  State<CompareSection> createState() => _CompareSectionState();
}

class _CompareSectionState extends State<CompareSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _comparisonTypes = const [
    'Stage 2 - Pre-Test',
    'Stage 3 - Midway/Mid-test',
    'Stage 4 - Post-Test',
  ];
  String _selectedType = 'Stage 2 - Pre-Test';
  String? _selectedSectionId;
  String? _selectedSectionId2;
  bool _loading = true;
  bool _comparing = false;
  String? _error;
  String? _chartUrl;
  List<Section> _sections = [];
  Division? _division;
  School? _school;
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
      if (widget.rc.divisionid != null) {
        final divisionDoc = await _firestore
            .collection('divisions')
            .doc(widget.rc.divisionid)
            .get();
        if (divisionDoc.exists) {
          _division = Division.fromMap(
            divisionDoc.id,
            divisionDoc.data() ?? {},
          );
        }
      }

      if (widget.rc.schoolid != null) {
        final schoolDoc = await _firestore
            .collection('schools')
            .doc(widget.rc.schoolid)
            .get();
        if (schoolDoc.exists) {
          _school = School.fromMap(schoolDoc.id, schoolDoc.data() ?? {});
        }
      }

      Query<Map<String, dynamic>> sectionsQuery = _firestore
          .collection('sections')
          .where('schoolyearid', isEqualTo: widget.schoolYear.id)
          .where('schoolid', isEqualTo: widget.rc.schoolid)
          .where('divisionid', isEqualTo: widget.rc.divisionid);

      final sectionsSnapshot = await sectionsQuery.get();

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
        if (!mounted) return;
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
          .where('schoolid', isEqualTo: widget.rc.schoolid)
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      for (final doc in studentSnapshot.docs) {
        final student = Student.fromMap(doc.id, doc.data());
        studentSectionMap[student.id] = student.sectionid;
      }

      final assessmentSnapshot = await _firestore
          .collection('assessment')
          .where('schoolyearid', isEqualTo: widget.schoolYear.id)
          .where('assessmenttitle', isEqualTo: _selectedType)
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

  Widget _analyticsInsight(String subject, Map<String, int> counts) {
    final total =
        (counts['Frustration'] ?? 0) +
        (counts['Instructional'] ?? 0) +
        (counts['Independent'] ?? 0);
    if (total == 0) {
      return _insightBox(
        'No assessment results are available for $subject in this stage.',
      );
    }

    final levels = ['Frustration', 'Instructional', 'Independent'];
    levels.sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    final leadingLevel = levels.first;
    final leadingCount = counts[leadingLevel] ?? 0;
    final leadingPercent = (leadingCount / total * 100).round();
    final interpretation = switch (leadingLevel) {
      'Independent' => 'most learners can work with minimal support',
      'Instructional' => 'many learners may benefit from guided support',
      _ => 'many learners may need targeted intervention',
    };

    return _insightBox(
      '$subject has mostly $leadingLevel readers ($leadingCount of $total, '
      '$leadingPercent%); $interpretation.',
    );
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

  Widget _buildSectionCompareCard(
    Section section,
    Map<String, int> counts,
    Color accentColor, {
    String label = 'A',
  }) {
    final total =
        (counts['Frustration'] ?? 0) +
        (counts['Instructional'] ?? 0) +
        (counts['Independent'] ?? 0);

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.10),
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
                  colors: [accentColor, accentColor.withValues(alpha: 0.72)],
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
                            'Section $label',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          section.sectionname,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 11,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _sectionTeacherNames[section.id] ??
                                    'Unknown Teacher',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                  _buildMetricRow(
                    'Frustration',
                    counts['Frustration'] ?? 0,
                    AppTheme.levelFrustration,
                    total: total,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    'Instructional',
                    counts['Instructional'] ?? 0,
                    AppTheme.levelInstructional,
                    total: total,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    'Independent',
                    counts['Independent'] ?? 0,
                    AppTheme.levelIndependent,
                    total: total,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _analyticsInsight(section.sectionname, counts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    int value,
    Color color, {
    int total = 0,
  }) {
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

  Widget _buildDropdown(
    String? value,
    String hint,
    void Function(String?) onChanged,
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
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimaryColor,
          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final section1 = _sections.cast<Section?>().firstWhere(
      (s) => s?.id == _selectedSectionId,
      orElse: () => null,
    );
    final section2 = _sections.cast<Section?>().firstWhere(
      (s) => s?.id == _selectedSectionId2,
      orElse: () => null,
    );

    final counts1 = _countsForSection(_selectedSectionId);
    final counts2 = _countsForSection(_selectedSectionId2);

    final canCompare =
        !_comparing &&
        _selectedSectionId != null &&
        _selectedSectionId2 != null &&
        _selectedSectionId != _selectedSectionId2;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compare Section',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              [
                'SY ${widget.schoolYear.schoolyearstart}–${widget.schoolYear.schoolyearend}',
                if (widget.rc.divisionid != null)
                  _division?.name ?? 'Unknown Division',
                if (widget.rc.schoolid != null)
                  _school?.name ?? 'Unknown School',
              ].join(' · '),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
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
                                final isNarrow = constraints.maxWidth < 600;
                                final sectionADd = _buildDropdown(
                                  _selectedSectionId,
                                  'Section A',
                                  (value) {
                                    if (value == null) return;
                                    setState(() => _selectedSectionId = value);
                                  },
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
                                    child: Text(
                                      'vs',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                );
                                final sectionBDd = _buildDropdown(
                                  _selectedSectionId2,
                                  'Section B',
                                  (value) {
                                    if (value == null) return;
                                    setState(() => _selectedSectionId2 = value);
                                  },
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
                                      Row(
                                        children: [
                                          Expanded(child: sectionADd),
                                          vsBadge,
                                          Expanded(child: sectionBDd),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      compareBtn,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: sectionADd),
                                    vsBadge,
                                    Expanded(child: sectionBDd),
                                    const SizedBox(width: 8),
                                    compareBtn,
                                  ],
                                );
                              },
                            ),
                            if (_selectedSectionId != null &&
                                _selectedSectionId2 != null &&
                                _selectedSectionId == _selectedSectionId2)
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
                                      'Please select two different sections.',
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
                                    final isSelected = _selectedType == type;
                                    return GestureDetector(
                                      onTap: () async {
                                        if (isSelected) return;
                                        setState(() => _selectedType = type);
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
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          boxShadow: isSelected
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
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.textSecondaryColor,
                                            fontWeight: isSelected
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

                  // ── Side-by-side Section Cards ──────────────────────────
                  if (section1 != null || section2 != null)
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
                                'Section Comparison',
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
                              if (section1 != null)
                                _buildSectionCompareCard(
                                  section1,
                                  counts1,
                                  AppTheme.primaryColor,
                                  label: 'A',
                                ),
                              if (section1 != null && section2 != null)
                                const SizedBox(width: 12),
                              if (section2 != null)
                                _buildSectionCompareCard(
                                  section2,
                                  counts2,
                                  const Color(0xFF3B82F6),
                                  label: 'B',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ── Summary + Chart ─────────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final summaryTable = Container(
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
                                columns: [
                                  const DataColumn(label: Text('Section')),
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
                                    color:
                                        WidgetStateProperty.resolveWith<Color?>(
                                          (states) {
                                            if (isA)
                                              return AppTheme.primaryColor
                                                  .withValues(alpha: 0.08);
                                            if (isB)
                                              return const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.08);
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                                child: const Text(
                                                  'A',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (isB) ...[
                                              const SizedBox(width: 5),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF3B82F6,
                                                  ).withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
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
                            const SizedBox(height: 10),
                            _analyticsInsight(
                              'all sections',
                              _sections.fold<Map<String, int>>(
                                {
                                  'Frustration': 0,
                                  'Instructional': 0,
                                  'Independent': 0,
                                },
                                (summary, section) {
                                  final counts = _countsForSection(section.id);
                                  for (final level in summary.keys) {
                                    summary[level] =
                                        summary[level]! + (counts[level] ?? 0);
                                  }
                                  return summary;
                                },
                              ),
                            ),
                          ],
                        ),
                      );

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
                                          'Reading Level Comparison by Section',
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
                            summaryTable,
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
                          Expanded(flex: 1, child: summaryTable),
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
