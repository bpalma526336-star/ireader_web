import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/theme.dart';

class AddSectionScreen extends StatefulWidget {
  final Section? section;
  final SchoolYear schoolyear;

  const AddSectionScreen({super.key, required this.schoolyear, this.section});

  @override
  State<AddSectionScreen> createState() => _AddSectionScreenState();
}

class _AddSectionScreenState extends State<AddSectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final sectionname = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _selectedTeacherId;
  List<QueryDocumentSnapshot> _teachers = [];

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    final snapshot = await firestore.collection("teachers").get();
    setState(() {
      _teachers = snapshot.docs;
    });
  }

  Future<void> _saveSection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an assigned teacher")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Use plural "sections" to match convention
      final newsection = firestore.collection('sections').doc().id;

      await firestore
          .collection('sections')
          .doc(newsection)
          .set(
            Section(
              id: newsection,
              sectionname: sectionname.text.trim(),
              schoolyearid: widget.schoolyear.id,
              teacherid: _selectedTeacherId!,
            ).toMap(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section added successfully')),
        );
        Navigator.pop(context); // ✅ return to Manage Section
      }
    } catch (e) {
      debugPrint("Error adding section: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add section: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text("Create Section"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 20),
              label: const Text('Save Section'),
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
              onPressed: _isLoading ? null : _saveSection,
            ),
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

            // Section name input
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

            // Teacher dropdown
            DropdownButtonFormField<String>(
              value: _selectedTeacherId,
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

            // Save button (optional, duplicate of AppBar)
            Center(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSection,
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
                          "Save Section",
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
