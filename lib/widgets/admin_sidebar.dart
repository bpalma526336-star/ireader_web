import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/views/admin/admin/manage_admin.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/admin/division/manage_division.dart';
import 'package:ireader_web/views/admin/readingcoordinator/manage_rc.dart';
import 'package:ireader_web/views/admin/school/manage_school.dart';
import 'package:ireader_web/views/admin/schoolyear/manage_schoolyear.dart';
import 'package:ireader_web/views/admin/teacher/manage_teacher.dart';

enum AdminRoute { dashboard, schoolYears, divisions, schools, admins, readingCoordinators, teachers }

class AdminSidebar extends StatelessWidget {
  final AdminRoute activeRoute;

  const AdminSidebar({super.key, required this.activeRoute});

  static const Color _bg = Color(0xFF0F172A);
  static const Color _activeBg = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _accent = Color(0xFF3B82F6);

  void _navigate(BuildContext context, Widget page) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (_) => false,
    );
  }

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
                      border: Border.all(color: const Color(0xFF2D4E7E), width: 1),
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
                        'ADMIN PORTAL',
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
          _navItem(context, 'D', 'Dashboard', AdminRoute.dashboard, const AdminDashboard()),
          _navItem(context, 'Y', 'School Years', AdminRoute.schoolYears, const ManageSchoolyearScreen()),
          _navItem(context, 'V', 'Divisions', AdminRoute.divisions, const ManageDivisionScreen()),
          _navItem(context, 'S', 'Schools', AdminRoute.schools, const ManageSchoolScreen()),
          _navItem(context, 'A', 'Admins', AdminRoute.admins, const ManageAdminScreen()),
          _navItem(context, 'R', 'Reading Coords', AdminRoute.readingCoordinators, const ManageRcScreen()),
          _navItem(context, 'T', 'Teachers', AdminRoute.teachers, const ManageTeacherScreen()),
          const Spacer(),
          Container(height: 1, color: const Color(0xFF1E293B)),
          _logoutItem(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    String letter,
    String label,
    AdminRoute route,
    Widget page,
  ) {
    final isActive = activeRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isActive ? _activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          hoverColor: const Color(0xFF1E293B),
          onTap: isActive ? null : () => _navigate(context, page),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _accent.withValues(alpha: 0.18)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: isActive ? _accent : _muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : _muted,
                      fontSize: 12.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isActive)
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
                    child: Icon(Icons.logout, color: Colors.redAccent, size: 13),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
