import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/services/auth_service.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'package:ireader_web/views/readingcoordinator/rcdashboard.dart';
import 'package:ireader_web/views/teacher/sections/teacher_manage_section.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, AuthService? authService})
    : _authService = authService;

  final AuthService? _authService;

  AuthService get authService => _authService ?? AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null || user.email == null) {
          return LoginScreen(errorMessage: AuthService.lastErrorMessage);
        }

        return RoleGate(email: user.email!, authService: authService);
      },
    );
  }
}

class RoleGate extends StatefulWidget {
  const RoleGate({
    super.key,
    required this.email,
    AuthService? authService,
  }) : _authService = authService;

  final String email;
  final AuthService? _authService;

  AuthService get authService => _authService ?? AuthService();

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<AuthSession> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = widget.authService.resolveSession(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          AuthService.lastErrorMessage = snapshot.error.toString();
          return LoginScreen(errorMessage: AuthService.lastErrorMessage);
        }

        final session = snapshot.data!;
        switch (session.role) {
          case UserRole.admin:
            return const AdminDashboard();
          case UserRole.readingCoordinator:
            return RCDashboard(divisionId: session.divisionId);
          case UserRole.teacher:
            if (session.teacher == null || session.schoolYear == null) {
              AuthService.lastErrorMessage = "Incomplete teacher profile. Please contact your administrator.";
              return LoginScreen(errorMessage: AuthService.lastErrorMessage);
            }
            return TeacherManageSection(
              teacher: session.teacher!,
              schoolyear: session.schoolYear!,
            );
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'iR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
