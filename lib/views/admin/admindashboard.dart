import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/practice_set/manage_practice_set.dart';
import 'package:ireader_web/views/admin/readingcoordinator/manage_rc.dart';
import 'package:ireader_web/views/admin/schoolyear/manage_schoolyear.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _chartImageUrl;
  String? _femalechartImageUrl;
  String? _malechartImageUrl;

  int notassessedCountStudents = 0;
  int frustrationCountStudents = 0;
  int instructionalCountStudents = 0;
  int independentCountStudents = 0;

  int notassessedCountMale = 0;
  int frustrationCountMale = 0;
  int instructionalCountMale = 0;
  int independentCountMale = 0;

  int notassessedCountFemale = 0;
  int frustrationCountFemale = 0;
  int instructionalCountFemale = 0;
  int independentCountFemale = 0;

  @override
  void initState() {
    super.initState();
    _generateChart();
    _fetchschoolyear();
    _fetchstudentmale();
    _fetchstudentfemale();
    _generatemaleChart();
    _generatefemaleChart();
  }

  Future<void> _fetchschoolyear() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schoolyears')
          .get();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load School Years: $e")),
      );
    }
  }

  Future<Map<String, int>> _fetchstudentmale() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('gender', isEqualTo: 'Male')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      int notyetassessedCountMale = 0;
      int frustrationCountMale = 0;
      int instructionalCountMale = 0;
      int independentCountMale = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final level =
            data['readlevel'] ?? ''; // adjust the field name if needed

        if (level == 'Frustration') {
          frustrationCountMale++;
        } else if (level == 'Instructional') {
          instructionalCountMale++;
        } else if (level == 'Independent') {
          independentCountMale++;
        } else if (level == 'NOT YET ASSESSED') {
          notyetassessedCountMale++;
        }
      }

      return {
        'NOT YET ASSESSED': notyetassessedCountMale,
        'Frustration': frustrationCountMale,
        'Instructional': instructionalCountMale,
        'Independent': independentCountMale,
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load Students gender: $e")),
      );
      return {
        'NOT YET ASSESSED': 0,
        'Frustration': 0,
        'Instructional': 0,
        'Independent': 0,
      };
    }
  }

  Future<Map<String, int>> _fetchstudentfemale() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('gender', isEqualTo: 'Female')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      int frustrationCountFemale = 0;
      int instructionalCountFemale = 0;
      int independentCountFemale = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final level =
            data['readlevel'] ?? ''; // adjust the field name if needed

        if (level == 'Frustration') {
          frustrationCountFemale++;
        } else if (level == 'Instructional') {
          instructionalCountFemale++;
        } else if (level == 'Independent') {
          independentCountFemale++;
        }
      }

      return {
        'Frustration': frustrationCountFemale,
        'Instructional': instructionalCountFemale,
        'Independent': independentCountFemale,
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load Students gender: $e")),
      );
      return {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
    }
  }

  Future<Map<String, int>> _fetchstudentcurrentlevel() async {
    try {
      final snapshot = await _firestore.collection('students').get();

      int notassessedCountStudents = 0;
      int frustrationCountStudents = 0;
      int instructionalCountStudents = 0;
      int independentCountStudents = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final level =
            data['readlevel'] ?? ''; // adjust the field name if needed

        if (level == 'Frustration') {
          frustrationCountStudents++;
        } else if (level == 'Instructional') {
          instructionalCountStudents++;
        } else if (level == 'Independent') {
          independentCountStudents++;
        } else if (level == 'NOT YET ASSESSED') {
          notassessedCountStudents++;
        }
      }

      return {
        'NOT YET ASSESSED': notassessedCountStudents,
        'Frustration': frustrationCountStudents,
        'Instructional': instructionalCountStudents,
        'Independent': independentCountStudents,
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load studentreadlevel: $e")),
      );
      return {'Frustration': 0, 'Instructional': 0, 'Independent': 0};
    }
  }

  Future<void> _generatemaleChart() async {
    final counts = await _fetchstudentmale();

    setState(() {
      notassessedCountMale = counts['NOT YET ASSESSED'] ?? 0;
      frustrationCountMale = counts['Frustration'] ?? 0;
      instructionalCountMale = counts['Instructional'] ?? 0;
      independentCountMale = counts['Independent'] ?? 0;
    });

    final chartConfig = {
      "type": "pie",
      "data": {
        "datasets": [
          {
            "label": "Student Reading Levels",
            "data": [
              counts['NOT YET ASSESSED'],
              counts['Frustration'],
              counts['Instructional'],
              counts['Independent'],
            ],
            "backgroundColor": [
              "rgb(128, 128, 128)",
              "rgb(0, 255, 255)",
              "rgb(255, 215, 128)",
              "rgb(144, 238, 144)",
            ],
          },
        ],
      },
      "options": {
        "plugins": {
          "legend": {"position": "right"},
          "title": {
            "display": true,
            "text": "Overall Student Reading Level",
            "font": {"size": 20},
          },
        },
      },
    };

    final encodedConfig = jsonEncode(chartConfig);
    final chartUrl = 'https://quickchart.io/chart?c=$encodedConfig';

    setState(() {
      _malechartImageUrl = chartUrl;
    });
  }

  Future<void> _generatefemaleChart() async {
    final counts = await _fetchstudentfemale();

    setState(() {
      notassessedCountFemale = counts['NOT YET ASSESSED'] ?? 0;
      frustrationCountFemale = counts['Frustration'] ?? 0;
      instructionalCountFemale = counts['Instructional'] ?? 0;
      independentCountFemale = counts['Independent'] ?? 0;
    });

    final chartConfig = {
      "type": "pie",
      "data": {
        "datasets": [
          {
            "label": "Student Reading Levels",
            "data": [
              counts['NOT YET ASSESSED'],
              counts['Frustration'],
              counts['Instructional'],
              counts['Independent'],
            ],
            "backgroundColor": [
              "rgb(128, 128, 128)",
              "rgb(0, 255, 255)",
              "rgb(255, 215, 128)",
              "rgb(144, 238, 144)",
            ],
          },
        ],
      },
      "options": {
        "plugins": {
          "legend": {"position": "right"},
          "title": {
            "display": true,
            "text": "Overall Student Reading Level",
            "font": {"size": 20},
          },
        },
      },
    };

    final encodedConfig = jsonEncode(chartConfig);
    final chartUrl = 'https://quickchart.io/chart?c=$encodedConfig';

    setState(() {
      _femalechartImageUrl = chartUrl;
    });
  }

  Future<void> _generateChart() async {
    final counts = await _fetchstudentcurrentlevel();

    setState(() {
      notassessedCountStudents = counts['NOT YET ASSESSED'] ?? 0;
      frustrationCountStudents = counts['Frustration'] ?? 0;
      instructionalCountStudents = counts['Instructional'] ?? 0;
      independentCountStudents = counts['Independent'] ?? 0;
    });

    final chartConfig = {
      "type": "pie",
      "data": {
        "datasets": [
          {
            "label": "Student Reading Levels",
            "data": [
              counts['NOT YET ASSESSED'],
              counts['Frustration'],
              counts['Instructional'],
              counts['Independent'],
            ],
            "backgroundColor": [
              "rgb(0, 255, 255)",
              "rgb(255, 215, 128)",
              "rgb(144, 238, 144)",
            ],
          },
        ],
      },
      "options": {
        "plugins": {
          "legend": {"position": "right"},
          "title": {
            "display": true,
            "text": "Overall Student Reading Level",
            "font": {"size": 20},
          },
        },
      },
    };

    final encodedConfig = jsonEncode(chartConfig);
    final chartUrl = 'https://quickchart.io/chart?c=$encodedConfig';

    setState(() {
      _chartImageUrl = chartUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.file_upload, size: 20),
              label: const Text('Export Result'),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import Result clicked!')),
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
                color: AppTheme.primaryColor,
              ),
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(fontSize: 20, color: AppTheme.primaryColor),
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
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Set Up',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Section
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'Welcome to the Admin Dashboard!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Monitor students' reading comprehension levels."
                          "You can view insights, manage users, and explore performance trends.",
                          style: TextStyle(
                            fontSize: 18,
                            color: AppTheme.textPrimaryColor,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          "Total Number of Frustration Student Level: $frustrationCountStudents",
                        ),
                        Text(
                          "Total Number of Instructional Student Level: $instructionalCountStudents",
                        ),
                        Text(
                          "Total Number of Independent Student Level: $independentCountStudents",
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 4,
                          width: 100,
                          color: AppTheme.primaryColor.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                  // Right Section
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: _chartImageUrl == null
                          ? const CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _chartImageUrl!,
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Male Chart
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        const Text(
                          'Male Student Reading Level',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _malechartImageUrl == null
                            ? const CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              )
                            : SizedBox(
                                height: 325, // adjust the chart size here
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _malechartImageUrl!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 10),
                        Text(
                          'Total Number of Frustration Level Male Students: $frustrationCountMale',
                        ),
                        Text(
                          'Total Number of Instructional Level Male Students: $instructionalCountMale',
                        ),
                        Text(
                          'Total Number of Independent Level Male Students: $independentCountMale',
                        ),
                      ],
                    ),
                  ),

                  // Female Chart
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        const Text(
                          'Female Student Reading Level',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _femalechartImageUrl == null
                            ? const CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              )
                            : SizedBox(
                                height: 325, // adjust the chart size here
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _malechartImageUrl!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 10),
                        Text(
                          'Total Number of Frustration Level Female Students: $frustrationCountFemale',
                        ),
                        Text(
                          'Total Number of Instructional Level Female Students: $instructionalCountFemale',
                        ),
                        Text(
                          'Total Number of Independent Level Female Students: $independentCountFemale',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
