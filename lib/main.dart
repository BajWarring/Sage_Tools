import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'core.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/settings_tab.dart';
import 'splash_screen.dart'; // <-- import the splash

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SageApp()));
}

class SageApp extends ConsumerWidget {
  const SageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sageTheme = ref.watch(currentThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sage Tools',
      themeMode: themeMode,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sageTheme.primary,
          brightness: Brightness.light,
          surface: const Color(0xFFF4F4F5),
          surfaceContainer: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F4F5),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sageTheme.primary,
          brightness: Brightness.dark,
          surface: const Color(0xFF09090B),
          surfaceContainer: const Color(0xFF18181B),
          onSurface: const Color(0xFFFAFAFA),
        ),
        scaffoldBackgroundColor: const Color(0xFF09090B),
      ),

      // ← Start from SplashScreen instead of MainScaffold directly
      home: const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main scaffold (referenced by HomePage inside splash_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          DashboardTab(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: theme.surfaceContainer.withOpacity(0.85),
              border: Border(
                  top: BorderSide(color: theme.outlineVariant.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.home_rounded,
                  label: "Home",
                  isActive: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _NavBarItem(
                  icon: Icons.settings_rounded,
                  label: "Settings",
                  isActive: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem(
      {required this.icon,
      required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isActive
                    ? theme.onPrimaryContainer
                    : theme.onSurfaceVariant,
                size: 24),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: theme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}
