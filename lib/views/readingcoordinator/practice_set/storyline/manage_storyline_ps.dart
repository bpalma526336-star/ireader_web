import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/storyline_practice_set.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/readingcoordinator/practice_set/storyline/add_storyline_ps.dart';
import 'package:ireader_web/views/readingcoordinator/practice_set/storyline/edit_storyline_ps.dart';

class ManageSLPS extends StatefulWidget {
  final Section section;
  final SchoolYear schoolyear;
  const ManageSLPS({
    super.key,
    required this.section,
    required this.schoolyear,
  });

  @override
  State<ManageSLPS> createState() => _ManageSLPSState();
}

class _ManageSLPSState extends State<ManageSLPS> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String selectedFilter = "All";
  String selectedCategory = "All";
  String selectedGradeLevel = "All";

  Stream<QuerySnapshot> _fetchStorylinePracticeSets() {
    return firestore
        .collection('storylinepracticeset')
        .where('sectionid', isEqualTo: widget.section.id)
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .snapshots();
  }

  Future<void> _handlePracticeSetAction(
    BuildContext context,
    String value,
    StorylinePracticeSet storylinepracticeset,
  ) async {
    if (value == "edit") {
      if (storylinepracticeset.visibility == "View to Students") {
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
              EditStoryLinePS(storylinePracticeSet: storylinepracticeset),
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
            .collection("storylinepracticeset")
            .doc(storylinepracticeset.id)
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
          color: isSelected ? Colors.white : Colors.purple.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(label),
      selectedColor: Colors.purple.shade700,
      backgroundColor: Colors.white.withOpacity(0.2),
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
              colors: [Colors.purple.shade500, Colors.purple.shade300],
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
                    colors: [Colors.purple.shade500, Colors.purple.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.auto_stories, color: Colors.white, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'Storyline Adventures',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Storyline Practice Reviewer',
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

              // STORYLINE LIST
              StreamBuilder<QuerySnapshot>(
                stream: _fetchStorylinePracticeSets(),
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
                        (doc) => StorylinePracticeSet.fromMap(
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
                      final StorylinePracticeSet practiceset =
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
                                        builder: (context) => EditStoryLinePS(
                                          storylinePracticeSet: practiceset,
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
                                      color: Colors.purple.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.menu_book,
                                      color: Colors.purple,
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
                                          style: TextStyle(
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
                                  // PopupMenuButton<String>(
                                  //   itemBuilder: (context) {
                                  //     final vis = practiceset.visibility;
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
                                  //                   "storylinepracticeset",
                                  //                 )
                                  //                 .doc(practiceset.id)
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
                                  //                   "storylinepracticeset",
                                  //                 )
                                  //                 .doc(practiceset.id)
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
                                  //         practiceset,
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
