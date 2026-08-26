import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/views/teacher/parent/manage_parents.dart';
import 'package:ireader_web/views/teacher/sections/teacher_manage_section.dart';

class TeacherSidebar extends StatelessWidget {
  final Teacher teacher;
  final SchoolYear schoolyear;

  const TeacherSidebar({
    super.key,
    required this.teacher,
    required this.schoolyear,
  });

  static const Color _bg = Color(0xFF0F172A);
  static const Color _activeBg = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF3B82F6);

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    html.window.history.pushState(null, '', '');
    final sub = html.window.onPopState.listen((_) {
      html.window.history.pushState(null, '', '');
    });
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
    await sub.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFF2D4E7E)),
                    ),
                    child: const Center(
                      child: Text(
                        'iR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'iReader',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'TEACHER PORTAL',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 8.5,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: const Color(0xFF1E293B)),
          const SizedBox(height: 6),
          _sectionItem(context),
          const SizedBox(height: 6),
          _manageparentitem(context),
          const Spacer(),
          Container(height: 1, color: const Color(0xFF1E293B)),
          _logoutItem(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: _activeBg,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherManageSection(
                  teacher: teacher,
                  schoolyear: schoolyear,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.class_outlined,
                    color: _accent,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Assigned Sections',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _manageparentitem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: _activeBg,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ManageParents(teacher: teacher, schoolyear: schoolyear),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.people, color: _accent, size: 14),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Manage Parents',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoutItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          hoverColor: Colors.red.withValues(alpha: 0.08),
          onTap: () => _logout(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                      size: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
