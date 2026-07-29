import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/sentences.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/teacher/practice_set/sentences/add_sentences.dart';
import 'package:ireader_web/views/teacher/practice_set/sentences/edit_sentences.dart';

class SentencePS extends StatefulWidget {
  final Section section;
  final SchoolYear schoolyear;
  const SentencePS({
    super.key,
    required this.section,
    required this.schoolyear,
  });

  @override
  State<SentencePS> createState() => _SentencePSState();
}

class _SentencePSState extends State<SentencePS> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String selectedFilter = "All";
  String selectedCategory = "All";
  String selectedGradeLevel = "All";

  Stream<QuerySnapshot> _fetchSentencesPracticeSets() {
    return firestore
        .collection('phrasesentencespracticeset')
        .where('sectionid', isEqualTo: widget.section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .snapshots();
  }

  Future<void> _handlePracticeSetAction(
    BuildContext context,
    String value,
    sentencespracticeset sentencepracticesets,
  ) async {
    if (value == "edit") {
      if (sentencepracticesets.visibility == "View to Students") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("This practice set is locked for editing."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              EditSentences(sentencepracticesets: sentencepracticesets),
        ),
      );
    } else if (value == "delete") {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Delete Quiz"),
          content: Text("Are you sure you want to delete this quiz?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text("Delete", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await firestore
            .collection("phrasesentencespracticeset")
            .doc(sentencepracticesets.id)
            .delete();
      }
    }
  }

  Widget _buildFilterSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }

  Widget _buildChip(
    String label,
    String selectedValue,
    Function(String) onSelected,
  ) {
    final bool isSelected = selectedValue == label;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.green.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(label),
      selectedColor: Colors.green.shade700,
      backgroundColor: Colors.white.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16), // 👈 adds right margin
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddSentences(
                      section: widget.section,
                      schoolyear: widget.schoolyear,
                    ),
                  ),
                );
                setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Practice Set"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],

        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade500, Colors.green.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.lightBlue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // HEADER SECTION
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade500, Colors.green.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.short_text, color: Colors.white, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'Phrase & Sentences',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Phrase Sentence Reviewer',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// VISIBILITY
                        _buildFilterSection(
                          title: "Visibility",
                          children: [
                            _buildChip("All", selectedFilter, (v) {
                              setState(() => selectedFilter = v);
                            }),
                            _buildChip("View to Students", selectedFilter, (v) {
                              setState(() => selectedFilter = v);
                            }),
                            _buildChip("Hide from Students", selectedFilter, (
                              v,
                            ) {
                              setState(() => selectedFilter = v);
                            }),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// CATEGORY
                        _buildFilterSection(
                          title: "Category",
                          children: [
                            _buildChip("All", selectedCategory, (v) {
                              setState(() => selectedCategory = v);
                            }),
                            _buildChip("Frustration", selectedCategory, (v) {
                              setState(() => selectedCategory = v);
                            }),
                            _buildChip("Instructional", selectedCategory, (v) {
                              setState(() => selectedCategory = v);
                            }),
                            _buildChip("Independent", selectedCategory, (v) {
                              setState(() => selectedCategory = v);
                            }),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// GRADE LEVEL
                        _buildFilterSection(
                          title: "Grade Level",
                          children: [
                            _buildChip("All", selectedGradeLevel, (v) {
                              setState(() => selectedGradeLevel = v);
                            }),
                            _buildChip("Grade 1", selectedGradeLevel, (v) {
                              setState(() => selectedGradeLevel = v);
                            }),
                            _buildChip("Grade 2", selectedGradeLevel, (v) {
                              setState(() => selectedGradeLevel = v);
                            }),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Align(alignment: Alignment.centerRight),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // PRACTICE SETS LIST
              StreamBuilder<QuerySnapshot>(
                stream: _fetchSentencesPracticeSets(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error loading practice sets"));
                  }
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    );
                  }

                  var practicesets = snapshot.data!.docs
                      .map(
                        (doc) => sentencespracticeset.fromMap(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ),
                      )
                      .toList();

                  if (selectedFilter != "All") {
                    practicesets = practicesets
                        .where((set) => set.visibility == selectedFilter)
                        .toList();
                  }

                  if (selectedCategory != "All") {
                    practicesets = practicesets
                        .where((set) => set.category == selectedCategory)
                        .toList();
                  }

                  if (selectedGradeLevel != "All") {
                    practicesets = practicesets
                        .where((set) => set.gradelevel == selectedGradeLevel)
                        .toList();
                  }

                  if (practicesets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 64,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No practice sets yet",
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddSentences(
                                    section: widget.section,
                                    schoolyear: widget.schoolyear,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                            child: const Text(
                              "Add Phrase and Sentence Practice Set",
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    primary: false,
                    itemCount: practicesets.length,
                    itemBuilder: (context, index) {
                      final sentencespracticeset practiceset =
                          practicesets[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap:
                                practiceset.visibility == "Hide from Students"
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditSentences(
                                          sentencepracticesets: practiceset,
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // LEFT ICON BOX
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.short_text,
                                      color: Colors.green,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  // TEXT CONTENT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          practiceset.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),

                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.quiz,
                                                  size: 14,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${practiceset.questions.length} Questions',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Published / Draft
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    practiceset.visibility ==
                                                        "View to Students"
                                                    ? Colors.green.shade100
                                                    : Colors.orange.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                practiceset.visibility ==
                                                        "View to Students"
                                                    ? 'Published'
                                                    : 'Draft',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      practiceset.visibility ==
                                                          "View to Students"
                                                      ? Colors.green.shade700
                                                      : Colors.orange.shade700,
                                                ),
                                              ),
                                            ),

                                            // Grade
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                practiceset.gradelevel,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),

                                            // Category
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                practiceset.category,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // RIGHT MENU
                                  // RIGHT MENU
                                  PopupMenuButton<String>(
                                    itemBuilder: (context) {
                                      final vis = practiceset.visibility;
                                      return [
                                        // EDIT - only if not published
                                        if (vis != "View to Students")
                                          PopupMenuItem(
                                            value: "edit",
                                            child: ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                Icons.edit,
                                                color: AppTheme.primaryColor,
                                              ),
                                              title: Text("Edit"),
                                            ),
                                          ),

                                        // PUBLISH - if currently hidden
                                        if (vis == "Hide from Students")
                                          PopupMenuItem(
                                            value: "View to Students",
                                            onTap: () async {
                                              await firestore
                                                  .collection(
                                                    "phrasesentencespracticeset",
                                                  )
                                                  .doc(practiceset.id)
                                                  .update({
                                                    "visibility":
                                                        "View to Students",
                                                  });
                                              if (mounted) setState(() {});
                                            },
                                            child: ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                Icons.remove_red_eye,
                                                color: AppTheme.primaryColor,
                                              ),
                                              title: Text("Publish"),
                                            ),
                                          ),

                                        // UNPUBLISH - if currently visible
                                        if (vis == "View to Students")
                                          PopupMenuItem(
                                            value: "Hide from Students",
                                            onTap: () async {
                                              await firestore
                                                  .collection(
                                                    "phrasesentencespracticeset",
                                                  )
                                                  .doc(practiceset.id)
                                                  .update({
                                                    "visibility":
                                                        "Hide from Students",
                                                  });
                                              if (mounted) setState(() {});
                                            },
                                            child: ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                Icons.visibility_off,
                                                color: Colors.redAccent,
                                              ),
                                              title: Text("Unpublish"),
                                            ),
                                          ),
                                      ];
                                    },
                                    onSelected: (value) =>
                                        _handlePracticeSetAction(
                                          context,
                                          value,
                                          practiceset,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
