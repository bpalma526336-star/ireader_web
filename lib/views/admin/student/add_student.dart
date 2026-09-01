import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? student;
  final Section section;
  final SchoolYear schoolyear;
  const AddStudentScreen({
    super.key,
    required this.section,
    required this.schoolyear,
    required this.student,
  });

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstnamecontroller;
  late TextEditingController _middlenamecontroller;
  late TextEditingController _lastnamecontroller;
  late TextEditingController lrncontroller;
  late TextEditingController gendercontroller;
  final List<String> gender = ["Male", "Female"];
  late TextEditingController gstscorecontroller;
  String? selectedgender;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String status = "active";
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize the text controllers
    lrncontroller = TextEditingController(text: widget.student?.lrn ?? '');
    _firstnamecontroller = TextEditingController(
      text: widget.student?.firstname ?? '',
    );
    _middlenamecontroller = TextEditingController(
      text: widget.student?.middlename ?? '',
    );
    _lastnamecontroller = TextEditingController(
      text: widget.student?.lastname ?? '',
    );
    gstscorecontroller = TextEditingController(
      text: widget.student?.gstscore ?? '',
    );
    gendercontroller = TextEditingController(
      text: widget.student?.gender ?? '',
    );

    selectedgender =
        widget.student?.gender; // Set the gender if updating a student
  }

  String gradelevelread() {
    int score = int.tryParse(gstscorecontroller.text) ?? 0;

    if (score <= 7) {
      return "Grade 1";
    } else if (score <= 13) {
      return "Grade 2";
    } else {
      return "NOT QUALIFIED";
    }
  }

  Future<void> SaveStudent() async {
    if (!_formKey.currentState!.validate()) {
      int gst = int.tryParse(gstscorecontroller.text.trim()) ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill in all required fields"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    int gst = int.tryParse(gstscorecontroller.text.trim()) ?? 0;
    if (gst >= 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("This student is not qualified for PHIL IRI Pretest"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return; // STOP COMPLETELY — NO FIREBASE SAVE
    }

    try {
      if (widget.student != null) {
        // Update the existing student
        final studentupdate = widget.student!.copyWith(
          lrn: lrncontroller.text.trim(),
          firstname: _firstnamecontroller.text.trim(),
          middlename: _middlenamecontroller.text.trim().isEmpty
              ? null
              : _middlenamecontroller.text.trim(),
          lastname: _lastnamecontroller.text.trim(),
          gstscore: gstscorecontroller.text.trim(),
          gradelevelread: gradelevelread(),
          gender: selectedgender,
        );

        Map<String, dynamic> updateData = studentupdate.toMap();

        if (_middlenamecontroller.text.trim().isEmpty) {
          updateData['middlename'] = FieldValue.delete();
        }

        await firestore
            .collection("students")
            .doc(widget.student!.id)
            .update(updateData);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Student updated successfully")));
        Navigator.pop(context);
      } else {
        // Add a new student
        // 🔍 Check if student already exists
        final existingStudent = await firestore
            .collection("students")
            .where("lrn", isEqualTo: lrncontroller.text.trim())
            .where("firstname", isEqualTo: _firstnamecontroller.text.trim())
            .where("lastname", isEqualTo: _lastnamecontroller.text.trim())
            .where("schoolyearid", isEqualTo: widget.schoolyear.id)
            .where("sectionid", isEqualTo: widget.section.id)
            .get();

        final existinglrn = await firestore
            .collection("students")
            .where("lrn", isEqualTo: lrncontroller.text.trim())
            .where("schoolyearid", isEqualTo: widget.schoolyear.id)
            .where("sectionid", isEqualTo: widget.section.id)
            .get();

        if (existingStudent.docs.isNotEmpty || existinglrn.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Student already exists in this section.",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        final studentadd = firestore.collection("students").doc().id;

        await firestore
            .collection("students")
            .doc(studentadd)
            .set(
              Student(
                id: studentadd,
                lrn: lrncontroller.text.trim(),
                sectionid: widget.section.id,
                schoolyearid: widget.schoolyear.id,
                firstname: _firstnamecontroller.text.trim(),
                middlename: _middlenamecontroller.text.trim().isEmpty
                    ? null
                    : _middlenamecontroller.text.trim(),
                lastname: _lastnamecontroller.text.trim(),
                gstscore: gstscorecontroller.text.trim(),
                gradelevelread: gradelevelread(),
                gender: selectedgender!,
                readlevel: "Not Started",
                readingresult: "Not Started",
                comprehensionresult: "Not Started",
                status: "ACTIVE",
              ).toMap(),
            );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Student added successfully",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e, stack) {
      // Handle any errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Something went wrong! Please try again.\n Error $e, StackTrace: $stack",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _firstnamecontroller.dispose();
    _middlenamecontroller.dispose();
    _lastnamecontroller.dispose();
    lrncontroller.dispose();
    gstscorecontroller.dispose();
    gendercontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          widget.student != null ? "Edit Student" : "Add Student",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Student Details",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a new student for organizing your classes and managing student information.",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: lrncontroller,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    fillColor: Colors.white,
                    labelText: "Student LRN",
                    hintText: "Enter Student LRN",
                    prefixIcon: Icon(
                      Icons.format_list_numbered,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Enter Student LRN" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                /// Category name input
                TextFormField(
                  controller: _firstnamecontroller,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    fillColor: Colors.white,
                    labelText: "Student First Name",
                    hintText: "Enter First Name",
                    prefixIcon: Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Enter First Name" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _middlenamecontroller,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    fillColor: Colors.white,
                    labelText: "Student Middle Name (Optional)",
                    hintText: "Enter Middle Name",
                    prefixIcon: Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  validator: (value) => null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                /// Description input
                TextFormField(
                  controller: _lastnamecontroller,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    fillColor: Colors.white,
                    labelText: "Student Last Name",
                    hintText: "Enter Last Name",
                    prefixIcon: Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Enter Last Name" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: gstscorecontroller,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    fillColor: Colors.white,
                    labelText: "GST Score",
                    hintText: "Enter Student Gst Score",
                    prefixIcon: Icon(Icons.score, color: AppTheme.primaryColor),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Enter Student GST Score" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 32),

                DropdownButtonFormField<String>(
                  initialValue: selectedgender,
                  decoration: InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.remove_red_eye,
                      color: AppTheme.primaryColor,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: gender.map((gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedgender = value;
                      gendercontroller.text = value ?? "";
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please Select Gender";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                /// Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : SaveStudent,
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
                        : Text(
                            widget.student != null
                                ? "Update Student"
                                : "Add Student",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
