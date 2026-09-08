import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/core/firestore_collections.dart';
import 'package:ireader_web/model/division.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/theme.dart';

class AddSchoolDialog extends StatefulWidget {
  final Division division;
  final School? school;
  const AddSchoolDialog({super.key, this.school, required this.division});

  @override
  State<AddSchoolDialog> createState() => _AddSchoolDialogState();
}

class _AddSchoolDialogState extends State<AddSchoolDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TextEditingController _nameController;
  late TextEditingController _addressController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.school?.name ?? '');
    _addressController = TextEditingController(
      text: widget.school?.address ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.school == null) {
        final schoolYears = await _firestore
            .collection(FirestoreCollections.schoolYears)
            .get();
        final schoolyearids = schoolYears.docs.map((doc) => doc.id).toList();

        final existing = await _firestore
            .collection(FirestoreCollections.schools)
            .where('name', isEqualTo: _nameController.text.trim())
            .where('divisionid', isEqualTo: widget.division.id)
            .get();

        if (existing.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A school with this name already exists in the selected division.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final docId = _firestore
            .collection(FirestoreCollections.schools)
            .doc()
            .id;
        await _firestore
            .collection(FirestoreCollections.schools)
            .doc(docId)
            .set(
              School(
                id: docId,
                name: _nameController.text.trim(),
                divisionid: widget.division.id,
                schoolyearids: schoolyearids,
                address: _addressController.text.trim().isEmpty
                    ? null
                    : _addressController.text.trim(),
                status: 'ACTIVE',
              ).toMap(),
            );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School added successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await _firestore
            .collection(FirestoreCollections.schools)
            .doc(widget.school!.id)
            .update({
              'name': _nameController.text.trim(),
              'divisionid': widget.division.id,
              'address': _addressController.text.trim().isEmpty
                  ? null
                  : _addressController.text.trim(),
            });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School updated successfully!'),
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
          content: Text('Error: $e'),
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
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                        widget.school != null ? 'Edit School' : 'Add School',
                        style: const TextStyle(
                          fontSize: 18,
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
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'School Name',
                    hintText: 'e.g. Sta. Rosa Elementary School',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter school name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    hintText: 'e.g. Brgy. San Jose, Sta. Rosa',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    onPressed: _isLoading ? null : _save,
                    label: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.school != null
                                ? 'Update School'
                                : 'Add School',
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
