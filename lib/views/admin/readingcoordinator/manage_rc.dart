import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/model/readingcoordinator.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/admin/practice_set/select_practice_set.dart';
import 'package:ireader_web/views/admin/readingcoordinator/add_rc.dart';
import 'package:ireader_web/views/admin/readingcoordinator/add_rc_dialog.dart';
import 'package:ireader_web/views/admin/schoolyear/manage_schoolyear.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';
import 'dart:html' as html;

class ManageRcScreen extends StatefulWidget {
  const ManageRcScreen({super.key});

  @override
  State<ManageRcScreen> createState() => _ManageRcScreenState();
}

class _ManageRcScreenState extends State<ManageRcScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String status = "ACTIVE";
  String selectedFilter = "All";
  final TextEditingController _searchController = TextEditingController();

  Stream<QuerySnapshot> fetchRC() {
    Query rcs = _firestore.collection("readingcoordinators");

    return rcs.snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobile = screenWidth <= 768;

              void onPressed() {
                if (isMobile) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddRCScreen(),
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AddRcDialog(rc: null),
                  );
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobile
                    ? IconButton(
                        icon: const Icon(Icons.person_add),
                        tooltip: 'Add Reading Coordinator',
                        onPressed: onPressed,
                      )
                    : ElevatedButton.icon(
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
                        onPressed: onPressed,
                      ),
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
                      'assets/images/Department-of-Education-DepEd-Seal-300x300.png',
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
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Log Out',
                style: TextStyle(fontSize: 20, color: Colors.redAccent),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();

                html.window.history.pushState(null, '', '');
                html.window.onPopState.listen((event) {
                  html.window.history.pushState(null, '', '');
                });

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Center(
                  child: AutoSizeText(
                    "Manage Reading Coordinators",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search reading coordinators by name or email',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text(
                        "All",
                        style: TextStyle(
                          color: selectedFilter == "All"
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                        ),
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
                        style: TextStyle(
                          color: selectedFilter == "ACTIVE"
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                        ),
                      ),
                      selected: selectedFilter == "ACTIVE",
                      selectedColor: AppTheme.primaryColor,
                      onSelected: (selected) {
                        setState(() {
                          selectedFilter = "ACTIVE";
                        });
                      },
                    ),

                    SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        "Inactive",
                        style: TextStyle(
                          color: selectedFilter == "INACTIVE"
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                        ),
                      ),
                      selected: selectedFilter == "INACTIVE",
                      selectedColor: AppTheme.primaryColor,
                      onSelected: (selected) {
                        setState(() {
                          selectedFilter = "INACTIVE";
                        });
                      },
                    ),
                  ],
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

                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  rcs = rcs.where((t) {
                    final fullName =
                        "${t.firstname} ${t.middlename} ${t.lastname}"
                            .toLowerCase();
                    return fullName.contains(query) ||
                        t.email.toLowerCase().contains(query);
                  }).toList();
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
                          child: const Text("Add Reading Coordinator"),
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
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.1,
                          ),
                          child: Text(
                            (rc.firstname.isNotEmpty ? rc.firstname[0] : 'R')
                                .toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        title: Text(
                          "${rc.firstname} ${rc.middlename ?? ""} ${rc.lastname}"
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 6),
                            Text("Email: ${rc.email}"),
                            SizedBox(height: 4),
                            Text(
                              "Status: ${rc.status}",
                              style: TextStyle(
                                color: rc.status == "ACTIVE"
                                    ? Colors.green
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: Icon(
                                Icons.edit,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                final screenWidth = MediaQuery.of(
                                  context,
                                ).size.width;

                                if (screenWidth > 600) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AddRcDialog(rc: rc),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddRCScreen(rc: rc),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: rc.status == "ACTIVE"
                                  ? 'Set Inactive'
                                  : 'Set Active',
                              icon: Icon(
                                rc.status == "ACTIVE"
                                    ? Icons.toggle_on
                                    : Icons.toggle_off,
                                color: rc.status == "ACTIVE"
                                    ? Colors.green
                                    : Colors.grey,
                                size: 28,
                              ),
                              onPressed: () async {
                                final newStatus = rc.status == "ACTIVE"
                                    ? "INACTIVE"
                                    : "ACTIVE";
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      '${rc.status == "ACTIVE" ? "Deactivate" : "Activate"} Reading Coordinator',
                                    ),
                                    content: Text(
                                      'Are you sure you want to ${rc.status == "ACTIVE" ? "set this reading coordinator as inactive" : "set this reading coordinator as active"}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text('Confirm'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed ?? false) {
                                  _firestore
                                      .collection('readingcoordinators')
                                      .doc(rc.id)
                                      .update({'status': newStatus});
                                }
                              },
                            ),
                          ],
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
}
