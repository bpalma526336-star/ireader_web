import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';

class EditSectionDialog extends StatefulWidget {
  final Section section;
  final Teacher teacher;

  const EditSectionDialog({
    super.key,
    required this.section,
    required this.teacher,
  });

  @override
  State<EditSectionDialog> createState() => _EditSectionDialogState();
}

class _EditSectionDialogState extends State<EditSectionDialog> {
  final firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController sectionname;
  late String? _selectedTeacherId;

  List<QueryDocumentSnapshot> _teachers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    sectionname = TextEditingController(text: widget.section.sectionname);
    _selectedTeacherId = widget.section.teacherid;
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    final snapshot = await firestore.collection("teachers").get();
    setState(() => _teachers = snapshot.docs);
  }

  Future<void> _updateSection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await firestore.collection('sections').doc(widget.section.id).update({
        'sectionname': sectionname.text.trim(),
        'teacherid': _selectedTeacherId,
      });

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update section: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    sectionname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Edit Section",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
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
                  controller: sectionname,
                  decoration: InputDecoration(
                    labelText: "Section Name",
                    prefixIcon: Icon(Icons.title, color: AppTheme.primaryColor),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedTeacherId,
                  decoration: const InputDecoration(
                    labelText: "Assigned Teacher",
                    border: OutlineInputBorder(),
                  ),
                  items: _teachers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text("${data['firstname']} ${data['lastname']}"),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedTeacherId = value);
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateSection,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Update Section"),
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
