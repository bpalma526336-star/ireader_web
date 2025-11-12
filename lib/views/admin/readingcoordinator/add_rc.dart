import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/readingcoordinator.dart';
import 'package:ireader_web/theme.dart';

class AddRCScreen extends StatefulWidget {
  final RC? rc; // null = add, not null = edit

  const AddRCScreen({super.key, this.rc});

  @override
  State<AddRCScreen> createState() => _AddRCScreenState();
}

String formatPhoneNumber(String input) {
  input = input.trim();
  if (input.startsWith('0')) {
    return '+63${input.substring(1)}';
  } else if (input.startsWith('+63')) {
    return input;
  } else {
    return input; // Or throw error/handle differently if needed
  }
}

class _AddRCScreenState extends State<AddRCScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController firstnameController;
  late TextEditingController middlenameController;
  late TextEditingController lastnameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

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
    phoneController = TextEditingController(text: widget.rc?.phonenumber ?? '');
  }

  @override
  void dispose() {
    firstnameController.dispose();
    middlenameController.dispose();
    lastnameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveTeacher() async {
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
            .collection('teachers')
            .where('firstname', isEqualTo: firstnameController.text.trim())
            .where('middlename', isEqualTo: middlenameController.text.trim())
            .where('lastname', isEqualTo: lastnameController.text.trim())
            .get();

        if (nameCheck.docs.isNotEmpty) {
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

      final newrc =
          widget.rc?.id ??
          _firestore.collection('readingcoordinators').doc().id;

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
                phonenumber: formatPhoneNumber(phoneController.text),
                status: 'active',
              ).toMap(),
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reading Coordinator added successfully!"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // ✅ UPDATE EXISTING TEACHER
        await _firestore.collection('teachers').doc(widget.rc!.id).update({
          'firstname': firstnameController.text.trim(),
          'middlename': middlenameController.text.trim(),
          'lastname': lastnameController.text.trim(),
          'email': emailController.text.trim(),
          'phonenumber': formatPhoneNumber(phoneController.text),
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
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          widget.rc != null
              ? "Edit Reading Coordinator"
              : "Add Reading Coordinator",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
                  labelText: "Middle Name",
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter middle name" : null,
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
              const SizedBox(height: 16),

              // 📱 PHONE NUMBER
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter phone number";
                  }

                  final formatted = formatPhoneNumber(value);

                  if (formatted.length != 13 || !formatted.startsWith('+63')) {
                    return "Invalid phone number";
                  }

                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 💾 SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  onPressed: _isLoading ? null : _saveTeacher,
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
