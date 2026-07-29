import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/readingcoordinator/rcdashboard.dart';
import 'package:ireader_web/views/teacher/sections/teacher_manage_section.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/model/schoolyear.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data!.docs.isNotEmpty) {
          return const AdminDashboard();
        }

        return const LoginScreen();
      },
    );
  }
}
