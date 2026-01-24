import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core.dart';
import '../tools/pdf/pdf_crop.dart';

class DashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final p = theme.primary; // shorthand for primary swatch

    // Logic moved here to ensure 'context' is always valid
    Future<void> _handleToolSelection(String toolId) async {
      if (toolId == 'crop-pdf') {
        // 1. Pick File
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom, 
          allowedExtensions: ['pdf']
        );
        
        // 2. Navigate (Using Dashboard's persistent context)
        if (result != null && result.files.single.path != null) {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (c) => PdfCropScreen(filePath: result.files.single.path!))
          );
        }
      } else {
        // Placeholder for other tools
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tool '$toolId' opening soon..."))
        );
      }
    }

    void _showToolModal(ToolItem tool) async {
      // Wait for the modal to return a Result (ID of the sub-tool)
      final String? selectedId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _ToolModal(tool: tool, ref: ref),
      );

      // If we got an ID back, handle it
      if (selectedId != null) {
        _handleToolSelection(selectedId);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sage Tools", style: TextStyle(color: p[800], fontWeight: FontWeight.bold, fontSize: 24)),
            Text("All-in-one Utility", style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 20),
            width: 36, height: 36,
            decoration: BoxDecoration(color: p[100], shape: BoxShape.circle),
            child: Icon(Icons.person, color: p[600], size: 16),
          )
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // 1. Recent Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("RECENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.0)),
              Text("View All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p[600])),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RecentCard(p, "Invoice_2024.pdf", "2 mins ago", Icons.picture_as_pdf_rounded, Colors.red[50]!, Colors.red[400]!),
                _RecentCard(p, "Design_v2.png", "1 hr ago", Icons.image_rounded, Colors.blue[50]!, Colors.blue[400]!),
                _RecentCard(p, "Voice_Note.mp3", "Yesterday", Icons.audiotrack_rounded, Colors.purple[50]!, Colors.purple[400]!),
              ],
            ),
          ),

          SizedBox(height: 32),

          // 2. Tools Grid
          Text("TOOLS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.0)),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0,
            ),
            itemCount: toolsData.length + 3, // +3 for Coming Soon
            itemBuilder: (ctx, i) {
              if (i < toolsData.length) {
                final tool = toolsData[i];
                return _ToolCard(
                  title: tool.title.split(' ')[0], 
                  icon: tool.icon,
                  color: p,
                  onTap: () => _showToolModal(tool),
                );
              } else {
                return _ComingSoonCard();
              }
            },
          ),

          SizedBox(height: 32),

          // 3. Saved Files
          Text("SAVED FILES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.0)),
          SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
            child: Column(
              children: [
                _FileRow(p, "Downloads", "12 items", Icons.folder_rounded, Colors.amber[50]!, Colors.amber[500]!),
                Divider(height: 1, indent: 60),
                _FileRow(p, "Project_Specs.html", "1.2 MB", Icons.html, p[50]!, p[600]!),
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
    final p = ref.watch(currentThemeProvider).primary;
    
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(tool.icon, color: p[600]),
                SizedBox(width: 12),
                Text(tool.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ]),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: Colors.grey))
            ],
          ),
          Divider(),
          SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5,
            children: tool.items.map((sub) => InkWell(
              onTap: () {
                // FIXED: Just return the ID. Do not try to push routes here.
                Navigator.pop(context, sub.id);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: p[50], shape: BoxShape.circle), child: Icon(sub.icon, size: 16, color: p[600])),
                    SizedBox(width: 12),
                    Text(sub.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
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

// --- Components ---
Widget _RecentCard(MaterialColor p, String title, String sub, IconData icon, Color bg, Color fg) {
  return Container(
    width: 120, margin: EdgeInsets.only(right: 12),
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p[50]!, Colors.white]),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p[100]!),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: p[100], borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: p[600])),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
      ])
    ]),
  );
}

Widget _ToolCard({required String title, required IconData icon, required MaterialColor color, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color[100], shape: BoxShape.circle),
            child: Icon(icon, color: color[600]),
          ),
          SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        ],
      ),
    ),
  );
}

Widget _ComingSoonCard() {
  return Container(
    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle), child: Icon(Icons.add, color: Colors.grey[400])),
      SizedBox(height: 8),
      Text("Soon", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400])),
    ]),
  );
}

Widget _FileRow(MaterialColor p, String title, String sub, IconData icon, Color bg, Color fg) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: fg, size: 20)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[700])),
          Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ])),
        Icon(Icons.chevron_right, size: 16, color: Colors.grey[300]),
      ],
    ),
  );
}
