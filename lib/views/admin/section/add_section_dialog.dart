import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/theme.dart';

class AddSectionDialog extends StatefulWidget {
  final SchoolYear schoolyear;

  const AddSectionDialog({super.key, required this.schoolyear});

  @override
  State<AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<AddSectionDialog> {
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
    final snapshot = await firestore
        .collection("teachers")
        .where('status', isEqualTo: 'ACTIVE')
        .get();

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
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Section added successfully")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to add section: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                        "Create Section",
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
                    prefixIcon: Icon(
                      Icons.class_,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter section name";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

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
                        "${data['firstname']} ${data['middlename'] ?? ''} ${data['lastname']}",
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTeacherId = value;
                    });
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Save Section"),
                    onPressed: _isLoading ? null : _saveSection,
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
