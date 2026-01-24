import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui'; 
import 'core.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/settings_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // We can't set status bar color here nicely for both modes, 
  // so we let the Scaffold handle it.
  runApp(ProviderScope(child: SageApp()));
}

class SageApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sageTheme = ref.watch(currentThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sage Tools',
      themeMode: themeMode,
      
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sageTheme.primary,
          brightness: Brightness.light,
          surface: Color(0xFFF4F4F5), // Light Grey
          surfaceContainer: Colors.white, // Card BG
        ),
        scaffoldBackgroundColor: Color(0xFFF4F4F5),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sageTheme.primary,
          brightness: Brightness.dark,
          surface: Color(0xFF09090B), // Deep Black/Grey
          surfaceContainer: Color(0xFF18181B), // Card BG Dark
          onSurface: Color(0xFFFAFAFA),
        ),
        scaffoldBackgroundColor: Color(0xFF09090B),
      ),

      home: MainScaffold(),
    );
  }
}

class MainScaffold extends ConsumerStatefulWidget {
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
        children: [
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
              color: theme.surfaceContainer.withOpacity(0.85), // Dynamic
              border: Border(top: BorderSide(color: theme.outlineVariant.withOpacity(0.2))),
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

  _NavBarItem({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? theme.onPrimaryContainer : theme.onSurfaceVariant, size: 24),
            if (isActive) ...[
              SizedBox(width: 8),
              Text(label, style: TextStyle(color: theme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}
