import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/core/firestore_collections.dart';
import 'package:ireader_web/model/division.dart';
import 'package:ireader_web/theme.dart';

class AddDivisionDialog extends StatefulWidget {
  final Division? division;
  const AddDivisionDialog({super.key, this.division});

  @override
  State<AddDivisionDialog> createState() => _AddDivisionDialogState();
}

class _AddDivisionDialogState extends State<AddDivisionDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.division?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.division == null) {
        final existing = await _firestore
            .collection(FirestoreCollections.divisions)
            .where('name', isEqualTo: _nameController.text.trim())
            .get();

        if (existing.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A division with this name already exists.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final docId = _firestore.collection(FirestoreCollections.divisions).doc().id;
        await _firestore.collection(FirestoreCollections.divisions).doc(docId).set(
          Division(id: docId, name: _nameController.text.trim(), status: 'ACTIVE').toMap(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Division added successfully!'), behavior: SnackBarBehavior.floating),
        );
      } else {
        await _firestore
            .collection(FirestoreCollections.divisions)
            .doc(widget.division!.id)
            .update({'name': _nameController.text.trim()});

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Division updated successfully!'), behavior: SnackBarBehavior.floating),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                        widget.division != null ? 'Edit Division' : 'Add Division',
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
                    labelText: 'Division Name',
                    hintText: 'e.g. Division Z',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter division name' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    onPressed: _isLoading ? null : _save,
                    label: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.division != null ? 'Update Division' : 'Add Division'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
