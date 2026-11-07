import 'package:flutter/material.dart';
import 'System Login/login_page.dart';
import 'System Login/register_page.dart';
import 'Home/home_page.dart';
import '../ui/Theme/theme_notifier.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.themeMode,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Mobile App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          
          // Tema Terang (Light Mode)
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            cardColor: Colors.white,
            dividerColor: const Color(0xFFE0E0E0),
          ),

          // Tema Gelap (Dark Mode)
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            dividerColor: const Color(0xFF2C2C2C),
          ),

          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const RegisterPage(),
            '/': (context) => const HomePage(),
          },
        );
      },
    );
  }
}