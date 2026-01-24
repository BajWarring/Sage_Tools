import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- 1. Data Models ---

class SageTheme {
  final String id;
  final String name;
  final MaterialColor primary;
  final Color background;
  final Color surface;
  
  SageTheme({
    required this.id, 
    required this.name, 
    required this.primary,
    this.background = const Color(0xFFF4F4F5), // Default Zinc-50
    this.surface = Colors.white,
  });
}

// --- 2. Color Swatches ---

final sageSwatch = MaterialColor(0xFF4E924E, {
  50: Color(0xFFF4F9F4), 100: Color(0xFFE3F2E3), 200: Color(0xFFC5E2C5),
  300: Color(0xFF9CCB9C), 400: Color(0xFF72AF72), 500: Color(0xFF4E924E),
  600: Color(0xFF3A753A), 700: Color(0xFF2F5D2F), 800: Color(0xFF274A27),
  900: Color(0xFF213D21),
});

final oceanSwatch = MaterialColor(0xFF3B82F6, {
  50: Color(0xFFEFF6FF), 100: Color(0xFFDBEAFE), 200: Color(0xFFBFDBFE),
  300: Color(0xFF93C5FD), 400: Color(0xFF60A5FA), 500: Color(0xFF3B82F6),
  600: Color(0xFF2563EB), 700: Color(0xFF1D4ED8), 800: Color(0xFF1E40AF),
  900: Color(0xFF1E3A8A),
});

final royalSwatch = MaterialColor(0xFFA855F7, {
  50: Color(0xFFFAF5FF), 100: Color(0xFFF3E8FF), 200: Color(0xFFE9D5FF),
  300: Color(0xFFD8B4FE), 400: Color(0xFFC084FC), 500: Color(0xFFA855F7),
  600: Color(0xFF9333EA), 700: Color(0xFF7E22CE), 800: Color(0xFF6B21A8),
  900: Color(0xFF581C87),
});

final sunsetSwatch = MaterialColor(0xFFF97316, {
  50: Color(0xFFFFF7ED), 100: Color(0xFFFFEDD5), 200: Color(0xFFFED7AA),
  300: Color(0xFFFDBA74), 400: Color(0xFFFB923C), 500: Color(0xFFF97316),
  600: Color(0xFFEA580C), 700: Color(0xFFC2410C), 800: Color(0xFF9A3412),
  900: Color(0xFF7C2D12),
});

final monochromeSwatch = MaterialColor(0xFF525252, {
  50: Color(0xFFFAFAFA), 100: Color(0xFFF5F5F5), 200: Color(0xFFEEEEEE),
  300: Color(0xFFE0E0E0), 400: Color(0xFFBDBDBD), 500: Color(0xFF9E9E9E),
  600: Color(0xFF757575), 700: Color(0xFF616161), 800: Color(0xFF424242),
  900: Color(0xFF212121),
});

final themes = [
  SageTheme(id: 'sage', name: 'Sage Green', primary: sageSwatch),
  SageTheme(id: 'ocean', name: 'Ocean Blue', primary: oceanSwatch),
  SageTheme(id: 'royal', name: 'Royal Purple', primary: royalSwatch),
  SageTheme(id: 'sunset', name: 'Sunset Orange', primary: sunsetSwatch),
  SageTheme(id: 'mono', name: 'Monochrome', primary: monochromeSwatch),
];

// --- 3. Providers ---

// Color Theme Provider
final currentThemeProvider = StateNotifierProvider<ThemeNotifier, SageTheme>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<SageTheme> {
  ThemeNotifier() : super(themes[0]) {
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('theme_id') ?? 'sage';
    state = themes.firstWhere((t) => t.id == id, orElse: () => themes[0]);
  }

  void set(SageTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_id', theme.id);
  }
}

// Theme Mode Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode') ?? 'system';
    state = _parse(mode);
  }

  void set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', mode.toString().split('.').last);
  }

  ThemeMode _parse(String val) {
    if (val == 'light') return ThemeMode.light;
    if (val == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }
}

final storagePathProvider = StateProvider<String>((ref) => '/storage/emulated/0/SageTools');

// --- 4. Tool Data ---

class ToolItem {
  final String id;
  final String title;
  final IconData icon;
  final List<SubTool> items;
  ToolItem(this.id, this.title, this.icon, this.items);
}

class SubTool {
  final String name;
  final IconData icon;
  final String id;
  SubTool(this.name, this.icon, [this.id = '']);
}

final toolsData = [
  ToolItem('pdf', 'PDF Tools', Icons.picture_as_pdf_rounded, [
    SubTool('Crop PDF', Icons.crop, 'crop-pdf'),
    SubTool('Merge PDF', Icons.layers),
    SubTool('Split PDF', Icons.content_cut),
    SubTool('Compress', Icons.compress),
    SubTool('PDF to Image', Icons.image),
    SubTool('Sign PDF', Icons.draw),
  ]),
  ToolItem('image', 'Image Tools', Icons.image_rounded, [
    SubTool('Resize', Icons.aspect_ratio),
    SubTool('Crop', Icons.crop),
    SubTool('Compress', Icons.compress),
    SubTool('Remove BG', Icons.auto_fix_high),
  ]),
  ToolItem('video', 'Video Tools', Icons.videocam_rounded, [
    SubTool('Trim Video', Icons.content_cut),
    SubTool('Extract Audio', Icons.audiotrack),
    SubTool('GIF Maker', Icons.gif),
  ]),
  ToolItem('audio', 'Audio Tools', Icons.headphones_rounded, [
    SubTool('Convert MP3', Icons.sync_alt),
    SubTool('Cutter', Icons.content_cut),
    SubTool('Volume Boost', Icons.volume_up),
  ]),
];
