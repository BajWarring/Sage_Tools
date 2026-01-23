import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui'; // For blur
import 'core.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/settings_tab.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(ProviderScope(child: SageApp()));
}

class SageApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sage Tools',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: theme.background, // Zinc-50
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: theme.primary,
          backgroundColor: theme.background,
        ),
        fontFamily: 'Roboto', // Or standard sans
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
    final theme = ref.watch(currentThemeProvider);
    
    return Scaffold(
      extendBody: true, // For glass effect behind nav
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
              color: Colors.white.withOpacity(0.85),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.home_rounded,
                  label: "Home",
                  isActive: _tabIndex == 0,
                  activeColor: theme.primary[100]!,
                  activeIconColor: theme.primary[700]!,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _NavBarItem(
                  icon: Icons.settings_rounded,
                  label: "Settings",
                  isActive: _tabIndex == 1,
                  activeColor: theme.primary[100]!,
                  activeIconColor: theme.primary[700]!,
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
  final Color activeColor;
  final Color activeIconColor;
  final VoidCallback onTap;

  _NavBarItem({required this.icon, required this.label, required this.isActive, required this.activeColor, required this.activeIconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? activeIconColor : Colors.grey[400], size: 24),
            if (isActive) ...[
              SizedBox(width: 8),
              Text(label, style: TextStyle(color: activeIconColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}
