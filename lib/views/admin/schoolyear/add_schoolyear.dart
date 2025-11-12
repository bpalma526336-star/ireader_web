import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';

class AddSchoolyearScreen extends StatefulWidget {
  final SchoolYear? schoolyear;
  const AddSchoolyearScreen({super.key, required this.schoolyear});

  @override
  State<AddSchoolyearScreen> createState() => _AddSchoolyearScreenState();
}

class _AddSchoolyearScreenState extends State<AddSchoolyearScreen> {
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
      // 🧩 Validate numeric and logical range
      final startYear = int.tryParse(start);
      final endYear = int.tryParse(end);

      if (startYear == null || endYear == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please enter valid numeric years."),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (startYear >= endYear) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Invalid range: start year must be less than end year.",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 🔒 Check for duplicates when adding a new school year
      final duplicate = await _firestore
          .collection('schoolyears')
          .where('schoolyearstart', isEqualTo: start)
          .where('schoolyearend', isEqualTo: end)
          .get();

      if (duplicate.docs.isNotEmpty && widget.schoolyear == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This school year already exists."),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // ✅ If updating
      if (widget.schoolyear != null) {
        final updated = widget.schoolyear!.copyWith(
          schoolyearstart: start,
          schoolyearend: end,
        );

        await _firestore
            .collection('schoolyears')
            .doc(widget.schoolyear!.id)
            .update(updated.toMap());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("School Year updated successfully")),
        );
      } else {
        // ✅ If adding new
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School Year added successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving School Year: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          widget.schoolyear != null ? "Edit School Year" : "Add School Year",
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
                "School Year Details",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              /// Input field
              TextFormField(
                controller: _schoolyearstartController,
                decoration: const InputDecoration(
                  labelText: "School Year Start",
                  hintText: "Enter School Year Start",
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Enter School Year Start"
                    : null,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _schoolyearendController,
                decoration: const InputDecoration(
                  labelText: "School Year End",
                  hintText: "Enter School Year End",
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Enter School Year End"
                    : null,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),

              /// Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSchoolYear,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 2,
                        )
                      : Text(
                          widget.schoolyear != null
                              ? "Update School Year"
                              : "Add School Year",
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
    );
  }
}
