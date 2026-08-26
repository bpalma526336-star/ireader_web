import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/parent.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/parent/add_student_parent.dart';

class ViewParentStudent extends StatefulWidget {
  final Parent? parent;

  const ViewParentStudent({super.key, this.parent});

  @override
  State<ViewParentStudent> createState() => _ViewParentStudentState();
}

class _ViewParentStudentState extends State<ViewParentStudent> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<List<Student>> getStudentsStream() {
    if (widget.parent == null) {
      return Stream.value([]);
    }

    final studentIds = widget.parent!.studentids ?? [];

    if (studentIds.isEmpty) {
      return Stream.value([]);
    }

    return firestore
        .collection('students')
        .where(FieldPath.documentId, whereIn: studentIds)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Student.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  Future<List<Student>> getStudentsUnderParent() async {
    if (widget.parent == null) {
      return [];
    }

    final studentIds = widget.parent!.studentids ?? [];

    if (studentIds.isEmpty) {
      return [];
    }

    final snapshot = await firestore
        .collection('students')
        .where(FieldPath.documentId, whereIn: studentIds)
        .get();

    return snapshot.docs.map((doc) {
      return Student.fromMap(doc.id, doc.data());
    }).toList();
  }

  Future<SchoolYear?> getSchoolYear(String schoolYearId) async {
    if (schoolYearId.isEmpty) {
      return null;
    }

    final doc = await firestore
        .collection('schoolyears')
        .doc(schoolYearId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return SchoolYear.fromMap(doc.id, doc.data()!);
  }

  Future<Section?> getSection(String sectionId) async {
    if (sectionId.isEmpty) {
      return null;
    }

    final doc = await firestore.collection('sections').doc(sectionId).get();

    if (!doc.exists) {
      return null;
    }

    return Section.fromMap(doc.id, doc.data()!);
  }

  @override
  Widget build(BuildContext context) {
    final parentName = widget.parent == null
        ? 'Parent'
        : '${widget.parent!.firstname} ${widget.parent!.lastname}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Students of $parentName',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Student',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddParentStudent(parent: widget.parent),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),

      body: StreamBuilder<List<Student>>(
        stream: getStudentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final students = snapshot.data ?? [];

          if (students.isEmpty) {
            return _emptyState('This parent has no students assigned.');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(parentName, students.length),
                const SizedBox(height: 16),
                Text('Assigned Students', style: AppTheme.sectionTitleStyle),
                const SizedBox(height: 10),
                _buildStudentsCard(students),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String parentName, int studentCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              parentName == 'Parent' ? '?' : parentName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 16,
                      color: AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$studentCount ${studentCount == 1 ? 'student' : 'students'} assigned',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsCard(List<Student> students) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: students.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildStudentRow(students[index]),
      ),
    );
  }

  Widget _buildStudentRow(Student student) {
    final fullName = '${student.firstname} ${student.lastname}'.trim();
    final initial = student.firstname.isNotEmpty
        ? student.firstname[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: AppTheme.textSecondaryColor,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      'LRN: ${student.lrn}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),

                    const SizedBox(width: 15),
                    FutureBuilder<Section?>(
                      future: getSection(student.sectionid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(
                            'Section: Loading...',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondaryColor,
                            ),
                          );
                        }

                        if (snapshot.hasError || snapshot.data == null) {
                          return const Text(
                            'Section: Not found',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondaryColor,
                            ),
                          );
                        }

                        final section = snapshot.data!;

                        return Text(
                          'Section: '
                          '${section.sectionname}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondaryColor,
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 15),

                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppTheme.textSecondaryColor,
                    ),

                    const SizedBox(width: 15),

                    FutureBuilder<SchoolYear?>(
                      future: getSchoolYear(student.schoolyearid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(
                            'School Year: Loading...',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondaryColor,
                            ),
                          );
                        }

                        if (snapshot.hasError || snapshot.data == null) {
                          return const Text(
                            'School Year: Not found',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondaryColor,
                            ),
                          );
                        }

                        final schoolYear = snapshot.data!;

                        return Text(
                          'School Year: '
                          '${schoolYear.schoolyearstart}-'
                          '${schoolYear.schoolyearend}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondaryColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
        ],
      ),
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
}
