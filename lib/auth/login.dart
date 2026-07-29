import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/views/readingcoordinator/rcdashboard.dart';
import 'package:ireader_web/views/readingcoordinator/schoolyears/manage_schoolyear.dart';
import 'package:ireader_web/views/teacher/sections/teacher_manage_section.dart';
import 'package:ireader_web/model/schoolyear.dart';
// import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  // final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;

  // ---------------------------
  // LOGIN FUNCTION (Google Sign-In for Web, role-based)
  // ---------------------------

  Future<void> login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      User? user;

      if (kIsWeb) {
        // 🌐 WEB LOGIN
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        provider.setCustomParameters({'prompt': 'select_account'});

        final userCredential = await FirebaseAuth.instance.signInWithPopup(
          provider,
        );

        user = userCredential.user;
      } else {
        // 📱 ANDROID LOGIN
        final GoogleSignIn googleSignIn = GoogleSignIn();

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // User cancelled
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        user = userCredential.user;
      }

      if (user == null || user.email == null) {
        return;
      }

      final email = user.email!.trim();

      // Check teacher first (teachers have no extra roles)
      final teacherQuery = await FirebaseFirestore.instance
          .collection("teachers")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();

      if (teacherQuery.docs.isNotEmpty) {
        final teacherDoc = teacherQuery.docs.first;

        if (teacherDoc['status'] != 'ACTIVE') {
          await FirebaseAuth.instance.signOut();
          throw Exception("Teacher account inactive.");
        }

        final teacher = Teacher.fromMap(teacherDoc.id, teacherDoc.data());

        // Fetch active schoolyear
        // Get one section assigned to this teacher
        final sectionQuery = await FirebaseFirestore.instance
            .collection("sections")
            .where("teacherid", isEqualTo: teacher.id)
            .limit(1)
            .get();

        if (sectionQuery.docs.isEmpty) {
          throw Exception("No section assigned to this teacher.");
        }

        final sectionData = sectionQuery.docs.first.data();
        final schoolyearId = sectionData["schoolyearid"];

        // Fetch correct schoolyear
        final syDoc = await FirebaseFirestore.instance
            .collection("schoolyears")
            .doc(schoolyearId)
            .get();

        if (!syDoc.exists) {
          throw Exception("School year not found.");
        }

        final schoolyear = SchoolYear.fromMap(syDoc.id, syDoc.data()!);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TeacherManageSection(teacher: teacher, schoolyear: schoolyear),
          ),
        );
        return;
      }

      // Check admin / reading coordinator
      final adminQuery = await FirebaseFirestore.instance
          .collection("admins")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();

      final rcQuery = await FirebaseFirestore.instance
          .collection("readingcoordinators")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final adminDoc = adminQuery.docs.first;

        if (adminDoc['status'] != 'ACTIVE') {
          await FirebaseAuth.instance.signOut();
          throw Exception('Account inactive.');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
        return;
      }

      if (rcQuery.docs.isNotEmpty) {
        final rcDoc = rcQuery.docs.first;

        if (rcDoc['status'] != 'ACTIVE') {
          await FirebaseAuth.instance.signOut();
          throw Exception('Account inactive.');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RCDashboard()),
        );
        return;
      }

      // No matching role — sign out and show error
      await FirebaseAuth.instance.signOut();
      throw Exception("No account associated with this Google account.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        // Web: user closed Google popup
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------
  // NAVIGATION AFTER LOGIN
  // ---------------------------
  void navigateBasedOnRole(String role) {
    if (role == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else if (role == "rc") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RCManageSchoolyearScreen()),
      );
    } else if (role == "teacher") {
      // Navigation for teachers is handled in the login function
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // <-- important (no full height)
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Department-of-Education-DepEd-Seal-300x300.png',
                        width: isMobile ? 80 : 100,
                      ),
                      const SizedBox(width: 12),
                      Image.asset(
                        'assets/images/untitled-1.png',
                        width: isMobile ? 80 : 100,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'KAGAWARAN NG EDUKASYON',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Text(
                    'REPUBLIKA NG PILIPINAS',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Container(height: 2, color: AppTheme.primaryColor),

                  const SizedBox(height: 20),

                  const Text(
                    'iReader: Reading Comprehensive Assessment System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ Button auto-size (NOT full width)
                  ElevatedButton(
                    onPressed: _isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'SIGN IN WITH GOOGLE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
