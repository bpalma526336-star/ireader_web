import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentassessmentresult.dart';
import 'package:ireader_web/model/studentlevelhistory.dart';
import 'package:ireader_web/model/studentreadingresult.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/student/add_student_read_record.dart';

class StudentProfileScreen extends StatefulWidget {
  final Student student;
  final SchoolYear schoolyear;
  final Section section;

  const StudentProfileScreen({
    super.key,
    required this.student,
    required this.schoolyear,
    required this.section,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<StudentReadingresult> studentprofilereadingresult = [];
  List<CompAssessmentResult> studentassessmentresult = [];
  List<studentlevelhistory> levelhistory = [];

  int _selectedFilter =
      0; // 0 = Profile, 1 = ReadLevel, 2 = ReadingResult, 3 = Assessment, 4 = History

  @override
  void initState() {
    super.initState();
  }

  Future<String> _getAssessmentName(String assessmentid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('assessment')
          .doc(assessmentid)
          .get();
      if (doc.exists) {
        return doc['assessmenttitle'] ?? 'Unnamed Assessment';
      }
      return 'Unknown Assessment';
    } catch (e) {
      return 'Unknown Assessment';
    }
  }

  //  Future<String> _getCompResultDetails(String compresultid) async {
  //   try {
  //     final doc = await FirebaseFirestore.instance
  //         .collection('compresultdetails')
  //         .doc(compresultid)
  //         .get();
  //     if (doc.exists) {
  //       final total = doc['totalitems'] ?? 0;
  //       final correct = doc['correctitems'] ?? 0;
  //       return '$correct / $total Correct';
  //     }
  //     return 'Unknown Result';
  //   } catch (e) {
  //     return 'Unknown Result';
  //   }
  // }

  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchStudentReadingResult(),
      _fetchStudentAssessmentResult(),
      _fetchStudentReadHistory(),
    ]);
  }

  Future<void> _fetchStudentReadingResult() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('readingresult')
        .where('studentid', isEqualTo: widget.student.id)
        .get();

    setState(() {
      studentprofilereadingresult = snapshot.docs
          .map((d) => StudentReadingresult.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> _fetchStudentAssessmentResult() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('comprehensionresult')
        .where('studentid', isEqualTo: widget.student.id)
        .get();

    setState(() {
      studentassessmentresult = snapshot.docs
          .map((d) => CompAssessmentResult.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> _fetchStudentReadHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('studentlevelhistory')
        .where('studentid', isEqualTo: widget.student.id)
        .get();

    setState(() {
      levelhistory = snapshot.docs
          .map((d) => studentlevelhistory.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Widget _buildChoiceChips() {
    final filters = [
      "Reading Results",
      "Assessment Results",
      "Read Level History",
    ];

    return Wrap(
      spacing: 8,
      children: List.generate(filters.length, (index) {
        final isSelected = _selectedFilter == index;
        return ChoiceChip(
          label: Text(
            filters[index],
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          selected: isSelected,
          selectedColor: AppTheme.primaryColor,
          backgroundColor: Colors.grey[200],
          onSelected: (_) => setState(() => _selectedFilter = index),
        );
      }),
    );
  }

  Widget _buildList<T>({
    required List<T> data,
    required String title,
    required Widget Function(T item) itemBuilder,
  }) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          "No records yet",
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: itemBuilder(data[index]),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedFilter) {
      // 🔹 Reading Results Stream
      case 0:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('studentreadingresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No Reading Results yet"));
            }

            final results = snapshot.data!.docs
                .map(
                  (doc) => StudentReadingresult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Assessment: ${item.assessmentid ?? 'N/A'}"),
                        Text("Total Miscues: ${item.totalmiscues ?? 'N/A'}"),
                        Text("Total Words: ${item.totalwordsread ?? 'N/A'}"),
                        Text("Reading Result: ${item.totalreadingresult}"),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

      // 🔹 Assessment Results Stream
      case 1:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('comprehensionresult')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No Assessment Results yet"));
            }

            final results = snapshot.data!.docs
                .map(
                  (doc) => CompAssessmentResult.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Assessment: ${item.assessmentid ?? 'N/A'}"),
                        Text(
                          "Correct Items: ${item.correctitems ?? 'Unknown'}",
                        ),
                        Text(
                          "Incorrect Items: ${item.incorrectitems ?? 'N/A'}",
                        ),
                        Text("Total Items: ${item.totalitems ?? 'N/A'}"),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

      // 🔹 Level History Stream (with async data fetch)
      case 2:
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('studentlevelhistory')
              .where('studentid', isEqualTo: widget.student.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No Level History yet"));
            }

            final histories = snapshot.data!.docs
                .map(
                  (doc) => studentlevelhistory.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.builder(
              itemCount: histories.length,
              itemBuilder: (context, index) {
                final item = histories[index];

                return FutureBuilder<String>(
                  future: _getAssessmentName(item.assessmentid),
                  builder: (context, snapshot) {
                    final assessmenttitle =
                        snapshot.data ?? "Unknown Assessment";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Assessment: $assessmenttitle"),
                            Text("word Reading Result: ${item.wordreadresult}"),
                            Text(
                              "Comprehension Result: ${item.readcompresult}",
                            ),
                            Text("Reading Level: ${item.readlevel}"),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Student Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundColor,
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload, size: 20),
              label: const Text('Add Read Record'),
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
                    builder: (context) =>
                        AddStudentReadRecordScreen(student: widget.student),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Column(
                children: [
                  // 🧑‍🎓 Student Name
                  Text(
                    "${widget.student.firstname} ${widget.student.middlename} ${widget.student.lastname}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // 📘 Student LRN
                  Text(
                    widget.student.lrn,
                    style: const TextStyle(color: AppTheme.textPrimaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // 🚻 Student Gender
                  Text(
                    widget.student.gender,
                    style: const TextStyle(color: AppTheme.textPrimaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  Text(
                    widget.student.readlevel,
                    style: const TextStyle(color: AppTheme.textPrimaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // 🧾 Student Status
                  Text(
                    widget.student.status,
                    style: const TextStyle(color: AppTheme.textPrimaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 🧩 Choice Chips for Tabs
            _buildChoiceChips(),
            const SizedBox(height: 16),

            // 🪶 Selected Tab Content (uses StreamBuilder too)
            Expanded(child: _buildSelectedTab()),
          ],
        ),
      ),
    );
  }
}
