import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/auth/rolegate.dart';
import 'package:ireader_web/services/auth_service.dart';
import 'package:ireader_web/firebase_options.dart';
import 'package:ireader_web/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iReader',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/login': (context) =>
            LoginScreen(errorMessage: AuthService.lastErrorMessage),
      },
    );
  }
}
