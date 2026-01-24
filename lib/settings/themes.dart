import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core.dart';

class ThemeSettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(currentThemeProvider);
    final currentMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        title: Text("Appearance", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: theme.surface,
      ),
      body: ListView(
        children: [
          // 1. Header Info
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Choose your Style", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.onSurface)),
                SizedBox(height: 8),
                Text("Select a color theme and a brightness mode.", style: TextStyle(color: theme.onSurfaceVariant)),
              ],
            ),
          ),

          // 2. Carousel (The "Mobile Preview" Cards)
          SizedBox(
            height: 340,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: themes.length,
              separatorBuilder: (_, __) => SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final t = themes[i];
                final isSelected = t.id == currentTheme.id;
                
                return GestureDetector(
                  onTap: () => ref.read(currentThemeProvider.notifier).set(t),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 180,
                    decoration: BoxDecoration(
                      color: theme.surfaceContainer,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isSelected ? t.primary : Colors.transparent, 
                        width: 4
                      ),
                      boxShadow: [
                        if (isSelected) BoxShadow(color: t.primary.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          // -- MOCKUP UI --
                          Column(
                            children: [
                              // Mock Header
                              Container(
                                height: 60, 
                                color: t.primary[50], // Lightest shade
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(radius: 10, backgroundColor: t.primary[100], child: Icon(Icons.person, size: 12, color: t.primary)),
                                    SizedBox(width: 8),
                                    Container(width: 60, height: 8, decoration: BoxDecoration(color: t.primary[200], borderRadius: BorderRadius.circular(4)))
                                  ],
                                ),
                              ),
                              // Mock Body
                              Expanded(
                                child: Container(
                                  color: Colors.white,
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 80,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [t.primary[50]!, Colors.white]),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: t.primary[100]!)
                                        ),
                                        padding: EdgeInsets.all(8),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Container(width: 24, height: 24, decoration: BoxDecoration(color: t.primary[100], borderRadius: BorderRadius.circular(8))),
                                          SizedBox(height: 8),
                                          Container(width: 40, height: 6, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                                        ]),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(child: Container(height: 60, decoration: BoxDecoration(color: t.primary[50], borderRadius: BorderRadius.circular(16)))),
                                          SizedBox(width: 8),
                                          Expanded(child: Container(height: 60, decoration: BoxDecoration(color: t.primary[50], borderRadius: BorderRadius.circular(16)))),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              // Mock Label Area
                              Container(
                                height: 40,
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: Text(t.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                              )
                            ],
                          ),
                          
                          // -- Checkmark Overlay --
                          if (isSelected)
                            Positioned(
                              top: 12, right: 12,
                              child: CircleAvatar(
                                backgroundColor: t.primary,
                                radius: 12,
                                child: Icon(Icons.check, size: 16, color: Colors.white),
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 32),

          // 3. Brightness Mode Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Brightness", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primary)),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Row(
                    children: [
                      _ModeButton(
                        label: "System", 
                        icon: Icons.brightness_auto, 
                        isSelected: currentMode == ThemeMode.system,
                        onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.system),
                      ),
                      _ModeButton(
                        label: "Light", 
                        icon: Icons.light_mode, 
                        isSelected: currentMode == ThemeMode.light,
                        onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.light),
                      ),
                      _ModeButton(
                        label: "Dark", 
                        icon: Icons.dark_mode, 
                        isSelected: currentMode == ThemeMode.dark,
                        onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          SizedBox(height: 50),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  _ModeButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : []
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
              SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w600,
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant
              )),
            ],
          ),
        ),
      ),
    );
  }
}
