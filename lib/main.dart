import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/settings_tab.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(ProviderScope(child: SageToolsApp()));
}

class SageToolsApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final isDark = theme.id == 'oled';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sage Tools',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.robotoFlex().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primary,
          brightness: isDark ? Brightness.dark : Brightness.light,
          primary: theme.primary,
          primaryContainer: theme.primaryContainer,
          secondaryContainer: theme.secondaryContainer,
          surface: theme.surface,
          surfaceContainer: theme.surfaceContainer,
        ),
        scaffoldBackgroundColor: theme.surface,
      ),
      home: MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Sage Tools", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
                  CircleAvatar(backgroundColor: Colors.transparent, child: Icon(Icons.account_circle, color: colors.onSurfaceVariant))
                ],
              ),
            ),
            Expanded(child: _selectedIndex == 0 ? DashboardView() : SettingsView()),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          border: Border(top: BorderSide(color: colors.outlineVariant.withOpacity(0.1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.grid_view_rounded, label: "Dashboard", isActive: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
            _NavItem(icon: Icons.settings_rounded, label: "Settings", isActive: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: isActive ? colors.primary : colors.onSurfaceVariant),
      if(isActive) Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
    ]));
  }
}
