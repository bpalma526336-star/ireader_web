import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/core/firestore_collections.dart';
import 'package:ireader_web/model/division.dart';
import 'package:ireader_web/model/readingcoordinator.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/theme.dart';

class AddRcDialog extends StatefulWidget {
  final RC? rc;
  const AddRcDialog({super.key, this.rc});

  @override
  State<AddRcDialog> createState() => _AddRcDialogState();
}

class _AddRcDialogState extends State<AddRcDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TextEditingController firstnameController;
  late TextEditingController middlenameController;
  late TextEditingController lastnameController;
  late TextEditingController emailController;

  bool _isLoading = false;
  List<Division> _divisions = [];
  List<School> _schools = [];
  String? _selectedSchoolId;
  String? _selectedDivisionId;
  bool _loadingSchools = true;
  bool _loadingDivisions = true;

  @override
  void initState() {
    super.initState();
    firstnameController = TextEditingController(
      text: widget.rc?.firstname ?? '',
    );
    middlenameController = TextEditingController(
      text: widget.rc?.middlename ?? '',
    );
    lastnameController = TextEditingController(text: widget.rc?.lastname ?? '');
    emailController = TextEditingController(text: widget.rc?.email ?? '');
    _selectedDivisionId = widget.rc?.divisionid;
    _selectedSchoolId = widget.rc?.schoolid;
    _loadDivisions();
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

  Future<void> _loadDivisions() async {
    final snap = await _firestore
        .collection(FirestoreCollections.divisions)
        .where('status', isEqualTo: 'ACTIVE')
        .get();
    if (!mounted) return;
    setState(() {
      _divisions = snap.docs
          .map((d) => Division.fromMap(d.id, d.data()))
          .toList();
      _loadingDivisions = false;
    });
  }

  List<School> get _schoolsForSelectedDivision {
    if (_selectedDivisionId == null) return [];
    return _schools
        .where((school) => school.divisionid == _selectedDivisionId)
        .toList();
  }

  Future<void> _saveRC() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 🔍 Run duplication check only when adding
      if (widget.rc == null) {
        final emailCheck = await _firestore
            .collection('readingcoordinators')
            .where('email', isEqualTo: emailController.text.trim())
            .get();

        if (emailCheck.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "A Readingcoordinator with this email already exists.",
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final nameCheck = await _firestore
            .collection('readingcoordinators')
            .where('firstname', isEqualTo: firstnameController.text.trim())
            .where(
              'middlename',
              isEqualTo: middlenameController.text.trim().isEmpty
                  ? null
                  : middlenameController.text.trim(),
            )
            .where('lastname', isEqualTo: lastnameController.text.trim())
            .where('email', isEqualTo: emailController.text.trim())
            .get();

        if (nameCheck.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Reading Coordinator with same name already exists.",
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final newrc = widget.rc == null
          ? _firestore.collection('readingcoordinators').doc().id
          : widget.rc!.id;

      if (widget.rc == null) {
        // ✅ ADD NEW TEACHER
        await _firestore
            .collection('readingcoordinators')
            .doc(newrc)
            .set(
              RC(
                id: newrc,
                firstname: firstnameController.text.trim(),
                middlename: middlenameController.text.trim(),
                lastname: lastnameController.text.trim(),
                email: emailController.text.trim(),
                status: 'ACTIVE',
                divisionid: _selectedDivisionId,
                schoolid: _selectedSchoolId,
              ).toMap(),
            );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reading Coordinator added successfully!"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await _firestore
            .collection('readingcoordinators')
            .doc(widget.rc!.id)
            .update({
              'firstname': firstnameController.text.trim(),
              'middlename': middlenameController.text.trim(),
              'lastname': lastnameController.text.trim(),
              'email': emailController.text.trim(),
              'divisionid': _selectedDivisionId,
              'schoolid': _selectedSchoolId,
            });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reading Coordinator updated successfully!"),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.rc != null
                            ? "Edit Reading Coordinator"
                            : "Add Reading Coordinator",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

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

                _loadingDivisions
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedDivisionId,
                        decoration: const InputDecoration(
                          labelText: 'Division',
                          prefixIcon: Icon(Icons.account_tree_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— No division assigned —'),
                          ),
                          ..._divisions.map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedDivisionId = v;
                            if (v == null ||
                                !_schoolsForSelectedDivision.any(
                                  (school) => school.id == _selectedSchoolId,
                                )) {
                              _selectedSchoolId = null;
                            }
                          });
                        },
                      ),

                const SizedBox(height: 16),

                _loadingSchools
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedSchoolId,
                        decoration: const InputDecoration(
                          labelText: 'School',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        hint: Text(
                          _selectedDivisionId == null
                              ? 'Select a division first'
                              : 'Select a school',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— No school assigned —'),
                          ),
                          ..._schoolsForSelectedDivision.map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          ),
                        ],
                        onChanged: _selectedDivisionId == null
                            ? null
                            : (v) => setState(() => _selectedSchoolId = v),
                      ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    onPressed: _isLoading ? null : _saveRC,
                    label: _isLoading
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
                            widget.rc != null
                                ? "Update Reading Coordinator"
                                : "Add Reading Coordinator",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
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
