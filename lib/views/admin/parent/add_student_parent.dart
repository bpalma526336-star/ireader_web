import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/parent.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';

class AddParentStudent extends StatefulWidget {
  final Parent? parent;

  const AddParentStudent({super.key, this.parent});

  @override
  State<AddParentStudent> createState() => _AddParentStudentState();
}

class _AddParentStudentState extends State<AddParentStudent> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  List<Student> _students = [];
  List<Section> _sections = [];
  List<SchoolYear> _schoolYears = [];

  final TextEditingController _searchController = TextEditingController();
  String? _selectedSectionId;
  String? _selectedSchoolYearId;

  // Each item represents one student selector.
  List<String?> _selectedStudentIds = [];

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _loadStudents();

    // Start with one student row.
    _selectedStudentIds.add(null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOAD STUDENTS
  // ==========================================

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        firestore.collection('students').get(),
        firestore.collection('sections').get(),
        firestore.collection('schoolyears').get(),
      ]);

      final studentsSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final sectionsSnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;
      final schoolYearsSnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      final students = studentsSnapshot.docs.map((doc) {
        return Student.fromMap(doc.id, doc.data());
      }).toList();
      final sections = sectionsSnapshot.docs.map((doc) {
        return Section.fromMap(doc.id, doc.data());
      }).toList();
      final schoolYears = schoolYearsSnapshot.docs.map((doc) {
        return SchoolYear.fromMap(doc.id, doc.data());
      }).toList();

      if (!mounted) return;

      setState(() {
        _students = students;
        _sections = sections;
        _schoolYears = schoolYears;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load students: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================
  // ADD NEW STUDENT ROW
  // ==========================================

  void _addStudentRow() {
    setState(() {
      _selectedStudentIds.add(null);
    });
  }

  // ==========================================
  // REMOVE STUDENT ROW
  // ==========================================

  void _removeStudentRow(int index) {
    setState(() {
      _selectedStudentIds.removeAt(index);
    });
  }

  // ==========================================
  // CHANGE SELECTED STUDENT
  // ==========================================

  void _changeStudent(int index, String? studentId) {
    setState(() {
      _selectedStudentIds[index] = studentId;
    });
  }

  List<Student> get _filteredStudents {
    final search = _searchController.text.trim().toLowerCase();

    return _students.where((student) {
      final matchesSearch =
          search.isEmpty ||
          '${student.firstname} ${student.middlename ?? ''} ${student.lastname}'
              .toLowerCase()
              .contains(search) ||
          student.lrn.toLowerCase().contains(search);
      final matchesSection =
          _selectedSectionId == null || student.sectionid == _selectedSectionId;
      final matchesSchoolYear =
          _selectedSchoolYearId == null ||
          student.schoolyearid == _selectedSchoolYearId;

      return matchesSearch && matchesSection && matchesSchoolYear;
    }).toList();
  }

  String _sectionName(String sectionId) {
    return _sections
            .where((section) => section.id == sectionId)
            .map((section) => section.sectionname)
            .firstOrNull ??
        'Unknown section';
  }

  String _schoolYearName(String schoolYearId) {
    return _schoolYears
            .where((schoolYear) => schoolYear.id == schoolYearId)
            .map(
              (schoolYear) =>
                  '${schoolYear.schoolyearstart} - ${schoolYear.schoolyearend}',
            )
            .firstOrNull ??
        'Unknown school year';
  }

  // ==========================================
  // SAVE
  // ==========================================

  Future<void> addparentstudent() async {
    if (widget.parent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No parent selected.')));

      return;
    }

    // Remove empty selections.
    final studentIds = _selectedStudentIds.whereType<String>().toList();

    if (studentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student.')),
      );

      return;
    }

    // Prevent duplicates in the form.
    if (studentIds.toSet().length != studentIds.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot select the same student twice.'),
        ),
      );

      return;
    }

    // Prevent adding students already assigned
    // to this parent.
    final existingStudentIds = widget.parent!.studentids ?? [];

    final duplicateExisting = studentIds.any(
      (id) => existingStudentIds.contains(id),
    );

    if (duplicateExisting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'One or more students are already assigned to this parent.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await firestore.collection('parents').doc(widget.parent!.id).update({
        'studentids': FieldValue.arrayUnion(studentIds),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student(s) added successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Students to '
          '${widget.parent?.firstname ?? ''} '
          '${widget.parent?.lastname ?? ''}',
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Students',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text('Add one or more students to this parent.'),

                  const SizedBox(height: 24),

                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search students',
                      hintText: 'Name or LRN',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final sectionFilter = DropdownButtonFormField<String>(
                        value: _selectedSectionId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by section',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All sections'),
                          ),
                          ..._sections.map(
                            (section) => DropdownMenuItem<String>(
                              value: section.id,
                              child: Text(section.sectionname),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSectionId = value);
                        },
                      );
                      final schoolYearFilter = DropdownButtonFormField<String>(
                        value: _selectedSchoolYearId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by school year',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All school years'),
                          ),
                          ..._schoolYears.map(
                            (schoolYear) => DropdownMenuItem<String>(
                              value: schoolYear.id,
                              child: Text(
                                '${schoolYear.schoolyearstart} - '
                                '${schoolYear.schoolyearend}',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSchoolYearId = value);
                        },
                      );

                      if (constraints.maxWidth < 600) {
                        return Column(
                          children: [
                            sectionFilter,
                            const SizedBox(height: 12),
                            schoolYearFilter,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: sectionFilter),
                          const SizedBox(width: 12),
                          Expanded(child: schoolYearFilter),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ==================================
                  // DYNAMIC STUDENT ROWS
                  // ==================================
                  ...List.generate(_selectedStudentIds.length, (index) {
                    return _buildStudentRow(index);
                  }),

                  if (_filteredStudents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'No students match the current search and filters.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ==================================
                  // ADD STUDENT BUTTON
                  // ==================================
                  OutlinedButton.icon(
                    onPressed: _addStudentRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Student'),
                  ),

                  const SizedBox(height: 30),

                  // ==================================
                  // SAVE BUTTON
                  // ==================================
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : addparentstudent,
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Students'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // STUDENT ROW
  // ==========================================

  Widget _buildStudentRow(int index) {
    final selectedId = _selectedStudentIds[index];

    // IDs already assigned to this parent.
    final existingIds = widget.parent?.studentids ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Student dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedId,
              decoration: InputDecoration(
                labelText: 'Student ${index + 1}',
                border: const OutlineInputBorder(),
              ),

              items: _students
                  .where((student) {
                    if (!_filteredStudents.contains(student)) {
                      final isSelected = selectedId == student.id;
                      if (!isSelected) return false;
                    }

                    // Don't show students already
                    // assigned to this parent.
                    if (existingIds.contains(student.id)) {
                      return false;
                    }

                    // Don't allow the same student
                    // to be selected in another row.
                    final selectedElsewhere = _selectedStudentIds
                        .asMap()
                        .entries
                        .any((entry) {
                          return entry.key != index &&
                              entry.value == student.id;
                        });

                    return !selectedElsewhere;
                  })
                  .map((student) {
                    return DropdownMenuItem<String>(
                      value: student.id,
                      child: Text(
                        '${student.firstname} '
                        '${student.lastname} | '
                        '${_sectionName(student.sectionid)} | '
                        '${_schoolYearName(student.schoolyearid)} | '
                        'LRN: ${student.lrn}',
                      ),
                    );
                  })
                  .toList(),

              onChanged: (value) {
                _changeStudent(index, value);
              },
            ),
          ),

          const SizedBox(width: 10),

          // Delete row button
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              _removeStudentRow(index);
            },
          ),
        ],
      ),
    );
  }
}
