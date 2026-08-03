import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/teacher/practice_set/sentences/manage_sentence_ps.dart';
import 'package:ireader_web/views/teacher/practice_set/storyline/manage_storyline_ps.dart';
import 'package:ireader_web/views/teacher/practice_set/word_recognition/manage_wr_ps.dart';

class SelectPracticeSetScreen extends StatefulWidget {
  final Section section;
  final SchoolYear schoolyear;
  const SelectPracticeSetScreen({
    super.key,
    required this.section,
    required this.schoolyear,
  });

  @override
  State<SelectPracticeSetScreen> createState() =>
      _SelectPracticeSetScreenState();
}

class _SelectPracticeSetScreenState extends State<SelectPracticeSetScreen> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  int wrcount = 0;
  int spcount = 0;
  int slcount = 0;

  @override
  void initState() {
    super.initState();

    FirebaseFirestore.instance
        .collection('wordrecognitionpracticeset')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            wrcount = snapshot.docs.length;
          });
        });

    FirebaseFirestore.instance
        .collection('phrasesentencespracticeset')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            spcount = snapshot.docs.length;
          });
        });

    FirebaseFirestore.instance
        .collection('storylinepracticeset')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            slcount = snapshot.docs.length;
          });
        });
  }

  Widget _practiceCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.only(right: 16),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, color.withValues(alpha: 0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 28, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Manage Practice Sets",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  "School Year: ${widget.schoolyear.schoolyearstart} - ${widget.schoolyear.schoolyearend}",
                ),
                const SizedBox(height: 4),
                Text("Section: ${widget.section.sectionname}"),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text("Manage"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.backgroundColor),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _practiceCard(
            title: 'Word Recognition',
            icon: Icons.spellcheck,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageWRPS(
                    section: widget.section,
                    schoolyear: widget.schoolyear,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          _practiceCard(
            title: 'Phrase & Sentences',
            icon: Icons.short_text,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SentencePS(
                    section: widget.section,
                    schoolyear: widget.schoolyear,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          _practiceCard(
            title: 'Storyline',
            icon: Icons.menu_book,
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageSLPS(
                    section: widget.section,
                    schoolyear: widget.schoolyear,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
