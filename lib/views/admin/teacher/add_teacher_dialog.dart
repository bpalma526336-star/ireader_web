import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/core/firestore_collections.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';

class AddTeacherDialog extends StatefulWidget {
  final Teacher? teacher;
  const AddTeacherDialog({super.key, required this.teacher});

  @override
  State<AddTeacherDialog> createState() => _AddTeacherDialogState();
}

class _AddTeacherDialogState extends State<AddTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TextEditingController firstnameController;
  late TextEditingController middlenameController;
  late TextEditingController lastnameController;
  late TextEditingController emailController;

  bool _isLoading = false;
  List<School> _schools = [];
  String? _selectedSchoolId;
  bool _loadingSchools = true;

  @override
  void initState() {
    super.initState();
    firstnameController = TextEditingController(
      text: widget.teacher?.firstname ?? '',
    );
    middlenameController = TextEditingController(
      text: widget.teacher?.middlename ?? '',
    );
    lastnameController = TextEditingController(
      text: widget.teacher?.lastname ?? '',
    );
    emailController = TextEditingController(text: widget.teacher?.email ?? '');
    _selectedSchoolId = widget.teacher?.schoolid;
    _loadSchools();
  }

  @override
  void dispose() {
    firstnameController.dispose();
    middlenameController.dispose();
    lastnameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSchools() async {
    final snap = await _firestore
        .collection(FirestoreCollections.schools)
        .where('status', isEqualTo: 'ACTIVE')
        .get();
    if (!mounted) return;
    setState(() {
      _schools = snap.docs.map((d) => School.fromMap(d.id, d.data())).toList();
      _loadingSchools = false;
    });
  }

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 🔍 Run duplication check only when adding
      if (widget.teacher == null) {
        final emailCheck = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: emailController.text.trim())
            .get();

        if (emailCheck.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("A teacher with this email already exists."),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final nameCheck = await _firestore
            .collection('teachers')
            .where('firstname', isEqualTo: firstnameController.text.trim())
            .where(
              'middlename',
              isEqualTo: middlenameController.text.trim().isEmpty
                  ? null
                  : middlenameController.text.trim(),
            )
            .get();

        if (nameCheck.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Teacher with same name already exists."),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final newId = widget.teacher == null
          ? _firestore.collection('teachers').doc().id
          : widget.teacher!.id;

      if (widget.teacher == null) {
        // ✅ ADD NEW TEACHER
        await _firestore
            .collection('teachers')
            .doc(newId)
            .set(
              Teacher(
                id: newId,
                firstname: firstnameController.text.trim(),
                middlename: middlenameController.text.trim(),
                lastname: lastnameController.text.trim(),
                email: emailController.text.trim(),
                status: 'ACTIVE',
                schoolid: _selectedSchoolId,
              ).toMap(),
            );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Teacher added successfully!"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // ✅ UPDATE EXISTING TEACHER
        final teacherUpdate = widget.teacher!.copyWith(
          firstname: firstnameController.text.trim(),
          middlename: middlenameController.text.trim().isEmpty
              ? null
              : middlenameController.text.trim(),
          lastname: lastnameController.text.trim(),
          email: emailController.text.trim(),
          schoolid: _selectedSchoolId,
        );

        Map<String, dynamic> updateData = teacherUpdate.toMap();

        if (middlenameController.text.trim().isEmpty) {
          updateData['middlename'] = FieldValue.delete();
        }

        await _firestore
            .collection('teachers')
            .doc(widget.teacher!.id)
            .update(updateData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Teacher updated successfully!"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.teacher != null ? "Edit Teacher" : "Add Teacher",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: firstnameController,
                  decoration: const InputDecoration(
                    labelText: "First Name",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? "Enter first name"
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: middlenameController,
                  decoration: const InputDecoration(
                    labelText: "Middle Name (Optional)",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: lastnameController,
                  decoration: const InputDecoration(
                    labelText: "Last Name",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? "Enter last name" : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? "Enter email" : null,
                ),

                const SizedBox(height: 16),

                _loadingSchools
                    ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                    : DropdownButtonFormField<String>(
                        value: _selectedSchoolId,
                        decoration: const InputDecoration(
                          labelText: 'School (Optional)',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— No school assigned —')),
                          ..._schools.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) => setState(() => _selectedSchoolId = v),
                      ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    onPressed: _isLoading ? null : _saveTeacher,
                    label: Text(
                      widget.teacher != null ? "Update Teacher" : "Add Teacher",
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
