import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core.dart';
import '../tools/pdf/pdf_crop.dart';

class DashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).colorScheme;
    final sageTheme = ref.watch(currentThemeProvider);
    final p = sageTheme.primary;

    Future<void> _handleToolSelection(String toolId) async {
      if (toolId == 'crop-pdf') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        if (result != null && result.files.single.path != null) {
          Navigator.push(context, MaterialPageRoute(builder: (c) => PdfCropScreen(filePath: result.files.single.path!)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tool '$toolId' opening soon...")));
      }
    }

    void _showToolModal(ToolItem tool) async {
      final String? selectedId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _ToolModal(tool: tool, ref: ref),
      );
      if (selectedId != null) _handleToolSelection(selectedId);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: theme.surfaceContainer, // Dynamic
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sage Tools", style: TextStyle(color: theme.onSurface, fontWeight: FontWeight.bold, fontSize: 24)),
            Text("All-in-one Utility", style: TextStyle(color: theme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 20),
            width: 36, height: 36,
            decoration: BoxDecoration(color: theme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.person, color: theme.onPrimaryContainer, size: 16),
          )
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // 1. Recent
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("RECENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.onSurfaceVariant, letterSpacing: 1.0)),
              Text("View All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.primary)),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RecentCard(context, "Invoice_2024.pdf", "2 mins ago", Icons.picture_as_pdf_rounded, Colors.red),
                _RecentCard(context, "Design_v2.png", "1 hr ago", Icons.image_rounded, Colors.blue),
                _RecentCard(context, "Voice_Note.mp3", "Yesterday", Icons.audiotrack_rounded, Colors.purple),
              ],
            ),
          ),
          SizedBox(height: 32),

          // 2. Tools
          Text("TOOLS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.onSurfaceVariant, letterSpacing: 1.0)),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0),
            itemCount: toolsData.length + 3,
            itemBuilder: (ctx, i) {
              if (i < toolsData.length) {
                return _ToolCard(context, toolsData[i].title.split(' ')[0], toolsData[i].icon, p, () => _showToolModal(toolsData[i]));
              } else {
                return _ComingSoonCard(context);
              }
            },
          ),
          SizedBox(height: 32),

          // 3. Saved
          Text("SAVED FILES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.onSurfaceVariant, letterSpacing: 1.0)),
          SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: theme.surfaceContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.outlineVariant.withOpacity(0.2))),
            child: Column(
              children: [
                _FileRow(context, "Downloads", "12 items", Icons.folder_rounded, Colors.amber),
                Divider(height: 1, indent: 60, color: theme.outlineVariant.withOpacity(0.2)),
                _FileRow(context, "Project_Specs.html", "1.2 MB", Icons.html, p),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolModal extends StatelessWidget {
  final ToolItem tool;
  final WidgetRef ref;
  _ToolModal({required this.tool, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.surfaceContainer, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(tool.icon, color: theme.primary),
                SizedBox(width: 12),
                Text(tool.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.onSurface)),
              ]),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: theme.onSurfaceVariant))
            ],
          ),
          Divider(color: theme.outlineVariant.withOpacity(0.2)),
          SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5,
            children: tool.items.map((sub) => InkWell(
              onTap: () => Navigator.pop(context, sub.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.surface, border: Border.all(color: theme.outlineVariant.withOpacity(0.2)), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: theme.primaryContainer, shape: BoxShape.circle), child: Icon(sub.icon, size: 16, color: theme.onPrimaryContainer)),
                    SizedBox(width: 12),
                    Text(sub.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.onSurface)),
                  ],
                ),
              ),
            )).toList(),
          )
        ],
      ),
    );
  }
}

// --- Components (Dynamic) ---
Widget _RecentCard(BuildContext context, String title, String sub, IconData icon, MaterialColor seed) {
  final t = Theme.of(context).colorScheme;
  // Create a mini-scheme for this card based on the seed color
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: t.brightness);
  
  return Container(
    width: 120, margin: EdgeInsets.only(right: 12),
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.surfaceContainerHighest, scheme.surface]),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: scheme.onPrimaryContainer)),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: t.onSurface)),
        Text(sub, style: TextStyle(fontSize: 10, color: t.onSurfaceVariant)),
      ])
    ]),
  );
}

Widget _ToolCard(BuildContext context, String title, IconData icon, MaterialColor p, VoidCallback onTap) {
  final t = Theme.of(context).colorScheme;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.outlineVariant.withOpacity(0.2))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: t.primaryContainer, shape: BoxShape.circle), child: Icon(icon, color: t.onPrimaryContainer)),
        SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.onSurfaceVariant)),
      ]),
    ),
  );
}

Widget _ComingSoonCard(BuildContext context) {
  final t = Theme.of(context).colorScheme;
  return Container(
    decoration: BoxDecoration(color: t.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: t.outlineVariant.withOpacity(0.1))),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: t.surfaceContainerHighest, shape: BoxShape.circle), child: Icon(Icons.add, color: t.onSurfaceVariant.withOpacity(0.5))),
      SizedBox(height: 8),
      Text("Soon", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.onSurfaceVariant.withOpacity(0.5))),
    ]),
  );
}

Widget _FileRow(BuildContext context, String title, String sub, IconData icon, MaterialColor seed) {
  final t = Theme.of(context).colorScheme;
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: t.brightness);
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: scheme.onPrimaryContainer, size: 20)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: t.onSurface)),
          Text(sub, style: TextStyle(fontSize: 12, color: t.onSurfaceVariant)),
        ])),
        Icon(Icons.chevron_right, size: 16, color: t.onSurfaceVariant),
      ],
    ),
  );
}
