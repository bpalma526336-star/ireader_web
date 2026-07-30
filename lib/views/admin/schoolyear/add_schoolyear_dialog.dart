import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';

class AddSchoolyearDialog extends StatefulWidget {
  final SchoolYear? schoolyear;

  const AddSchoolyearDialog({super.key, this.schoolyear});

  /// Helper to show the dialog easily
  static Future<void> show(BuildContext context, {SchoolYear? schoolyear}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddSchoolyearDialog(schoolyear: schoolyear),
    );
  }

  @override
  State<AddSchoolyearDialog> createState() => _AddSchoolyearDialogState();
}

class _AddSchoolyearDialogState extends State<AddSchoolyearDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _schoolyearstartController;
  late TextEditingController _schoolyearendController;

  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _schoolyearstartController = TextEditingController(
      text: widget.schoolyear?.schoolyearstart ?? "",
    );
    _schoolyearendController = TextEditingController(
      text: widget.schoolyear?.schoolyearend ?? "",
    );
  }

  @override
  void dispose() {
    _schoolyearstartController.dispose();
    _schoolyearendController.dispose();
    super.dispose();
  }

  Future<void> _saveSchoolYear() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final start = _schoolyearstartController.text.trim();
    final end = _schoolyearendController.text.trim();

    try {
      final startYear = int.tryParse(start);
      final endYear = int.tryParse(end);

      if (startYear == null || endYear == null) {
        _showSnack("Please enter valid numeric years.");
        return;
      }

      if (startYear >= endYear) {
        _showSnack("Start year must be less than end year.");
        return;
      }

      final duplicate = await _firestore
          .collection('schoolyears')
          .where('schoolyearstart', isEqualTo: start)
          .where('schoolyearend', isEqualTo: end)
          .get();

      if (duplicate.docs.isNotEmpty && widget.schoolyear == null) {
        _showSnack("This school year already exists.");
        return;
      }

      if (widget.schoolyear != null) {
        final updated = widget.schoolyear!.copyWith(
          schoolyearstart: start,
          schoolyearend: end,
        );

        await _firestore
            .collection('schoolyears')
            .doc(widget.schoolyear!.id)
            .update(updated.toMap());

        _showSnack("School Year updated successfully");
      } else {
        final newId = _firestore.collection('schoolyears').doc().id;

        await _firestore
            .collection('schoolyears')
            .doc(newId)
            .set(
              SchoolYear(
                id: newId,
                schoolyearstart: start,
                schoolyearend: end,
              ).toMap(),
            );

        _showSnack("School Year added successfully");

        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showSnack("Error saving School Year: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.schoolyear != null ? "Edit School Year" : "Add School Year",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _schoolyearstartController,
                  decoration: const InputDecoration(
                    labelText: "School Year Start",
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _schoolyearendController,
                  decoration: const InputDecoration(
                    labelText: "School Year End",
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? "Required" : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSchoolYear,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.schoolyear != null ? "Update" : "Save",
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
