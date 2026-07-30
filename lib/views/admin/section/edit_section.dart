import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';

class EditSection extends StatefulWidget {
  final Section section;
  final Teacher teacher;

  const EditSection({super.key, required this.section, required this.teacher});

  @override
  State<EditSection> createState() => _EditSectionState();
}

class _EditSectionState extends State<EditSection> {
  final firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController sectionname;
  late String? _selectedTeacherId;

  List<QueryDocumentSnapshot> _teachers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // ✅ Pre-fill section name
    sectionname = TextEditingController(text: widget.section.sectionname);

    // ✅ Pre-select assigned teacher
    _selectedTeacherId = widget.section.teacherid;

    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    final snapshot = await firestore.collection("teachers").get();

    setState(() {
      _teachers = snapshot.docs;
    });
  }

  Future<void> _updateSection() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an assigned teacher")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await firestore.collection('sections').doc(widget.section.id).update({
        'sectionname': sectionname.text.trim(),
        'teacherid': _selectedTeacherId!,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error updating section: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update section: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text("Edit Section"),
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobileS = screenWidth <= 320;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobileS
                    ? IconButton(
                        icon: const Icon(Icons.save),
                        color: AppTheme.primaryColor,
                        tooltip: "Update Section",
                        onPressed: _isLoading ? null : _updateSection,
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text('Update Section'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _updateSection,
                      ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              "Section",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 🔹 Section Name
            TextFormField(
              controller: sectionname,
              decoration: InputDecoration(
                labelText: "Section Name",
                hintText: "Enter Section Name",
                prefixIcon: Icon(Icons.title, color: AppTheme.primaryColor),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? "Please enter section name" : null,
            ),
            const SizedBox(height: 16),

            // 🔹 Teacher Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedTeacherId,
              decoration: const InputDecoration(
                labelText: "Assigned Teacher",
                border: OutlineInputBorder(),
              ),
              items: _teachers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    "${data['firstname'] ?? ''} ${data['middlename'] ?? ''} ${data['lastname'] ?? ''}"
                        .trim(),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTeacherId = value;
                });
              },
              validator: (value) =>
                  value == null ? "Please select a teacher" : null,
            ),
            const SizedBox(height: 32),

            // 🔹 Update Button (Bottom)
            Center(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateSection,
                  child: _isLoading
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
                      : const Text(
                          "Update Section",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
