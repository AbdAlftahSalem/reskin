import 'package:flutter/material.dart';
import 'package:reskin/reskin.dart';

import 'home/home_page.dart';
import 'profile/profile_page.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
  fontFamily: 'Inter',
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.dark,
  ),
  fontFamily: 'Inter',
);

/// Font families in pubspec.yaml (assets/fonts).
const List<String> bundledFonts = <String>[
  'Inter',
  'Manrope',
  'Cormorant Garamond',
  'El Messiri',
  'JetBrains Mono',
  'DejaVu Serif',
];

void main() => runApp(const BazaarApp());

class BazaarApp extends StatelessWidget {
  const BazaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bazaar',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      // One line: debug-only, returns the app unchanged in release builds.
      builder: Reskin.builder(
        theme: lightTheme,
        darkTheme: darkTheme,
        // AI first: Gemini (or OpenAI) when you run with
        //   --dart-define=RESKIN_GEMINI_KEY=your-own-key
        // and the offline generator otherwise or when the call fails.
        // The model may only pick the fonts this app bundles.
        provider: ReskinProviders.fromEnvironment(fonts: bundledFonts),
        onExport: (code) => debugPrint('reskin export: ${code.length} chars'),
      ),
      home: const ShellPage(),
    );
  }
}

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab == 2 ? const ProfilePage() : const HomePage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Saved'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
