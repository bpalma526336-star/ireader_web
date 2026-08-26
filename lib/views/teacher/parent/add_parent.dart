import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/parent.dart';
import 'package:ireader_web/theme.dart';

class AddParent extends StatefulWidget {
  final Parent? parent;
  const AddParent({super.key, this.parent});

  @override
  State<AddParent> createState() => _AddParentState();
}

class _AddParentState extends State<AddParent> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late TextEditingController firstnameController;
  late TextEditingController middlenameController;
  late TextEditingController lastnameController;
  late TextEditingController accesscodeController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    firstnameController = TextEditingController(
      text: widget.parent?.firstname ?? '',
    );
    middlenameController = TextEditingController(
      text: widget.parent?.middlename ?? '',
    );
    lastnameController = TextEditingController(
      text: widget.parent?.lastname ?? '',
    );
    accesscodeController = TextEditingController(
      text: widget.parent?.accesscode ?? '',
    );
  }

  @override
  void dispose() {
    firstnameController.dispose();
    middlenameController.dispose();
    lastnameController.dispose();
    accesscodeController.dispose();
    super.dispose();
  }

  Future<void> _saveParent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 🔍 Run duplication check only when adding
      if (widget.parent == null) {
        final accesscodeCheck = await firestore
            .collection('parents')
            .where('accesscode', isEqualTo: accesscodeController.text.trim())
            .get();

        if (accesscodeCheck.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("A parent with this access code already exists."),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final nameCheck = await firestore
            .collection('parents')
            .where('firstname', isEqualTo: firstnameController.text.trim())
            .where(
              'middlename',
              isEqualTo: middlenameController.text.trim().isEmpty
                  ? null
                  : middlenameController.text.trim(),
            )
            .get();

        if (nameCheck.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Parent with same name already exists."),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final newId = widget.parent == null
          ? firestore.collection('parents').doc().id
          : widget.parent!.id;

      if (widget.parent == null) {
        // ✅ ADD NEW PARENT
        await firestore
            .collection('parents')
            .doc(newId)
            .set(
              Parent(
                id: newId,
                firstname: firstnameController.text.trim(),
                middlename: middlenameController.text.trim(),
                lastname: lastnameController.text.trim(),
                accesscode: accesscodeController.text.trim(),
                status: 'ACTIVE',
              ).toMap(),
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Parent added successfully!"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // ✅ UPDATE EXISTING PARENT
        final parentUpdate = widget.parent!.copyWith(
          firstname: firstnameController.text.trim(),
          middlename: middlenameController.text.trim().isEmpty
              ? null
              : middlenameController.text.trim(),
          lastname: lastnameController.text.trim(),
          accesscode: accesscodeController.text.trim(),
        );

        Map<String, dynamic> updateData = parentUpdate.toMap();

        if (middlenameController.text.trim().isEmpty) {
          updateData['middlename'] = FieldValue.delete();
        }

        await firestore
            .collection('parents')
            .doc(widget.parent!.id)
            .update(updateData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Parent updated successfully!"),
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
    final isEditing = widget.parent != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Parent' : 'Add Parent'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveParent,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(isEditing ? 'Update Parent' : 'Save Parent'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_outlined,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Update parent details'
                                      : 'Create a parent account',
                                  style: AppTheme.pageTitleStyle,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Enter the parent information below. The access code will be used for sign in.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 24),
                      Text(
                        'Personal Information',
                        style: AppTheme.sectionTitleStyle,
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final firstName = _parentField(
                            controller: firstnameController,
                            label: 'First Name',
                            hint: 'Enter first name',
                            icon: Icons.person_outline,
                            requiredField: true,
                          );
                          final middleName = _parentField(
                            controller: middlenameController,
                            label: 'Middle Name',
                            hint: 'Enter middle name (optional)',
                            icon: Icons.person_outline,
                          );
                          final lastName = _parentField(
                            controller: lastnameController,
                            label: 'Last Name',
                            hint: 'Enter last name',
                            icon: Icons.person_outline,
                            requiredField: true,
                          );

                          if (constraints.maxWidth < 560) {
                            return Column(
                              children: [
                                firstName,
                                const SizedBox(height: 16),
                                middleName,
                                const SizedBox(height: 16),
                                lastName,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: firstName),
                              const SizedBox(width: 14),
                              Expanded(child: middleName),
                              const SizedBox(width: 14),
                              Expanded(child: lastName),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text('Account Access', style: AppTheme.sectionTitleStyle),
                      const SizedBox(height: 14),
                      _parentField(
                        controller: accesscodeController,
                        label: 'Access Code',
                        hint: 'Enter a unique access code',
                        icon: Icons.key_outlined,
                        requiredField: true,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveParent,
                          icon: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isLoading
                                ? 'Saving...'
                                : isEditing
                                ? 'Update Parent'
                                : 'Save Parent',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _parentField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      ),
      validator: requiredField
          ? (value) => value == null || value.trim().isEmpty
                ? 'Please enter $label'
                : null
          : null,
    );
  }
}
