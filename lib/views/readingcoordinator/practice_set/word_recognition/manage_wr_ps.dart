import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/word_recognition.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/readingcoordinator/practice_set/word_recognition/add_wr_ps.dart';
import 'package:ireader_web/views/readingcoordinator/practice_set/word_recognition/edit_wr_ps.dart';

class ManageWRPS extends StatefulWidget {
  final Section section;
  final SchoolYear schoolyear;
  const ManageWRPS({
    super.key,
    required this.section,
    required this.schoolyear,
  });

  @override
  State<ManageWRPS> createState() => _ManageWRPSState();
}

class _ManageWRPSState extends State<ManageWRPS> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String selectedFilter = "All";
  String selectedCategory = "All";
  String selectedGradeLevel = "All";

  Stream<QuerySnapshot> _fetchWordRecognitionPracticeSets() {
    return firestore
        .collection('wordrecognitionpracticeset')
        .where('sectionid', isEqualTo: widget.section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .snapshots();
  }

  Future<void> _handlePracticeSetAction(
    BuildContext context,
    String value,
    WordRecognition wordrecognition,
  ) async {
    if (value == "edit") {
      if (wordrecognition.visibility == "View to Students") {
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
          builder: (context) => EditWordRecognition(wrcontent: wordrecognition),
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
            .collection("wordrecognitionpracticeset")
            .doc(wordrecognition.id)
            .delete();
      }
    }
  }

  Widget _filterVisibleChip(String label) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selectedFilter == label
              ? Colors.white
              : AppTheme.textPrimaryColor,
        ),
      ),
      selected: selectedFilter == label,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white30,

      onSelected: (_) {
        setState(() => selectedFilter = label);
      },
    );
  }

  Widget _filterCategoryChip(String label) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selectedCategory == label
              ? Colors.white
              : AppTheme.textPrimaryColor,
        ),
      ),
      selected: selectedCategory == label,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white30,

      onSelected: (_) {
        setState(() => selectedCategory = label);
      },
    );
  }

  Widget _filterGradeLevelChip(String label) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selectedGradeLevel == label
              ? Colors.white
              : AppTheme.textPrimaryColor,
        ),
      ),
      selected: selectedGradeLevel == label,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white30,

      onSelected: (_) {
        setState(() => selectedGradeLevel = label);
      },
    );
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
          color: isSelected ? Colors.white : Colors.blue.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(label),
      selectedColor: Colors.blue.shade700,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade500, Colors.blue.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// ================= HEADER (COPIED STYLE) =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade500, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.spellcheck, color: Colors.white, size: 40),

                    const SizedBox(height: 10),

                    const Text(
                      'Word Recognition',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Word Recognition Reviewer',
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
                          title: "All Category",
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
                          title: "All Grade level",
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

              /// ================= LIST =================
              StreamBuilder<QuerySnapshot>(
                stream: _fetchWordRecognitionPracticeSets(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var sets = snapshot.data!.docs
                      .map(
                        (doc) => WordRecognition.fromMap(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ),
                      )
                      .toList();

                  if (selectedFilter != "All") {
                    sets = sets
                        .where((s) => s.visibility == selectedFilter)
                        .toList();
                  }

                  if (selectedCategory != "All") {
                    sets = sets
                        .where((set) => set.category == selectedCategory)
                        .toList();
                  }

                  if (selectedGradeLevel != "All") {
                    sets = sets
                        .where((set) => set.gradelevel == selectedGradeLevel)
                        .toList();
                  }

                  if (sets.isEmpty) {
                    return const Center(child: Text("No practice sets yet"));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    primary: false,
                    itemCount: sets.length,
                    itemBuilder: (context, index) {
                      final set = sets[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),

                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(16),

                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),

                            child: Padding(
                              padding: const EdgeInsets.all(16),

                              child: Row(
                                children: [
                                  /// LEFT ICON BOX
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.menu_book,
                                      color: Colors.blue,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  /// CONTENT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          set.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),

                                        const SizedBox(height: 6),
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
                                                const Icon(
                                                  Icons.quiz,
                                                  size: 14,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${set.questions.length} Questions',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    set.visibility ==
                                                        "View to Students"
                                                    ? Colors.purple.shade100
                                                    : Colors.orange.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                set.visibility ==
                                                        "View to Students"
                                                    ? 'Published'
                                                    : 'Draft',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      set.visibility ==
                                                          "View to Students"
                                                      ? Colors.blue.shade700
                                                      : Colors.orange.shade700,
                                                ),
                                              ),
                                            ),

                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                set.gradelevel,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),

                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                set.category,
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

                                  const SizedBox(width: 12),

                                  /// MENU
                                  ///
                                  // PopupMenuButton<String>(
                                  //   itemBuilder: (context) {
                                  //     final vis = set.visibility;
                                  //     return [
                                  //       // EDIT - only if not published
                                  //       if (vis != "View to Students")
                                  //         PopupMenuItem(
                                  //           value: "edit",
                                  //           child: ListTile(
                                  //             contentPadding: EdgeInsets.zero,
                                  //             leading: Icon(
                                  //               Icons.edit,
                                  //               color: AppTheme.primaryColor,
                                  //             ),
                                  //             title: Text("Edit"),
                                  //           ),
                                  //         ),

                                  //       // PUBLISH - if currently hidden
                                  //       if (vis == "Hide from Students")
                                  //         PopupMenuItem(
                                  //           value: "View to Students",
                                  //           onTap: () async {
                                  //             await firestore
                                  //                 .collection(
                                  //                   "wordrecognitionpracticeset",
                                  //                 )
                                  //                 .doc(set.id)
                                  //                 .update({
                                  //                   "visibility":
                                  //                       "View to Students",
                                  //                 });
                                  //             if (mounted) setState(() {});
                                  //           },
                                  //           child: ListTile(
                                  //             contentPadding: EdgeInsets.zero,
                                  //             leading: Icon(
                                  //               Icons.remove_red_eye,
                                  //               color: AppTheme.primaryColor,
                                  //             ),
                                  //             title: Text("Publish"),
                                  //           ),
                                  //         ),

                                  //       // UNPUBLISH - if currently visible
                                  //       if (vis == "View to Students")
                                  //         PopupMenuItem(
                                  //           value: "Hide from Students",
                                  //           onTap: () async {
                                  //             await firestore
                                  //                 .collection(
                                  //                   "wordrecognitionpracticeset",
                                  //                 )
                                  //                 .doc(set.id)
                                  //                 .update({
                                  //                   "visibility":
                                  //                       "Hide from Students",
                                  //                 });
                                  //             if (mounted) setState(() {});
                                  //           },
                                  //           child: ListTile(
                                  //             contentPadding: EdgeInsets.zero,
                                  //             leading: Icon(
                                  //               Icons.visibility_off,
                                  //               color: Colors.redAccent,
                                  //             ),
                                  //             title: Text("Unpublish"),
                                  //           ),
                                  //         ),
                                  //     ];
                                  //   },
                                  //   onSelected: (value) =>
                                  //       _handlePracticeSetAction(
                                  //         context,
                                  //         value,
                                  //         set,
                                  //       ),
                                  // ),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      backgroundColor: AppTheme.backgroundColor,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
