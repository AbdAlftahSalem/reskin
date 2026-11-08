import 'package:flutter/material.dart';
import 'package:reskin/reskin.dart';

import 'app_theme.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rewards_screen.dart';
import 'state/cart.dart';

void main() => runApp(const BunnApp());

class BunnApp extends StatelessWidget {
  const BunnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bunn',
      debugShowCheckedModeBanner: false,
      theme: bunnLight,
      darkTheme: bunnDark,
      themeMode: ThemeMode.light,
      // reskin: one line, debug-only (returns the app unchanged in release).
      builder: Reskin.builder(
        theme: bunnLight,
        darkTheme: bunnDark,
        provider: ReskinProviders.fromEnvironment(fonts: bundledFonts),
        onExport: (code) => debugPrint('reskin export: ${code.length} chars'),
        // Float the reskin pill above the bottom navigation bar.
        panelBottomOffset: 84,
      ),
      home: const BunnShell(),
    );
  }
}

class BunnShell extends StatefulWidget {
  const BunnShell({super.key});

  @override
  State<BunnShell> createState() => _BunnShellState();
}

class _BunnShellState extends State<BunnShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenCart: () => setState(() => _tab = 1)),
      const CartScreen(),
      const RewardsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: ValueListenableBuilder<List<CartLine>>(
        valueListenable: cart,
        builder: (context, lines, _) {
          final count = lines.fold<int>(0, (n, l) => n + l.qty);
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: <NavigationDestination>[
              const NavigationDestination(
                  icon: Icon(Icons.local_cafe_outlined),
                  selectedIcon: Icon(Icons.local_cafe),
                  label: 'Home'),
              NavigationDestination(
                  icon: Badge.count(
                      count: count,
                      isLabelVisible: count > 0,
                      child: const Icon(Icons.shopping_bag_outlined)),
                  selectedIcon: Badge.count(
                      count: count,
                      isLabelVisible: count > 0,
                      child: const Icon(Icons.shopping_bag)),
                  label: 'Order'),
              const NavigationDestination(
                  icon: Icon(Icons.workspace_premium_outlined),
                  selectedIcon: Icon(Icons.workspace_premium),
                  label: 'Rewards'),
              const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
          );
        },
      ),
    );
  }
}
