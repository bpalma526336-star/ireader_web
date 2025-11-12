import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/practice_set.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/admin/practice_set/add_practice_set.dart';
import 'package:ireader_web/views/admin/practice_set/edit_practice_set.dart';
import 'package:ireader_web/views/admin/schoolyear/manage_schoolyear.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';

class ManagePracticeSet extends StatefulWidget {
  const ManagePracticeSet({super.key});

  @override
  State<ManagePracticeSet> createState() => _ManagePracticeSetState();
}

class _ManagePracticeSetState extends State<ManagePracticeSet> {
  String selectedFilter = "All";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> fetchPracticeSet() {
    Query query = _firestore.collection("practiceset");

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text(
          'Manage Practice Sets',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPracticeSet()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.backgroundColor),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Image.asset(
                      'assets/Department-of-Education-DepEd-Seal-300x300.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'iReader',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboard(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.book, color: AppTheme.primaryColor),
              title: const Text(
                'Practice Set',
                style: TextStyle(fontSize: 20, color: AppTheme.primaryColor),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManagePracticeSet(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Set Up',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageSchoolyearScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageAdminScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.textPrimaryColor,
              ),
              title: const Text(
                'Teachers',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageTeacherScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(
                    "All",
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                  selected: selectedFilter == "All",
                  selectedColor: AppTheme.primaryColor,
                  onSelected: (selected) {
                    setState(() {
                      selectedFilter = "All";
                    });
                  },
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    "View to Students",
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                  selected: selectedFilter == "View to Students",
                  selectedColor: AppTheme.primaryColor,
                  onSelected: (selected) {
                    setState(() {
                      selectedFilter = "View to Students";
                    });
                  },
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    "Hide from Students",
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                  selected: selectedFilter == "Hide from Students",
                  selectedColor: AppTheme.primaryColor,
                  onSelected: (selected) {
                    setState(() {
                      selectedFilter = "Hide from Students";
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: fetchPracticeSet(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error"));
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
                      (doc) => PracticeSet.fromMap(
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
                        SizedBox(height: 16),
                        Text(
                          "No practice sets yet",
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              (context),
                              MaterialPageRoute(
                                builder: (context) => AddPracticeSet(),
                              ),
                            );
                          },
                          child: Text("Add Practice Set"),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: practicesets.length,
                  itemBuilder: (context, index) {
                    final PracticeSet practiceset = practicesets[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.quiz_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          practiceset.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.category_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                SizedBox(width: 4),
                                Text("Category: ${practiceset.category}"),
                                SizedBox(width: 16),
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                SizedBox(width: 4),
                                Text("Visibility: ${practiceset.visibility}"),
                                SizedBox(width: 16),
                                Icon(
                                  Icons.question_answer_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "${practiceset.questions.length} Questions",
                                ),
                                SizedBox(width: 16),
                                Icon(Icons.timer_outlined, size: 16),
                                SizedBox(width: 4),
                                Text("${practiceset.timeLimit} mins"),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
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
                            PopupMenuItem(
                              value: "delete",
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                title: Text("Delete"),
                              ),
                            ),
                          ],
                          onSelected: (value) => _handlePracticeSetAction(
                            context,
                            value,
                            practiceset,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePracticeSetAction(
    BuildContext context,
    String value,
    PracticeSet practiceset,
  ) async {
    if (value == "edit") {
      if (practiceset.visibility == "View to Students") {
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
          builder: (context) => EditPracticeSet(practiceSet: practiceset),
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
        await _firestore.collection("practiceset").doc(practiceset.id).delete();
      }
    }
  }
}
