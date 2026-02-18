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
  List<GitNode> _fullFlatTree = []; 
  List<GitNode> _visibleTree = [];  
  
  // Interaction State
  Set<String> _expandedFolders = {}; 
  Set<String> _selectedFiles = {};   
  Map<String, String> _fileCache = {}; 

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
      final req1 = await client.getUrl(Uri.parse("https://api.github.com/repos/$_owner/$_repo"));
      req1.headers.set('User-Agent', 'SageTools');
      final resp1 = await req1.close();
      
      if (resp1.statusCode != 200) throw Exception("Repo not found");
      final json1 = jsonDecode(await resp1.transform(utf8.decoder).join());
      String defaultBranch = json1['default_branch'];

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

      // Build Map Hierarchy
      Map<String, _TempNode> nodeMap = {};
      _TempNode root = _TempNode(path: "", type: "tree", name: "root", children: []);
      nodeMap[""] = root; 

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

      for (var path in nodeMap.keys) {
        if (path == "") continue;
        final node = nodeMap[path]!;
        String parentPath = "";
        if (path.contains('/')) {
          parentPath = path.substring(0, path.lastIndexOf('/'));
        }
        if (nodeMap.containsKey(parentPath)) {
          nodeMap[parentPath]!.children.add(node);
        }
      }

      List<GitNode> flatResult = [];
      void flatten(_TempNode parent, int depth) {
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
          
          if (child.type == "tree") {
            flatten(child, depth + 1);
          }
        }
      }

      flatten(root, 0);

      setState(() {
        _currentBranch = branch;
        _fullFlatTree = flatResult;
        _expandedFolders.clear(); // Ensure all closed at start
        _selectedFiles.clear();
        _recalcVisible();
        _isLoading = false;
      });
      _setStatus("${flatResult.length} items loaded", Colors.green);

    } catch (e) {
      _setStatus("Tree Error: $e", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // --- 2. VISIBILITY & SELECTION ---

  void _recalcVisible() {
    _visibleTree = _fullFlatTree.where((node) {
      if (node.depth == 0) return true;
      String parentPath = node.path.substring(0, node.path.lastIndexOf('/'));
      if (!_expandedFolders.contains(parentPath)) return false;
      return true;
    }).toList();
  }

  void _toggleFolder(String path) {
    setState(() {
      if (_expandedFolders.contains(path)) {
        _expandedFolders.remove(path);
      } else {
        _expandedFolders.add(path);
      }
      _recalcVisible();
    });
  }

  // Select/Deselect all files inside a folder
  void _toggleFolderSelect(String folderPath, bool? select) {
    setState(() {
      final children = _fullFlatTree.where((n) => n.path.startsWith("$folderPath/") && n.type == NodeType.file);
      for (var child in children) {
        if (select == true) _selectedFiles.add(child.path);
        else _selectedFiles.remove(child.path);
      }
    });
  }

  // Determine state of folder checkbox (True=All, Null=Some, False=None)
  bool? _getFolderState(String folderPath) {
    final children = _fullFlatTree.where((n) => n.path.startsWith("$folderPath/") && n.type == NodeType.file).toList();
    if (children.isEmpty) return false;
    
    int selectedCount = children.where((n) => _selectedFiles.contains(n.path)).length;
    
    if (selectedCount == 0) return false;
    if (selectedCount == children.length) return true;
    return null; // Tristate (dash)
  }

  // --- 3. DOWNLOAD & SAVE ---

  Future<void> _saveAs() async {
    if (_selectedFiles.isEmpty) {
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

      for (String path in _selectedFiles) {
        final node = _fullFlatTree.firstWhere((n) => n.path == path);
        final req = await client.getUrl(Uri.parse(node.url));
        req.headers.set('User-Agent', 'SageTools');
        final resp = await req.close();
        final json = jsonDecode(await resp.transform(utf8.decoder).join());
        String raw = json['content'].toString().replaceAll('\n', '');
        String content = utf8.decode(base64.decode(raw));

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

  void _showCodePreview(GitNode node) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        child: Container(
          padding: EdgeInsets.all(16),
          height: 500,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(node.name, style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close))
                ],
              ),
              Divider(),
              Expanded(
                child: FutureBuilder<String>(
                  future: _fetchContent(node),
                  builder: (context, snap) {
                    if (!snap.hasData) return Center(child: CircularProgressIndicator());
                    return SingleChildScrollView(
                      child: SelectableText(
                        snap.data!, 
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  Future<String> _fetchContent(GitNode node) async {
    if (_fileCache.containsKey(node.path)) return _fileCache[node.path]!;
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(node.url));
      req.headers.set('User-Agent', 'SageTools');
      final resp = await req.close();
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      String raw = json['content'].toString().replaceAll('\n', '');
      String decoded = utf8.decode(base64.decode(raw));
      _fileCache[node.path] = decoded;
      return decoded;
    } catch (e) {
      return "Error: $e";
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
                  TextButton(onPressed: () => setState(() => _selectedFiles = _fullFlatTree.where((n) => n.type == NodeType.file).map((n) => n.path).toSet()), child: Text("All")),
                  TextButton(onPressed: () => setState(() => _selectedFiles.clear()), child: Text("None")),
                ])
              ]
            ]),
          ),
          
          Container(width: double.infinity, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), color: _statusColor.withOpacity(0.1), child: Text(_statusMsg, style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.bold))),

          Expanded(
            child: _visibleTree.isEmpty 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.code, size: 64, color: theme.outlineVariant), SizedBox(height: 16), Text("No files to display", style: TextStyle(color: theme.onSurfaceVariant))]))
              : ListView.builder(
                  itemCount: _visibleTree.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (ctx, i) => _buildNodeTile(_visibleTree[i], theme),
                ),
          ),

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
    
    // Checkbox State
    bool? checkboxState;
    if (isFolder) {
      checkboxState = _getFolderState(node.path);
    } else {
      checkboxState = _selectedFiles.contains(node.path);
    }

    double indent = 16.0 + (node.depth * 24.0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for(int k=0; k<node.depth; k++) 
            Container(width: 1, color: theme.outlineVariant.withOpacity(0.1), margin: EdgeInsets.only(left: 19, right: 0)),
          
          Expanded(
            child: InkWell(
              onTap: () {
                if (isFolder) _toggleFolder(node.path);
                else setState(() { if(checkboxState == true) _selectedFiles.remove(node.path); else _selectedFiles.add(node.path); });
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.outlineVariant.withOpacity(0.05))), color: (checkboxState == true) ? theme.primaryContainer.withOpacity(0.1) : null),
                child: Row(
                  children: [
                    // 1. CHECKBOX (Left Side)
                    Checkbox(
                      value: checkboxState, 
                      tristate: isFolder,
                      onChanged: (v) {
                        if (isFolder) _toggleFolderSelect(node.path, v != false); 
                        else setState(() { if(v == true) _selectedFiles.add(node.path); else _selectedFiles.remove(node.path); });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    
                    // 2. ICON
                    Icon(
                      isFolder ? (isExpanded ? Icons.folder_open : Icons.folder) : Icons.insert_drive_file,
                      size: 20, 
                      color: isFolder ? Colors.amber : theme.primary.withOpacity(0.8)
                    ),
                    SizedBox(width: 12),
                    
                    // 3. NAME
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
                    
                    // 4. PREVIEW BUTTON (Right Side, for Files)
                    if (!isFolder)
                      IconButton(
                        icon: Icon(Icons.visibility_outlined, size: 18, color: theme.outline),
                        onPressed: () => _showCodePreview(node),
                        tooltip: "Preview Code",
                      ),
                    SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
