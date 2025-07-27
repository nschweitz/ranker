import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ranker - Spotify Integration',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          secondary: Color(0xFF1DB954),
          surface: Color(0xFF000000),
          background: Color(0xFF000000),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          color: Color(0xFF000000),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      home: const MyHomePage(title: 'Ranker'),
    );
  }
}