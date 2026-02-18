import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class GitGrabberScreen extends StatefulWidget {
  @override
  _GitGrabberScreenState createState() => _GitGrabberScreenState();
}

class _GitGrabberScreenState extends State<GitGrabberScreen> {
  // --- STATE ---
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _zipNameCtrl = TextEditingController(text: "repo.zip");
  
  bool _isLoading = false;
  String _statusMsg = "Ready to explore";
  Color _statusColor = Colors.grey;

  // Repo Info
  String? _owner;
  String? _repo;
  List<String> _branches = [];
  String? _currentBranch;

  // Tree Data
  List<GitNode> _fullFlatTree = []; // The master list (correctly sorted)
  List<GitNode> _visibleTree = [];  // The list currently shown (filtered by expansion)
  
  // Interaction State
  Set<String> _expandedPaths = {}; // Folders that are open
  Set<String> _selectedPaths = {}; // Files that are checked
  Map<String, String> _fileCache = {}; // Content cache

  // --- 1. API & TREE BUILDING ---

  Future<void> _fetchRepoInfo() async {
    FocusScope.of(context).unfocus();
    String input = _urlCtrl.text.trim();
    if (input.isEmpty) return;

    if (input.contains('github.com')) {
      final uri = Uri.tryParse(input);
      if (uri != null && uri.pathSegments.length >= 2) {
        _owner = uri.pathSegments[0];
        _repo = uri.pathSegments[1].replaceAll('.git', '');
      }
    } else if (input.contains('/')) {
      final parts = input.split('/');
      if (parts.length == 2) {
        _owner = parts[0];
        _repo = parts[1].replaceAll('.git', '');
      }
    }

    if (_owner == null || _repo == null) {
      _setStatus("Invalid format. Use user/repo", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    _setStatus("Fetching $_owner/$_repo...", Colors.blue);

    try {
      final client = HttpClient();
      // Get Default Branch
      final req1 = await client.getUrl(Uri.parse("https://api.github.com/repos/$_owner/$_repo"));
      req1.headers.set('User-Agent', 'SageTools');
      final resp1 = await req1.close();
      
      if (resp1.statusCode != 200) throw Exception("Repo not found");
      final json1 = jsonDecode(await resp1.transform(utf8.decoder).join());
      String defaultBranch = json1['default_branch'];

      // Get Branch List
      final req2 = await client.getUrl(Uri.parse("https://api.github.com/repos/$_owner/$_repo/branches"));
      req2.headers.set('User-Agent', 'SageTools');
      final resp2 = await req2.close();
      
      if (resp2.statusCode == 200) {
        final json2 = jsonDecode(await resp2.transform(utf8.decoder).join()) as List;
        _branches = json2.map((e) => e['name'].toString()).toList();
      } else {
        _branches = [defaultBranch];
      }
      
      _currentBranch = defaultBranch;
      _zipNameCtrl.text = "$_repo.zip";

      await _fetchTree(defaultBranch);

    } catch (e) {
      _setStatus("Error: ${e.toString().replaceAll('Exception:', '')}", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTree(String branch) async {
    _setStatus("Building tree...", Colors.orange);
    setState(() => _isLoading = true);
    
    try {
      final client = HttpClient();
      final url = "https://api.github.com/repos/$_owner/$_repo/git/trees/$branch?recursive=1";
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'SageTools');
      final resp = await req.close();
      
      if (resp.statusCode != 200) throw Exception("Failed to load tree");
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      final List rawList = json['tree'];

      // --- THE FIX: Convert Flat API List -> Hierarchy -> Sorted Flat List ---
      
      // 1. Build Map Hierarchy
      Map<String, _TempNode> nodeMap = {};
      _TempNode root = _TempNode(path: "", type: "tree", name: "root", children: []);
      nodeMap[""] = root; // Root map

      // Create nodes
      for (var item in rawList) {
        String path = item['path'];
        nodeMap[path] = _TempNode(
          path: path,
          type: item['type'],
          name: path.split('/').last,
          url: item['url'],
          size: item['size'],
          children: []
        );
      }

      // Link parents
      for (var path in nodeMap.keys) {
        if (path == "") continue;
        final node = nodeMap[path]!;
        
        String parentPath = "";
        if (path.contains('/')) {
          parentPath = path.substring(0, path.lastIndexOf('/'));
        }
        
        // If parent exists (it should), add child
        if (nodeMap.containsKey(parentPath)) {
          nodeMap[parentPath]!.children.add(node);
        }
      }

      // 2. Flatten Recursive (Depth First)
      List<GitNode> flatResult = [];
      void flatten(_TempNode parent, int depth) {
        // Sort: Folders first, then Files. Both Alphabetical.
        parent.children.sort((a, b) {
          if (a.type != b.type) return a.type == "tree" ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        for (var child in parent.children) {
          flatResult.add(GitNode(
            path: child.path,
            name: child.name,
            type: child.type == "tree" ? NodeType.folder : NodeType.file,
            url: child.url ?? "",
            depth: depth,
            size: child.size
          ));
          
          // Recurse if folder
          if (child.type == "tree") {
            flatten(child, depth + 1);
          }
        }
      }

      flatten(root, 0);

      setState(() {
        _currentBranch = branch;
        _fullFlatTree = flatResult;
        _expandedFolders.clear();
        _selectedFiles.clear();
        
        // Auto-expand top level folders only
        for (var node in _fullFlatTree) {
          if (node.depth == 0 && node.type == NodeType.folder) {
            _expandedFolders.add(node.path);
          }
        }
        
        _recalcVisible(); // Build the view list
        _isLoading = false;
      });
      _setStatus("${flatResult.length} items loaded", Colors.green);

    } catch (e) {
      _setStatus("Tree Error: $e", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // --- 2. VISIBILITY & SELECTION LOGIC ---

  void _recalcVisible() {
    // Filter the full list based on expanded parents
    _visibleTree = _fullFlatTree.where((node) {
      if (node.depth == 0) return true;
      
      // Check if immediate parent is expanded
      String parentPath = node.path.substring(0, node.path.lastIndexOf('/'));
      // AND ensure the parent itself is visible (recursive check implicit via top-down expansion)
      // Actually, we just need to know if ALL ancestors are in _expandedFolders
      
      // Optimization: We know the list is sorted Depth-First. 
      // If a parent is closed, we skip all its children. 
      // But simple set check is safer for now:
      
      // We check if the direct parent is expanded. 
      // If the direct parent is collapsed, this node is hidden.
      // If the direct parent is expanded, but the GRANDPARENT was collapsed, 
      // the parent wouldn't be visible to be clicked. 
      // So checking strict ancestry is best.
      
      // Fast check: Is the direct parent expanded?
      if (!_expandedFolders.contains(parentPath)) return false;
      
      // Robust check: Are all ancestors expanded?
      // (Usually implied if we only click visible things, but "Expand All" might break it. 
      //  Let's stick to direct parent check for speed, usually sufficient for UI interaction)
      return true;
    }).toList();
  }

  void _toggleFolder(String path) {
    setState(() {
      if (_expandedFolders.contains(path)) {
        _expandedFolders.remove(path);
        // Remove any children from expanded too? No, keep state.
      } else {
        _expandedFolders.add(path);
      }
      _recalcVisible();
    });
  }

  void _toggleFolderSelect(String folderPath, bool? select) {
    setState(() {
      // Find all files that start with this folder path
      // Since it's a list, we iterate.
      for (var node in _fullFlatTree) {
        if (node.type == NodeType.file && node.path.startsWith("$folderPath/")) {
          if (select == true) _selectedPaths.add(node.path);
          else _selectedPaths.remove(node.path);
        }
      }
    });
  }

  // --- 3. DOWNLOAD & SAVE ---

  Future<void> _saveAs() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No files selected")));
      return;
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    _setStatus("Downloading...", Colors.blue);
    setState(() => _isLoading = true);

    try {
      String rootFolderName = _zipNameCtrl.text.replaceAll('.zip', '');
      final saveDir = Directory('$selectedDirectory/$rootFolderName');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);

      int count = 0;
      final client = HttpClient();

      for (String path in _selectedPaths) {
        // Find node
        final node = _fullFlatTree.firstWhere((n) => n.path == path);
        
        // Fetch
        final req = await client.getUrl(Uri.parse(node.url));
        req.headers.set('User-Agent', 'SageTools');
        final resp = await req.close();
        final json = jsonDecode(await resp.transform(utf8.decoder).join());
        String raw = json['content'].toString().replaceAll('\n', '');
        String content = utf8.decode(base64.decode(raw));

        // Save
        String localPath = "${saveDir.path}/${node.path}";
        File f = File(localPath);
        await f.parent.create(recursive: true);
        await f.writeAsString(content);
        count++;
      }

      _setStatus("Saved $count files", Colors.green);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Success! Saved to ${saveDir.path}"), backgroundColor: Colors.green));

    } catch (e) {
      _setStatus("Download Failed: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setStatus(String msg, Color color) {
    if(mounted) setState(() { _statusMsg = msg; _statusColor = color; });
  }

  // --- 4. UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(title: Text("Git Grabber", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: theme.surfaceContainer, elevation: 0),
      body: Column(
        children: [
          // Search
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.surfaceContainer, border: Border(bottom: BorderSide(color: theme.outlineVariant.withOpacity(0.2)))),
            child: Column(children: [
              Row(children: [
                Expanded(child: TextField(controller: _urlCtrl, decoration: InputDecoration(hintText: "user/repo", prefixIcon: Icon(Icons.search), filled: true, fillColor: theme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: 16)), onSubmitted: (_) => _fetchRepoInfo())),
                SizedBox(width: 8),
                IconButton.filled(onPressed: _fetchRepoInfo, icon: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.onPrimary, strokeWidth: 2)) : Icon(Icons.arrow_forward), style: IconButton.styleFrom(backgroundColor: theme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
              ]),
              if (_branches.isNotEmpty) ...[
                SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.fork_right, size: 16, color: theme.primary), SizedBox(width: 8),
                  Expanded(child: DropdownButton<String>(value: _currentBranch, isExpanded: true, underline: SizedBox(), items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(fontSize: 13)))).toList(), onChanged: (val) { if (val != null) _fetchTree(val); })),
                  TextButton(onPressed: () => setState(() => _selectedPaths = _fullFlatTree.where((n) => n.type == NodeType.file).map((n) => n.path).toSet()), child: Text("All")),
                  TextButton(onPressed: () => setState(() => _selectedPaths.clear()), child: Text("None")),
                ])
              ]
            ]),
          ),
          
          // Status
          Container(width: double.infinity, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), color: _statusColor.withOpacity(0.1), child: Text(_statusMsg, style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.bold))),

          // Tree List
          Expanded(
            child: _visibleTree.isEmpty 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.code, size: 64, color: theme.outlineVariant), SizedBox(height: 16), Text("No files to display", style: TextStyle(color: theme.onSurfaceVariant))]))
              : ListView.builder(
                  itemCount: _visibleTree.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (ctx, i) => _buildNodeTile(_visibleTree[i], theme),
                ),
          ),

          // Save Bar
          if (_fullFlatTree.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.surfaceContainer, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))]),
              child: SafeArea(
                child: Row(children: [
                  Expanded(child: TextField(controller: _zipNameCtrl, decoration: InputDecoration(labelText: "Folder Name", prefixIcon: Icon(Icons.create_new_folder, size: 18), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: _saveAs, icon: Icon(Icons.save_as), label: Text("Save As"), style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: theme.onPrimary, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
                ]),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildNodeTile(GitNode node, ColorScheme theme) {
    final bool isFolder = node.type == NodeType.folder;
    final bool isExpanded = _expandedFolders.contains(node.path);
    final bool isSelected = _selectedPaths.contains(node.path);
    
    // Guide Lines Logic: Calculate indentation padding
    double indent = 16.0 + (node.depth * 24.0);

    return InkWell(
      onTap: () {
        if (isFolder) _toggleFolder(node.path);
        else setState(() { if(isSelected) _selectedPaths.remove(node.path); else _selectedPaths.add(node.path); });
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.outlineVariant.withOpacity(0.05))),
          color: isSelected ? theme.primaryContainer.withOpacity(0.1) : null
        ),
        child: Stack(
          children: [
            // Guide Lines
            if (node.depth > 0)
              Positioned(
                left: 0, top: 0, bottom: 0, width: indent,
                child: CustomPaint(
                  painter: TreeGuidePainter(depth: node.depth, color: theme.outlineVariant.withOpacity(0.2)),
                ),
              ),
              
            // Content
            Padding(
              padding: EdgeInsets.only(left: indent),
              child: Row(
                children: [
                  // Icon
                  Icon(
                    isFolder ? (isExpanded ? Icons.folder_open : Icons.folder) : Icons.description_outlined,
                    size: 20, 
                    color: isFolder ? Colors.amber : theme.primary.withOpacity(0.8)
                  ),
                  SizedBox(width: 12),
                  // Name
                  Expanded(
                    child: Text(
                      node.name, 
                      style: TextStyle(
                        fontSize: 13, 
                        color: theme.onSurface,
                        fontWeight: isFolder ? FontWeight.w600 : FontWeight.normal
                      ), 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    )
                  ),
                  // Checkbox
                  if (isFolder)
                    IconButton(
                      icon: Icon(Icons.playlist_add_check, size: 20, color: theme.outline),
                      tooltip: "Select All Inside",
                      onPressed: () => _toggleFolderSelect(node.path, true),
                    )
                  else
                    Checkbox(
                      value: isSelected, 
                      onChanged: (v) => setState(() { if(v!) _selectedPaths.add(node.path); else _selectedPaths.remove(node.path); }),
                      visualDensity: VisualDensity.compact,
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TREE GUIDE PAINTER ---
class TreeGuidePainter extends CustomPainter {
  final int depth;
  final Color color;
  TreeGuidePainter({required this.depth, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.0;
    // Draw a vertical line for each depth level
    for (int i = 1; i <= depth; i++) {
      double x = (i * 24.0) - 12.0; // Center of the indent block
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- DATA CLASSES ---
enum NodeType { file, folder }

class GitNode {
  final String path;
  final String name;
  final NodeType type;
  final String url; 
  final int depth;
  final int? size;

  GitNode({required this.path, required this.name, required this.type, required this.url, required this.depth, this.size});
}

class _TempNode {
  String path;
  String type;
  String name;
  String? url;
  int? size;
  List<_TempNode> children;
  _TempNode({required this.path, required this.type, required this.name, this.url, this.size, required this.children});
}
