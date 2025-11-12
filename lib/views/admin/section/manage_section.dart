import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/assessment/manage_assessment.dart';
import 'package:ireader_web/views/admin/section/add_section.dart';
import 'package:ireader_web/views/admin/student/manage_student.dart';

class ManageSection extends StatefulWidget {
  final SchoolYear schoolyear;

  const ManageSection({super.key, required this.schoolyear});

  @override
  State<ManageSection> createState() => _ManageSectionState();
}

class _ManageSectionState extends State<ManageSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Fetch counts of reading levels per section
  Future<Map<String, int>> _fetchStudentReadLevels(String sectionid) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .where('sectionid', isEqualTo: sectionid)
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      int frustration = 0;
      int instructional = 0;
      int independent = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final level = data['readlevel'] ?? '';
        if (level == 'Frustration') {
          frustration++;
        } else if (level == 'Instructional') {
          instructional++;
        } else if (level == 'Independent') {
          independent++;
        }
      }

      return {
        'Frustration': frustration,
        'Instructional': instructional,
        'Independent': independent,
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load student levels: $e")),
      );
      return {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
    }
  }

  // ✅ Generate chart per section
  Future<String> _generateChartUrl(String sectionid) async {
    final counts = await _fetchStudentReadLevels(sectionid);
    final chartConfig = {
      "type": "pie",
      "data": {
        "labels": ["Frustration", "Instructional", "Independent"],
        "datasets": [
          {
            "data": [
              counts['Frustration'],
              counts['Instructional'],
              counts['Independent'],
            ],
            "backgroundColor": [
              "rgb(0, 255, 255)", // Frustration
              "rgb(255, 215, 128)", // Instructional
              "rgb(144, 238, 144)", // Independent
            ],
          },
        ],
      },
      "options": {
        "plugins": {
          "legend": {"position": "right"},
          "title": {
            "display": true,
            "text": "Reading Levels",
            "font": {"size": 16},
          },
        },
      },
    };
    final encodedConfig = Uri.encodeComponent(jsonEncode(chartConfig));
    return 'https://quickchart.io/chart?c=$encodedConfig&width=900&height=600&devicePixelRatio=3';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          "Sections - School Year: ${widget.schoolyear.schoolyearstart}-${widget.schoolyear.schoolyearend}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.assessment),
              label: const Text('Manage Assessments'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ManageAssessment(schoolyear: widget.schoolyear),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Section'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddSectionScreen(schoolyear: widget.schoolyear),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ✅ Display sections
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('sections')
            .where('schoolyearid', isEqualTo: widget.schoolyear.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No Sections Found for this School Year."),
            );
          }

          final sections = snapshot.data!.docs
              .map(
                (doc) =>
                    Section.fromMap(doc.id, doc.data() as Map<String, dynamic>),
              )
              .toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageStudentScreen(
                        section: section,
                        schoolyear: widget.schoolyear,
                      ),
                    ),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 Section Name
                        Center(
                          child: Text(
                            section.sectionname,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // 🔹 Teacher
                        FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection("teachers")
                              .doc(section.teacherid)
                              .get(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Text("Loading teacher...");
                            }
                            final t = snap.data!;
                            return Center(
                              child: Text(
                                "Teacher: ${t['firstname']} ${t['lastname']}",
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 6),

                        // 🔹 Student Count
                        FutureBuilder<QuerySnapshot>(
                          future: _firestore
                              .collection('students')
                              .where(
                                'schoolyearid',
                                isEqualTo: widget.schoolyear.id,
                              )
                              .where('sectionid', isEqualTo: section.id)
                              .where('status', isEqualTo: 'ACTIVE')
                              .get(),
                          builder: (context, countSnap) {
                            if (!countSnap.hasData) {
                              return const Text("Counting students...");
                            }
                            final count = countSnap.data!.docs.length;
                            return Center(
                              child: Text(
                                "Total Students: $count",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 8),

                        // 🔹 Chart
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _generateChartUrl(section.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Text("No chart data");
                              }
                              return Center(
                                child: Image.network(
                                  snapshot.data!,
                                  height: 500,
                                  fit: BoxFit.contain,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
