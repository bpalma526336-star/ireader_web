import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ireader_web/auth/login.dart';
import 'package:ireader_web/views/admin/admindashboard.dart';
import 'firebase_options.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
      routes: {'/login': (context) => LoginScreen()},
    );
  }
}
