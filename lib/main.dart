import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. Data Models & Decentralized Store (Mock) ---

class FileItem {
  final String name;
  final String date;
  final String size;
  final IconData icon;
  final String path; // Local/Decentralized path
  FileItem(this.name, this.date, this.size, this.icon, this.path);
}

class ToolItem {
  final String id;
  final String title;
  final IconData icon;
  final int count;
  final List<String> items;
  ToolItem(this.id, this.title, this.icon, this.count, this.items);
}

// Simulating a Decentralized / Local File System
final fileSystemProvider = Provider((ref) => [
  FileItem('Invoice_2026.pdf', '2h ago', '1.2MB', Icons.description, '/Internal/SageTools/Docs'),
  FileItem('Trip_Vlog.mp4', 'Yesterday', '142MB', Icons.video_file, '/Internal/SageTools/Media'),
  FileItem('Avatar.png', 'Oct 24', '2.8MB', Icons.image, '/Internal/SageTools/Images'),
  FileItem('Notes.txt', 'Oct 22', '12KB', Icons.description, '/Internal/SageTools/Docs'),
]);

final toolsProvider = Provider((ref) => [
  ToolItem('pdf', 'PDF Tools', Icons.picture_as_pdf, 6, ['Merge', 'Split', 'Sign', 'Compress', 'OCR']),
  ToolItem('img', 'Image Editor', Icons.photo_camera, 5, ['Resize', 'Crop', 'Filter', 'Convert', 'Markup']),
  ToolItem('vid', 'Video Studio', Icons.movie, 4, ['Trim', 'Audio', 'Speed', 'Mute']),
  ToolItem('util', 'Utilities', Icons.construction, 8, ['QR Gen', 'Scanner', 'Units', 'Time', 'Text']),
]);

// --- 2. Theme Engine (Matching HTML CSS Variables) ---

class AppTheme {
  final String id;
  final String name;
  final Color primary;
  final Color primaryContainer;
  final Color secondaryContainer;
  final Color surface;
  final Color surfaceContainer;

  AppTheme({
    required this.id, required this.name, required this.primary,
    required this.primaryContainer, required this.secondaryContainer,
    required this.surface, required this.surfaceContainer,
  });
}

final themes = [
  AppTheme(id: 'sakura', name: 'Sakura', primary: Color(0xFF984061), primaryContainer: Color(0xFFFFD9E2), secondaryContainer: Color(0xFFFFD9E2), surface: Color(0xFFFFF8F8), surfaceContainer: Color(0xFFFCEAEA)),
  AppTheme(id: 'lavender', name: 'Lavender', primary: Color(0xFF6750A4), primaryContainer: Color(0xFFEADDFF), secondaryContainer: Color(0xFFE8DEF8), surface: Color(0xFFFFF7FE), surfaceContainer: Color(0xFFF3EEFC)),
  AppTheme(id: 'mint', name: 'Mint', primary: Color(0xFF006C4C), primaryContainer: Color(0xFF89F8C7), secondaryContainer: Color(0xFFCEE9DA), surface: Color(0xFFFBFDF9), surfaceContainer: Color(0xFFEDF5EF)),
  AppTheme(id: 'ocean', name: 'Ocean', primary: Color(0xFF006492), primaryContainer: Color(0xFFCAE6FF), secondaryContainer: Color(0xFFD3E4F5), surface: Color(0xFFF8FDFF), surfaceContainer: Color(0xFFEAF2F8)),
  AppTheme(id: 'lemon', name: 'Lemon', primary: Color(0xFF685E0E), primaryContainer: Color(0xFFF1E386), secondaryContainer: Color(0xFFEBE3BE), surface: Color(0xFFFFFBF3), surfaceContainer: Color(0xFFF5F0E4)),
  AppTheme(id: 'oled', name: 'OLED', primary: Color(0xFFBFC2FF), primaryContainer: Color(0xFF2D3A87), secondaryContainer: Color(0xFF434659), surface: Color(0xFF000000), surfaceContainer: Color(0xFF121212)),
];

final currentThemeProvider = StateProvider<AppTheme>((ref) => themes[0]);

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

// --- 3. Main UI Structure ---

class MainScaffold extends ConsumerStatefulWidget {
  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Sage Tools", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
                  CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.account_circle, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: _selectedIndex == 0 ? DashboardView() : SettingsView(),
            ),
          ],
        ),
      ),
      // Animated Bottom Nav
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.grid_view_rounded,
              label: "Dashboard",
              isActive: _selectedIndex == 0,
              onTap: () => setState(() => _selectedIndex = 0),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: "Settings",
              isActive: _selectedIndex == 1,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. Dashboard Tab ---

class DashboardView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(fileSystemProvider);
    final tools = ref.watch(toolsProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Continue Editing (Horizontal Scroll)
        Text("Continue Editing", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (ctx, i) {
              final f = files[i];
              return Container(
                width: 140,
                margin: EdgeInsets.only(right: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.history, size: 18, color: Theme.of(context).colorScheme.primary),
                        Text("RESUME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text("Edited ${f.date}", style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        ),

        SizedBox(height: 24),

        // Tools Grid
        Text("Tools", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: tools.length,
          itemBuilder: (ctx, i) {
            final t = tools[i];
            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context, 
                isScrollControlled: true,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                builder: (c) => ToolSheet(tool: t)
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(t.icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("${t.count}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        )
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        Text("Tap to open", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),

        SizedBox(height: 24),

        // Saved Files
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Saved Files", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text("View All", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: files.length,
          itemBuilder: (ctx, i) {
            final f = files[i];
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(f.icon, size: 20, color: Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Text("${f.size} • ${f.date}", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            );
          },
        )
      ],
    );
  }
}

// --- 5. Settings Tab ---

class SettingsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Card 1: Appearance
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.palette,
                  title: "Theme",
                  subtitle: ref.watch(currentThemeProvider).name,
                  isPrimary: true,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    isScrollControlled: true,
                    builder: (c) => ThemeSelectorSheet()
                  ),
                ),
                Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                _SettingsTile(icon: Icons.language, title: "Language", subtitle: "English (US)"),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 24),
        Text("Data & Storage", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary)).paddingLeft(16),
        SizedBox(height: 8),
        
        // Card 2: Storage
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Column(
              children: [
                _SettingsTile(icon: Icons.folder, title: "Storage Location", subtitle: "/Internal/SageTools"),
                Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                _SettingsTile(icon: Icons.delete, title: "Clear Cache", subtitle: "14 MB"),
              ],
            ),
          ),
        ),

        SizedBox(height: 24),
        Text("About", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary)).paddingLeft(16),
        SizedBox(height: 8),

        // Card 3: About
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: _SettingsTile(icon: Icons.info, title: "Version", subtitle: "7.1.0 (Material You)"),
          ),
        ),
      ],
    );
  }
}

// --- 6. Helper Widgets & Modals ---

class ToolSheet extends StatelessWidget {
  final ToolItem tool;
  ToolSheet({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 24),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(tool.icon, size: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          SizedBox(height: 16),
          Text(tool.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
          SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: tool.items.map((item) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.extension, color: Theme.of(context).colorScheme.primary),
                    SizedBox(height: 8),
                    Text(item, style: TextStyle(fontSize: 12)),
                  ],
                ),
              )).toList(),
            ),
          )
        ],
      ),
    );
  }
}

class ThemeSelectorSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(currentThemeProvider).id;
    return Container(
      height: 400,
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Appearance", style: TextStyle(fontSize: 20)),
          SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: themes.length,
              itemBuilder: (ctx, i) {
                final t = themes[i];
                final isSelected = t.id == currentId;
                return GestureDetector(
                  onTap: () {
                    ref.read(currentThemeProvider.notifier).state = t;
                  },
                  child: Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? t.primary : Colors.grey[300]!,
                        width: isSelected ? 3 : 1
                      ),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))]
                    ),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Container(height: 24, color: t.surfaceContainer),
                            Expanded(child: Container(
                              margin: EdgeInsets.all(8),
                              decoration: BoxDecoration(color: t.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                            ))
                          ],
                        ),
                        if(isSelected) Positioned(
                          right: 8, bottom: 30,
                          child: Icon(Icons.check_circle, color: t.primary),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 4),
                            color: Colors.black.withOpacity(0.05),
                            child: Text(t.name.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 64, height: 32,
            decoration: BoxDecoration(
              color: isActive ? Theme.of(context).colorScheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: isActive ? Theme.of(context).colorScheme.onSecondaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 4),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: isActive ? 16 : 0,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback? onTap;

  _SettingsTile({required this.icon, required this.title, required this.subtitle, this.isPrimary = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 28, color: isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16)),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if(onTap != null) Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant)
          ],
        ),
      ),
    );
  }
}

extension PaddingExt on Widget {
  Widget paddingLeft(double p) => Padding(padding: EdgeInsets.only(left: p), child: this);
}
