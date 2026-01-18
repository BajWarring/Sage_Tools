import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Data Models ---
class FileItem {
  final String name;
  final String date;
  final String size;
  final IconData icon;
  final String path;
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

// --- Providers ---
final fileSystemProvider = StateProvider<List<FileItem>>((ref) => [
  FileItem('Invoice_2026.pdf', '2h ago', '1.2MB', Icons.description, ''),
  FileItem('Trip_Vlog.mp4', 'Yesterday', '142MB', Icons.video_file, ''),
  FileItem('Avatar.png', 'Oct 24', '2.8MB', Icons.image, ''),
]);

final toolsProvider = Provider((ref) => [
  ToolItem('pdf', 'PDF Tools', Icons.picture_as_pdf, 6, ['Crop', 'Merge', 'Sign', 'Compress']),
  ToolItem('img', 'Image Editor', Icons.photo_camera, 5, ['Resize', 'Filter', 'Convert', 'Markup']),
  ToolItem('vid', 'Video Studio', Icons.movie, 4, ['Trim', 'Audio', 'Speed', 'Mute']),
  ToolItem('util', 'Utilities', Icons.construction, 8, ['QR Gen', 'Scanner', 'Units', 'Time']),
]);

// --- Theme Engine ---
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
