import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'views/screens/login_screen.dart';
import 'views/screens/main_scaffold.dart';

class GereComApp extends StatelessWidget {
  const GereComApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GereCom Pesqueira',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E51A4),
          primary: const Color(0xFF2E51A4),
          secondary: const Color(0xFFF1C62F),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const MainScaffold();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
