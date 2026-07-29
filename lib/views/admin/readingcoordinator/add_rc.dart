import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/readingcoordinator.dart';
import 'package:ireader_web/theme.dart';

class AddRCScreen extends StatefulWidget {
  final RC? rc; // null = add, not null = edit

  const AddRCScreen({super.key, this.rc});

  @override
  State<AddRCScreen> createState() => _AddRCScreenState();
}

class _AddRCScreenState extends State<AddRCScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TextEditingController firstnameController;
  late TextEditingController middlenameController;
  late TextEditingController lastnameController;
  late TextEditingController emailController;

  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    firstnameController.dispose();
    middlenameController.dispose();
    lastnameController.dispose();
    emailController.dispose();
    super.dispose();
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
              ).toMap(),
            );

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
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reading Coordinator updated successfully!"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.backgroundColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Reading Coordinator Details",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // 🧑 FIRST NAME
              TextFormField(
                controller: firstnameController,
                decoration: const InputDecoration(
                  labelText: "First Name",
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter first name" : null,
              ),
              const SizedBox(height: 16),

              // 🧑‍🏫 MIDDLE NAME
              TextFormField(
                controller: middlenameController,
                decoration: const InputDecoration(
                  labelText: "Middle Name (Optional)",
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => null,
              ),
              const SizedBox(height: 16),

              // 🧑‍💼 LAST NAME
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

              // 📧 EMAIL
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter email" : null,
              ),
              const SizedBox(height: 32),

              // 💾 SAVE BUTTON
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
    );
  }
}
