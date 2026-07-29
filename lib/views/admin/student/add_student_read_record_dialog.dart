import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentoverallresult.dart';
import 'package:ireader_web/model/studentreadingresult.dart';
import 'package:ireader_web/theme.dart';

class AddStudentReadRecordDialog extends StatefulWidget {
  final Student student;
  const AddStudentReadRecordDialog({super.key, required this.student});

  @override
  State<AddStudentReadRecordDialog> createState() =>
      _AddStudentReadRecordDialogState();
}

class _AddStudentReadRecordDialogState
    extends State<AddStudentReadRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _totalwordscontroller;
  late TextEditingController _totalmiscuescontroller;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _assessments = [];
  List<QueryDocumentSnapshot> _studentlevelhistory = [];
  List<QueryDocumentSnapshot> compassessment = [];
  String? _selectedassessmentid;
  int _assessmentTotalWords = 0;
  String _assessmentAccessCode = "";

  @override
  void initState() {
    _totalwordscontroller = TextEditingController();
    _totalmiscuescontroller = TextEditingController();
    _fetchAssessment();
    super.initState();
  }

  Future<void> _fetchComprehensionAssessment() async {
    final snapshot = await _firestore
        .collection("assessment")
        .where('assessmentid', isEqualTo: _selectedassessmentid)
        .where('schoolyearid', isEqualTo: widget.student.schoolyearid)
        .get();
    setState(() {
      compassessment = snapshot.docs;
    });
  }

  Future<void> _fetchstudentreadhistory() async {
    final snapshot = await _firestore.collection("overallresult").get();
    setState(() {
      _studentlevelhistory = snapshot.docs;
    });
  }

  Future<void> _fetchAssessment() async {
    final snapshot = await _firestore
        .collection("assessment")
        .where('schoolyearid', isEqualTo: widget.student.schoolyearid)
        .get();
    setState(() {
      _assessments = snapshot.docs;
    });
  }

  // Helper used by the UI dropdown to load assessments once and return id/title
  Future<List<Map<String, String>>> _loadAssessmentsForDropdown() async {
    final snapshot = await _firestore
        .collection('assessment')
        .where('schoolyearid', isEqualTo: widget.student.schoolyearid)
        .get();

    return snapshot.docs.map((doc) {
      final data = (doc.data() is Map)
          ? Map<String, dynamic>.from(doc.data() as Map)
          : <String, dynamic>{};
      final title =
          (data['assessmenttitle'] as String?) ??
          (data['assessmentTitle'] as String?) ??
          (data['title'] as String?) ??
          doc.id;
      return {'id': doc.id, 'title': title};
    }).toList();
  }

  int calculatetotalread() {
    double totalwordsread = _assessmentTotalWords.toDouble();
    double totalmiscues = double.tryParse(_totalmiscuescontroller.text) ?? 0.0;
    double result = ((totalwordsread - totalmiscues) / totalwordsread) * 100;
    int percentageresult = result.round();

    return percentageresult;
  }

  String calculatereadingresultpercentage() {
    double totalwordsread = _assessmentTotalWords.toDouble();
    double totalmiscues = double.tryParse(_totalmiscuescontroller.text) ?? 0.0;

    double result = ((totalwordsread - totalmiscues) / totalwordsread) * 100;

    int percentageresult = result.round();

    if (percentageresult >= 97) {
      return "Independent";
    }
    if (percentageresult >= 90) {
      return "Instructional";
    } else {
      return "Frustration";
    }
  }

  Future<void> SaveReadingRecord() async {
    if (!_formKey.currentState!.validate()) return;
    // 🚨 DUPLICATE CHECK
    final existingReadingResult = await _firestore
        .collection('readingresult')
        .where('studentid', isEqualTo: widget.student.id)
        .where('assessmentid', isEqualTo: _selectedassessmentid)
        .limit(1)
        .get();

    if (existingReadingResult.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This student is already done with reading assessment.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final addreadingresult = "${widget.student.id}_${_selectedassessmentid!}";

      await _firestore
          .collection("readingresult")
          .doc(addreadingresult)
          .set(
            StudentReadingresult(
              id: addreadingresult,
              studentid: widget.student.id,
              assessmentid: _selectedassessmentid!,
              totalwordsread: _totalwordscontroller.text.trim(),
              totalmiscues: _totalmiscuescontroller.text.trim(),
              totalreadingresult: calculatetotalread(),
              readinglevel: calculatereadingresultpercentage(),
            ).toMap(),
            SetOptions(merge: true),
          );

      await _firestore.collection('students').doc(widget.student.id).update({
        'readingresult': calculatereadingresultpercentage(),
      });

      // final newstudentreadingresult = _firestore
      //     .collection("readingresult")
      //     .doc()
      //     .id;

      // await _firestore
      //     .collection("readingresult")
      //     .doc(newstudentreadingresult)
      //     .set(
      //       StudentReadingresult(
      //         id: newstudentreadingresult,
      //         studentid: widget.student.id,
      //         assessmentid: _selectedassessmentid!,
      //         totalwordsread: _totalwordscontroller.text.trim(),
      //         totalmiscues: _totalmiscuescontroller.text.trim(),
      //         totalreadingresult: calculatetotalread(),
      //         readinglevel: calculatereadingresultpercentage(),
      //       ).toMap(),
      //     );

      // 📝 If no assessment result, only save reading result to history

      // await _firestore
      //     .collection("overallresult")
      //     .doc(newstudentlevelhistory)
      //     .set(
      //       studentoverallresult(
      //         id: newstudentlevelhistory,
      //         studentid: widget.student.id,
      //         assessmentid: _selectedassessmentid!,
      //         wordreadresult: calculatereadingresultpercentage(),
      //         readcompresult: 'Comprehension Assessment Not Taken',
      //         readlevel: calculatereadingresultpercentage(),
      //       ).toMap(),
      //     );
      // 🔍 Fetch the student's assessment result from Firestore
      final assessmentSnapshot = await _firestore
          .collection('comprehensionresult')
          .where('studentid', isEqualTo: widget.student.id)
          .where('assessmentid', isEqualTo: _selectedassessmentid)
          .limit(1)
          .get();

      // 🧩 Compute current Word Reading result (from your function)
      final wordReading = calculatereadingresultpercentage();
      String finalProfile = wordReading; // default if no comprehension data

      // 🧠 If the student has a comprehension result
      if (assessmentSnapshot.docs.isNotEmpty) {
        final data = assessmentSnapshot.docs.first.data();
        final comprehension = data['result'] ?? '';

        // ✅ Apply rubric logic
        if (wordReading == 'Independent' && comprehension == 'Independent') {
          finalProfile = 'Independent';
        } else if (wordReading == 'Independent' &&
            comprehension == 'Instructional') {
          finalProfile = 'Instructional';
        } else if (wordReading == 'Instructional' &&
            comprehension == 'Independent') {
          finalProfile = 'Instructional';
        } else if (wordReading == 'Instructional' &&
            comprehension == 'Frustration') {
          finalProfile = 'Frustration';
        } else if (wordReading == 'Frustration' &&
            comprehension == 'Instructional') {
          finalProfile = 'Frustration';
        } else if (wordReading == 'Frustration' &&
            comprehension == 'Frustration') {
          finalProfile = 'Frustration';
        }
        await _firestore.collection('students').doc(widget.student.id).update({
          'readlevel': finalProfile,
        });
      }

      final overallresultexist = await _firestore
          .collection('overallresult')
          .where('studentid', isEqualTo: widget.student.id)
          .where('assessmentid', isEqualTo: _selectedassessmentid)
          .limit(1)
          .get();

      if (overallresultexist.docs.isNotEmpty) {
        await _firestore
            .collection('overallresult')
            .doc(overallresultexist.docs.first.id)
            .update({
              'wordreadresult': calculatereadingresultpercentage(),
              'readlevel': finalProfile,
            });
      } else {
        final addoverallresult = studentoverallresult(
          id: 'id',
          studentid: widget.student.id,
          assessmentid: _selectedassessmentid!,
          wordreadresult: calculatereadingresultpercentage(),
          readcompresult: 'Not Started',
          readlevel: 'Not Started',
        );
        final addoverall = addoverallresult.toMap();
        final overalldocid = "${widget.student.id}_${_selectedassessmentid!}";

        await _firestore.collection('overallresult').doc(overalldocid).set({
          ...addoverall,
          'id': overalldocid,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student Read Record added successfully'),
          ),
        );
        Navigator.pop(context); // ✅ return to Manage Section
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add student record: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _totalwordscontroller.dispose();
    _totalmiscuescontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Save Student Reading Record",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "${widget.student.firstname} "
            "${widget.student.middlename ?? ""} "
            "${widget.student.lastname}",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<List<Map<String, String>>>(
                  future: _loadAssessmentsForDropdown(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snap.hasData || snap.data!.isEmpty) {
                      return const Text(
                        'No assessments available for this school year',
                      );
                    }

                    final items = snap.data!;

                    return DropdownButtonFormField<String>(
                      value: _selectedassessmentid,
                      decoration: const InputDecoration(
                        labelText: "Select Assessment",
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: items.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Text(m['title'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedassessmentid = value;

                          final selectedAssessment = _assessments.firstWhere(
                            (doc) => doc.id == value,
                          );

                          final data =
                              selectedAssessment.data() as Map<String, dynamic>;

                          _assessmentTotalWords = data['totalwords'] ?? 0;

                          _assessmentAccessCode = data['accesscode'] ?? "";

                          _totalwordscontroller.text = _assessmentTotalWords
                              .toString();
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return "Please Select Assessment";
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.text_fields, color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Total Words: $_assessmentTotalWords",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Access Code: $_assessmentAccessCode",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _totalmiscuescontroller,
                  decoration: InputDecoration(
                    labelText: "Student Total Miscues",
                    hintText: "Enter Total Miscues",
                    prefixIcon: Icon(Icons.close, color: AppTheme.primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please Enter Student Total Miscues";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : SaveReadingRecord,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Save Record"),
        ),
      ],
    );
  }
}
