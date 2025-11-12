import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/admin/practice_set/manage_practice_set.dart';
import 'package:ireader_web/views/admin/readingcoordinator/manage_rc.dart';
import 'package:ireader_web/views/admin/section/manage_section.dart';
import 'package:ireader_web/views/admin/schoolyear/add_schoolyear.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';

class ManageSchoolyearScreen extends StatefulWidget {
  const ManageSchoolyearScreen({super.key});

  @override
  State<ManageSchoolyearScreen> createState() => _ManageSchoolyearScreenState();
}

class _ManageSchoolyearScreenState extends State<ManageSchoolyearScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches student counts per reading level for a specific school year
  Future<Map<String, int>> _fetchStudentReadLevels(String schoolyearid) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('schoolyearid', isEqualTo: schoolyearid)
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
        SnackBar(
          content: Text(
            "Failed to load student read levels for school year: $e",
          ),
        ),
      );
      return {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
    }
  }

  /// Builds the QuickChart pie chart URL for a given school year
  Future<String> _generateChartUrl(String schoolyearid) async {
    final counts = await _fetchStudentReadLevels(schoolyearid);

    final chartConfig = {
      "type": "pie",
      "data": {
        "datasets": [
          {
            "label": "Reading Level",
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
        "labels": ["Frustration", "Instructional", "Independent"],
      },
      "options": {
        "plugins": {
          "legend": {"position": "right"},
          "title": {
            "display": true,
            "text": "Student Reading Levels by School Year",
            "font": {"size": 18},
          },
        },
      },
    };

    final encodedConfig = jsonEncode(chartConfig);
    return 'https://quickchart.io/chart?c=$encodedConfig';
  }

  /// Fetches all school years from Firestore
  Stream<List<SchoolYear>> _fetchSchoolYears() {
    return _firestore
        .collection('schoolyears')
        .orderBy('schoolyearstart', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SchoolYear.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage School Year"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add School Year'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddSchoolyearScreen(schoolyear: null),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.backgroundColor),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Image.asset(
                      'assets/Department-of-Education-DepEd-Seal-300x300.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'iReader',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboard(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.book, color: AppTheme.textPrimaryColor),
              title: const Text(
                'Practice Set',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManagePracticeSet(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.primaryColor,
              ),
              title: const Text(
                'Set Up',
                style: TextStyle(fontSize: 20, color: AppTheme.primaryColor),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageSchoolyearScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageAdminScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.integration_instructions,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Reading Coordinators',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageRcScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Teachers',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageTeacherScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<SchoolYear>>(
        stream: _fetchSchoolYears(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No School Year Found"));
          }

          final schoolYears = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: schoolYears.length,
            itemBuilder: (context, index) {
              final schoolyear = schoolYears[index];

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ManageSection(schoolyear: schoolyear),
                    ),
                  );
                },
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            "School Year: ${schoolyear.schoolyearstart} - ${schoolyear.schoolyearend}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _generateChartUrl(schoolyear.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              } else if (snapshot.hasError) {
                                return const Center(
                                  child: Text("Failed to load chart"),
                                );
                              } else if (!snapshot.hasData) {
                                return const Center(
                                  child: Text("No chart data available"),
                                );
                              }

                              final chartUrl = snapshot.data!;
                              return Center(child: Image.network(chartUrl));
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
