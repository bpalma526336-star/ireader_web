import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/admin.dart';
import 'package:ireader_web/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddAdminScreen extends StatefulWidget {
  final Admin? admin;
  const AddAdminScreen({super.key, this.admin});

  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
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

class _AddAdminScreenState extends State<AddAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _passwordController = TextEditingController();
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
      text: widget.admin?.firstname ?? '',
    );
    middlenameController = TextEditingController(
      text: widget.admin?.middlename ?? '',
    );
    lastnameController = TextEditingController(
      text: widget.admin?.lastname ?? '',
    );
    emailController = TextEditingController(text: widget.admin?.email ?? '');
    phoneController = TextEditingController(
      text: widget.admin?.phonenumber ?? '',
    );
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

  Future<void> _saveAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 🔍 Run duplication check only when adding
      if (widget.admin == null) {
        final emailCheck = await _firestore
            .collection('admins')
            .where('email', isEqualTo: emailController.text.trim())
            .get();

        if (emailCheck.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("An Admin with this email already exists."),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final nameCheck = await _firestore
            .collection('admins')
            .where('firstname', isEqualTo: firstnameController.text.trim())
            .where('middlename', isEqualTo: middlenameController.text.trim())
            .where('lastname', isEqualTo: lastnameController.text.trim())
            .get();

        if (nameCheck.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Admin with same details already exists."),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final newadmin =
          widget.admin?.id ?? _firestore.collection('admins').doc().id;

      if (widget.admin == null) {
        await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final User? user = _auth.currentUser;
        final String uid = user?.uid ?? newadmin;
        // ✅ ADD NEW TEACHER
        await _firestore
            .collection('admins')
            .doc(uid)
            .set(
              Admin(
                id: uid,
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
        await _firestore.collection('admins').doc(widget.admin!.id).update({
          'firstname': firstnameController.text.trim(),
          'middlename': middlenameController.text.trim(),
          'lastname': lastnameController.text.trim(),
          'email': emailController.text.trim(),
          'phonenumber': formatPhoneNumber(phoneController.text),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin updated successfully!"),
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
          widget.admin != null ? "Edit Admin" : "Add Admin",
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
                "Admin Details",
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

              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.password),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter Password" : null,
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
                  onPressed: _isLoading ? null : _saveAdmin,
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
                          widget.admin != null ? "Update Admin" : "Add Admin",
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
