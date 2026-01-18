import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core.dart';
import '../tools/pdf/pdf_crop.dart';

class DashboardView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(fileSystemProvider);
    final tools = ref.watch(toolsProvider);
    final theme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text("Tools", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.onSurfaceVariant)),
        SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
          ),
          itemCount: tools.length,
          itemBuilder: (ctx, i) {
            final t = tools[i];
            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context, isScrollControlled: true,
                backgroundColor: theme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                builder: (c) => ToolSheet(tool: t)
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: theme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                          child: Icon(t.icon, color: theme.onPrimaryContainer),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: theme.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                          child: Text("${t.count}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        )
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        Text("Tap to open", style: TextStyle(fontSize: 12, color: theme.onSurfaceVariant)),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: 24),
        Text("Saved Files", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.onSurfaceVariant)),
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
              decoration: BoxDecoration(color: theme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.secondaryContainer, shape: BoxShape.circle), child: Icon(f.icon, size: 20, color: theme.onSecondaryContainer)),
                  SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text("${f.size} • ${f.date}", style: TextStyle(fontSize: 12, color: theme.onSurfaceVariant)),
                  ])),
                  Icon(Icons.more_vert, color: theme.onSurfaceVariant),
                ],
              ),
            );
          },
        )
      ],
    );
  }
}

class ToolSheet extends StatelessWidget {
  final ToolItem tool;
  ToolSheet({required this.tool});

  Future<void> _handleToolAction(BuildContext context, String action) async {
    if (tool.id == 'pdf' && action == 'Crop') {
      Navigator.pop(context);
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null) {
        Navigator.push(context, MaterialPageRoute(builder: (c) => PdfCropScreen(filePath: result.files.single.path!)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 24),
          Text(tool.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
          SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
              children: tool.items.map((item) => GestureDetector(
                onTap: () => _handleToolAction(context, item),
                child: Container(
                  decoration: BoxDecoration(color: theme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.extension, color: theme.primary),
                      SizedBox(height: 8),
                      Text(item, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          )
        ],
      ),
    );
  }
}
