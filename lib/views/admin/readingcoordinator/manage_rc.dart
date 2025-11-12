import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/readingcoordinator.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/admin/practice_set/manage_practice_set.dart';
import 'package:ireader_web/views/admin/readingcoordinator/add_rc.dart';
import 'package:ireader_web/views/admin/schoolyear/manage_schoolyear.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';

class ManageRcScreen extends StatefulWidget {
  const ManageRcScreen({super.key});

  @override
  State<ManageRcScreen> createState() => _ManageRcScreenState();
}

class _ManageRcScreenState extends State<ManageRcScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String status = "active";
  String selectedFilter = "All";

  Stream<QuerySnapshot> fetchRC() {
    Query rcs = _firestore.collection("readingcoordinators");

    return rcs.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Reading Coordinator"),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('Add Reading Coordinator'),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddRCScreen()),
                );
              },
            ),
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
              leading: const Icon(Icons.book, color: AppTheme.textPrimaryColor),
              title: const Text(
                'Practice Set',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.textPrimaryColor,
                ),
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
                Icons.integration_instructions,
                color: AppTheme.primaryColor,
              ),
              title: const Text(
                'Reading Coordinators',
                style: TextStyle(fontSize: 20, color: AppTheme.primaryColor),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageRcScreen(),
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
                    "Active",
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                  selected: selectedFilter == "active",
                  selectedColor: AppTheme.primaryColor,
                  onSelected: (selected) {
                    setState(() {
                      selectedFilter = "active";
                    });
                  },
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    "Inactive",
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                  selected: selectedFilter == "inactive",
                  selectedColor: AppTheme.primaryColor,
                  onSelected: (selected) {
                    setState(() {
                      selectedFilter = "inactive";
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: fetchRC(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: "));
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                var rcs = snapshot.data!.docs
                    .map(
                      (doc) => RC.fromMap(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList();

                if (selectedFilter != "All") {
                  rcs = rcs
                      .where((set) => set.status == selectedFilter)
                      .toList();
                }

                // final teachers = snapshot.data!.docs
                //     .map(
                //       (doc) => Teacher.fromMap(
                //         doc.id,
                //         doc.data() as Map<String, dynamic>,
                //       ),
                //     )
                //     .toList();

                if (rcs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          size: 64,
                          color: AppTheme.textSecondaryColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No Reading Coordinator Yet",
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddRCScreen(),
                              ),
                            );
                          },
                          child: const Text("Add School Year"),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: rcs.length,
                  itemBuilder: (context, index) {
                    final RC rc = rcs[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        // onTap: () {
                        //   Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder: (context) =>
                        //           ManageSection(schoolyear: schoolyear),
                        //     ),
                        //   );
                        // },
                        contentPadding: EdgeInsets.all(16),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${rc.firstname} ${rc.middlename} ${rc.lastname}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text("Email: ${rc.email}"),
                            Text("Phone Number: ${rc.phonenumber}"),
                            Text("Status: ${rc.status}"),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: "edit",
                              child: ListTile(
                                leading: Icon(
                                  Icons.edit,
                                  color: AppTheme.primaryColor,
                                ),
                                title: Text("Edit"),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              // 👇 dynamic value & label depending on teacher.status
                              value: rc.status == "active"
                                  ? "inactive"
                                  : "active",
                              child: ListTile(
                                leading: Icon(
                                  rc.status == "active"
                                      ? Icons.disabled_by_default
                                      : Icons.check_circle,
                                  color: rc.status == "active"
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                ),
                                title: Text(
                                  rc.status == "active"
                                      ? "Set Inactive"
                                      : "Set Active",
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == "edit") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddRCScreen(rc: rc),
                                ),
                              );
                            } else if (value == "inactive" ||
                                value == "active") {
                              _firestore
                                  .collection("students")
                                  .doc(rc.id)
                                  .update({"status": value});
                            }
                          },
                        ),
                        // onTap: () {
                        //   Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder: (context) => ManageQuizesScreen(
                        //         categoryId: category.id,
                        //         categoryName: category.name,
                        //       ),
                        //     ),
                        //   );
                        // },
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
}
