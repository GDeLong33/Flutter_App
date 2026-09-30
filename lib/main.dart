import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/providers.dart';
import 'screens/lineup_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      // Retries are handled explicitly (retry button, polling), so disable
      // Riverpod's automatic retry to surface errors immediately.
      retry: (_, _) => null,
      child: const LineupTrackerApp(),
    ),
  );
}

class LineupTrackerApp extends StatelessWidget {
  const LineupTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lineup Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: const LineupScreen(),
    );
  }
}
