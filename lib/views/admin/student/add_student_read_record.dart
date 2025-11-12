import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/model/studentlevelhistory.dart';
import 'package:ireader_web/model/studentreadingresult.dart';
import 'package:ireader_web/theme.dart';

class AddStudentReadRecordScreen extends StatefulWidget {
  final Student student;

  const AddStudentReadRecordScreen({super.key, required this.student});

  @override
  State<AddStudentReadRecordScreen> createState() =>
      _AddStudentReadRecordScreenState();
}

class _AddStudentReadRecordScreenState
    extends State<AddStudentReadRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _totalwordscontroller;
  late TextEditingController _totalmiscuescontroller;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _assessments = [];
  List<QueryDocumentSnapshot> _studentlevelhistory = [];
  List<QueryDocumentSnapshot> compassessment = [];
  String? _selectedassessmentid;

  @override
  void initState() {
    _totalwordscontroller = TextEditingController();
    _totalmiscuescontroller = TextEditingController();
    _fetchAssessment();
    super.initState();
  }

  Future<void> _fetchComprehensionAssessment() async {
    final snapshot = await _firestore
        .collection("assessments")
        .where('assessmentid', isEqualTo: _selectedassessmentid)
        .get();
    setState(() {
      compassessment = snapshot.docs;
    });
  }

  Future<void> _fetchstudentreadhistory() async {
    final snapshot = await _firestore.collection("levelhistory").get();
    setState(() {
      _studentlevelhistory = snapshot.docs;
    });
  }

  Future<void> _fetchAssessment() async {
    final snapshot = await _firestore.collection("assessments").get();
    setState(() {
      _assessments = snapshot.docs;
    });
  }

  int calculatetotalread() {
    double totalwordsread = double.tryParse(_totalwordscontroller.text) ?? 0.0;
    double totalmiscues = double.tryParse(_totalmiscuescontroller.text) ?? 0.0;
    double result = ((totalwordsread - totalmiscues) / totalwordsread) * 100;
    int percentageresult = result.round();

    return percentageresult;
  }

  String calculatereadingresultpercentage() {
    double totalwordsread = double.tryParse(_totalwordscontroller.text) ?? 0.0;
    double totalmiscues = double.tryParse(_totalmiscuescontroller.text) ?? 0.0;

    double result = ((totalwordsread - totalmiscues) / totalwordsread) * 100;

    int percentageresult = result.round();

    if (percentageresult >= 97) {
      return "independent";
    }
    if (percentageresult >= 90) {
      return "instructional";
    } else {
      return "frustration";
    }
  }

  Future<void> SaveReadingRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final newstudentreadingresult = _firestore
          .collection("readingresult")
          .doc()
          .id;

      await _firestore
          .collection("readingresult")
          .doc(newstudentreadingresult)
          .set(
            StudentReadingresult(
              id: newstudentreadingresult,
              studentid: widget.student.id,
              assessmentid: _selectedassessmentid!,
              totalwordsread: _totalwordscontroller.text.trim(),
              totalmiscues: _totalmiscuescontroller.text.trim(),
              totalreadingresult: calculatetotalread(),
              readinglevel: calculatereadingresultpercentage(),
            ).toMap(),
          );

      // 📝 If no assessment result, only save reading result to history
      final newstudentlevelhistory = _firestore
          .collection("studentlevelhistory")
          .doc()
          .id;

      await _firestore
          .collection("studentlevelhistory")
          .doc(newstudentlevelhistory)
          .set(
            studentlevelhistory(
              id: newstudentlevelhistory,
              studentid: widget.student.id,
              assessmentid: _selectedassessmentid!,
              wordreadresult: calculatereadingresultpercentage(),
              readcompresult: 'Comprehension Assessment Not Taken',
              readlevel: calculatereadingresultpercentage(),
            ).toMap(),
          );

      // await _firestore.collection("studentlevelhistory").add({
      //   'studentid': widget.student.id,
      //   'assessmentid': _selectedassessmentid,
      //   'readlevel': calculatereadingresultpercentage(),
      // });

      // await _firestore.collection("studentreadingresult").add({
      //   'studentid': widget.student.id,
      //   'totalmiscues': _totalmiscuescontroller.text.trim(),
      //   'totalwordsread': _totalwordscontroller.text.trim(),
      //   "readlevel": calculatereadingresultpercentage(),
      //   "totalreadingresult": calculatetotalread(),
      // });
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
        if (wordReading == 'independent' && comprehension == 'independent') {
          finalProfile = 'independent';
        } else if (wordReading == 'independent' &&
            comprehension == 'instructional') {
          finalProfile = 'instructional';
        } else if (wordReading == 'instructional' &&
            comprehension == 'independent') {
          finalProfile = 'instructional';
        } else if (wordReading == 'instructional' &&
            comprehension == 'frustration') {
          finalProfile = 'frustration';
        } else if (wordReading == 'frustration' &&
            comprehension == 'instructional') {
          finalProfile = 'frustration';
        } else if (wordReading == 'frustration' &&
            comprehension == 'frustration') {
          finalProfile = 'frustration';
        }
        await _firestore.collection('students').doc(widget.student.id).update({
          'readlevel': finalProfile,
        });

        await _firestore
            .collection("studentlevelhistory")
            .doc(newstudentlevelhistory)
            .set(
              studentlevelhistory(
                id: newstudentlevelhistory,
                studentid: widget.student.id,
                assessmentid: _selectedassessmentid!,
                wordreadresult: calculatereadingresultpercentage(),
                readcompresult: comprehension,
                readlevel: finalProfile,
              ).toMap(),
            );
      } else {
        await _firestore.collection('students').doc(widget.student.id).update({
          'readlevel': 'Incomplete Assessment',
        });

        await _firestore
            .collection("studentlevelhistory")
            .doc(newstudentlevelhistory)
            .set(
              studentlevelhistory(
                id: newstudentlevelhistory,
                studentid: widget.student.id,
                assessmentid: _selectedassessmentid!,
                wordreadresult: calculatereadingresultpercentage(),
                readcompresult: 'Not Taking Comprehension Yet',
                readlevel: 'Incomplete Assessment',
              ).toMap(),
            );
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text("Add Student Read Records"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.read_more, size: 20),
              label: const Text('Save Student Reading Record'),
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
              onPressed: _isLoading ? null : SaveReadingRecord,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              "${widget.student.firstname} ${widget.student.middlename} ${widget.student.lastname} Reading Record",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedassessmentid,
              decoration: const InputDecoration(
                labelText: "Select Assessment",
                border: OutlineInputBorder(),
              ),
              items: _assessments.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text("${data['assessmenttitle'] ?? ''} ".trim()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedassessmentid = value;
                });
              },
              validator: (value) =>
                  value == null ? "Please Select Assessment" : null,
            ),
            const SizedBox(height: 16),

            // Section name input
            TextFormField(
              controller: _totalwordscontroller,
              decoration: InputDecoration(
                labelText: "Student Total Words Read",
                hintText: "Student Total Words Read",
                prefixIcon: Icon(
                  Icons.text_format,
                  color: AppTheme.primaryColor,
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? "Please Enter Student Total Words"
                  : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _totalmiscuescontroller,
              decoration: InputDecoration(
                labelText: "Student Total Words Miscues",
                hintText: "Student Total Words Miscues",
                prefixIcon: Icon(Icons.close, color: AppTheme.primaryColor),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? "Please Enter Student Total Miscues"
                  : null,
            ),
            const SizedBox(height: 32),

            // Save button (optional, duplicate of AppBar)
            Center(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : SaveReadingRecord,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Save Student Reading Record",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
