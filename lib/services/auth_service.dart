import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ireader_web/core/firestore_collections.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/teacher.dart';

enum UserRole { admin, readingCoordinator, teacher }

class AuthSession {
  final UserRole role;
  final Teacher? teacher;
  final SchoolYear? schoolYear;

  const AuthSession.admin() : role = UserRole.admin, teacher = null, schoolYear = null;

  const AuthSession.readingCoordinator()
    : role = UserRole.readingCoordinator,
      teacher = null,
      schoolYear = null;

  const AuthSession.teacher({required this.teacher, required this.schoolYear})
    : role = UserRole.teacher;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Shown on the login screen after a signed-in user fails role resolution.
  static String? lastErrorMessage;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    lastErrorMessage = null;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      provider.setCustomParameters({'prompt': 'select_account'});

      final userCredential = await _auth.signInWithPopup(provider);
      return userCredential.user;
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<AuthSession> resolveSession(String email) async {
    final normalizedEmail = email.trim();

    // Run all 3 role lookups in parallel instead of sequentially
    final results = await Future.wait([
      _firestore.collection(FirestoreCollections.teachers).where('email', isEqualTo: normalizedEmail).limit(1).get(),
      _firestore.collection(FirestoreCollections.admins).where('email', isEqualTo: normalizedEmail).limit(1).get(),
      _firestore.collection(FirestoreCollections.readingCoordinators).where('email', isEqualTo: normalizedEmail).limit(1).get(),
    ]);

    final teacherQuery = results[0];
    final adminQuery = results[1];
    final rcQuery = results[2];

    if (teacherQuery.docs.isNotEmpty) {
      final teacherDoc = teacherQuery.docs.first;

      if (teacherDoc['status'] != 'ACTIVE') {
        await _auth.signOut();
        throw Exception('Teacher account inactive.');
      }

      final teacher = Teacher.fromMap(teacherDoc.id, teacherDoc.data());

      final sectionQuery = await _firestore
          .collection(FirestoreCollections.sections)
          .where('teacherid', isEqualTo: teacher.id)
          .limit(1)
          .get();

      if (sectionQuery.docs.isEmpty) {
        await _auth.signOut();
        throw Exception('No section assigned to this teacher.');
      }

      final schoolYearId = sectionQuery.docs.first.data()['schoolyearid'];
      final schoolYearDoc = await _firestore
          .collection(FirestoreCollections.schoolYears)
          .doc(schoolYearId)
          .get();

      if (!schoolYearDoc.exists) {
        await _auth.signOut();
        throw Exception('School year not found.');
      }

      return AuthSession.teacher(
        teacher: teacher,
        schoolYear: SchoolYear.fromMap(schoolYearDoc.id, schoolYearDoc.data()!),
      );
    }

    if (adminQuery.docs.isNotEmpty) {
      if (adminQuery.docs.first['status'] != 'ACTIVE') {
        await _auth.signOut();
        throw Exception('Account inactive.');
      }
      return const AuthSession.admin();
    }

    if (rcQuery.docs.isNotEmpty) {
      if (rcQuery.docs.first['status'] != 'ACTIVE') {
        await _auth.signOut();
        throw Exception('Account inactive.');
      }
      return const AuthSession.readingCoordinator();
    }

    await _auth.signOut();
    throw Exception('No account associated with this Google account.');
  }

  Future<void> signOut() => _auth.signOut();
}
