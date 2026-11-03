import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'ui/screens/reaction_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReactionApp());
}

class ReactionApp extends StatelessWidget {
  const ReactionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reaction Lab',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Set default to light mode
      home: const ReactionHomeScreen(),
    );
  }
}
