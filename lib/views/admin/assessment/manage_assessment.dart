import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/assessment.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/assessment/add_assessment.dart';
import 'package:ireader_web/views/admin/assessment/edit_assessment.dart';

class ManageAssessment extends StatefulWidget {
  final SchoolYear schoolyear;
  const ManageAssessment({super.key, required this.schoolyear});

  @override
  State<ManageAssessment> createState() => _ManageAssessmentState();
}

class _ManageAssessmentState extends State<ManageAssessment> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to fetch all assessments under a school year
  Stream<QuerySnapshot> _fetchAssessments() {
    return _firestore
        .collection('assessments')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .snapshots();
  }

  // Delete assessment
  void _deleteAssessment(String id) async {
    await _firestore.collection('assessments').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          "Assessments - School Year: ${widget.schoolyear.schoolyearstart}-${widget.schoolyear.schoolyearend}",
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.assessment, size: 20),
              label: const Text('Create Assessment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddAssessmentScreen(
                      schoolyear: widget.schoolyear,
                      schoolyearid: widget.schoolyear.id,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchAssessments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No assessments found.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final assessments = snapshot.data!.docs
              .map(
                (doc) => Assessment.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assessments.length,
            itemBuilder: (context, index) {
              final assessment = assessments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    assessment.assessmenttitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text("Visibility: ${assessment.visibility}"),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "edit",
                        child: ListTile(
                          leading: const Icon(
                            Icons.edit,
                            color: AppTheme.primaryColor,
                          ),
                          title: const Text("Edit"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: ListTile(
                          leading: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          title: const Text("Delete"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      // if (value == "edit") {
                      //   Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (context) => EditAssessmentScreen(
                      //         assessment: assessment,
                      //         schoolyear: widget.schoolyear,
                      //       ),
                      //     ),
                      //   );
                      // } else if (value == "delete") {
                      //   _deleteAssessment(assessment.id);
                      // }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
