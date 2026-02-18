import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Using existing package for "Save As"
import 'package:path_provider/path_provider.dart';
// Note: Add 'archive' to pubspec.yaml for real zipping logic if needed.
// import 'package:archive/archive.dart'; 

class GitGrabberScreen extends StatefulWidget {
  @override
  _GitGrabberScreenState createState() => _GitGrabberScreenState();
}

class _GitGrabberScreenState extends State<GitGrabberScreen> {
  // Logic State
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _zipNameCtrl = TextEditingController(text: "repo.zip");
  
  bool _isLoading = false;
  String _statusMsg = "Ready to explore";
  Color _statusColor = Colors.grey;

  // Repo Data
  String? _owner;
  String? _repo;
  List<String> _branches = [];
  String? _currentBranch;
  List<GitNode> _tree = [];
  
  // UI State
  Set<String> _expandedFolders = {};
  Set<String> _selectedFiles = {};
  Map<String, String> _fileCache = {};

  // --- API LOGIC ---

  Future<void> _fetchRepoInfo() async {
    FocusScope.of(context).unfocus();
    String input = _urlCtrl.text.trim();
    if (input.isEmpty) return;

    // URL Parser
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
      _setStatus("Invalid URL format. Use user/repo", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    _setStatus("Fetching info for $_owner/$_repo...", Colors.blue);

    try {
      final client = HttpClient();
      
      // 1. Get Repo Details
      final req1 = await client.getUrl(Uri.parse("https://api.github.com/repos/$_owner/$_repo"));
      req1.headers.set('User-Agent', 'SageTools');
      final resp1 = await req1.close();
      
      if (resp1.statusCode != 200) throw Exception("Repo not found (Error ${resp1.statusCode})");
      final json1 = jsonDecode(await resp1.transform(utf8.decoder).join());
      String defaultBranch = json1['default_branch'];

      // 2. Get Branches
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

      // 3. Fetch Tree
      await _fetchTree(defaultBranch);

    } catch (e) {
      _setStatus("Error: ${e.toString().replaceAll('Exception:', '')}", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTree(String branch) async {
    _setStatus("Fetching file tree...", Colors.orange);
    setState(() => _isLoading = true);
    
    try {
      final client = HttpClient();
      final url = "https://api.github.com/repos/$_owner/$_repo/git/trees/$branch?recursive=1";
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'SageTools');
      
      final resp = await req.close();
      if (resp.statusCode != 200) throw Exception("Failed to load tree");
      
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      if (json['truncated'] == true) _setStatus("Large repo (truncated)", Colors.orange);

      final List raw = json['tree'];
      
      _tree = raw.map((e) => GitNode(
        path: e['path'],
        type: e['type'] == 'tree' ? NodeType.folder : NodeType.file,
        url: e['url'], 
        size: e['size'],
      )).toList();

      // Sort: Folders first, then files
      _tree.sort((a, b) {
        if (a.type != b.type) return a.type == NodeType.folder ? -1 : 1;
        return a.path.compareTo(b.path);
      });

      setState(() {
        _currentBranch = branch;
        _isLoading = false;
        _expandedFolders.clear();
        _selectedFiles.clear();
      });
      _setStatus("${_tree.length} files loaded", Colors.green);

    } catch (e) {
      _setStatus("Tree Error: $e", Colors.red);
      setState(() => _isLoading = false);
    }
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
      return "Error loading content: $e";
    }
  }

  // --- UI HELPERS ---

  void _setStatus(String msg, Color color) {
    if(mounted) setState(() { _statusMsg = msg; _statusColor = color; });
  }

  void _toggleFolder(String path) {
    setState(() {
      if (_expandedFolders.contains(path)) {
        _expandedFolders.remove(path);
        // Also collapse children? Optional, but cleaner to leave them.
      } else {
        _expandedFolders.add(path);
      }
    });
  }

  // Recursively select all files inside a folder
  void _toggleFolderSelection(String folderPath, bool? val) {
    setState(() {
      // Find all files that start with this folder path
      final children = _tree.where((n) => n.path.startsWith("$folderPath/") && n.type == NodeType.file);
      for (var child in children) {
        if (val == true) _selectedFiles.add(child.path);
        else _selectedFiles.remove(child.path);
      }
    });
  }

  void _toggleFileSelection(String path, bool? val) {
    setState(() {
      if (val == true) _selectedFiles.add(path);
      else _selectedFiles.remove(path);
    });
  }

  void _selectAll(bool select) {
    setState(() {
      if (select) {
        _selectedFiles = _tree.where((n) => n.type == NodeType.file).map((n) => n.path).toSet();
      } else {
        _selectedFiles.clear();
      }
    });
  }

  // --- FIXED VISIBILITY LOGIC ---
  // A node is visible ONLY if ALL its parent folders are expanded
  bool _shouldShow(GitNode node) {
    if (!node.path.contains('/')) return true; // Root item always visible
    
    List<String> parts = node.path.split('/');
    String currentPath = "";
    
    // Check every parent folder in the path
    for (int i = 0; i < parts.length - 1; i++) {
      currentPath += (i == 0) ? parts[i] : "/${parts[i]}";
      if (!_expandedFolders.contains(currentPath)) {
        return false; // If any parent is not expanded, hide this node
      }
    }
    return true;
  }

  // --- SAVE AS LOGIC ---
  Future<void> _saveAs() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No files selected")));
      return;
    }

    _setStatus("Waiting for location...", Colors.blue);
    
    // 1. Pick Directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    
    if (selectedDirectory == null) {
      _setStatus("Save cancelled", Colors.grey);
      return;
    }

    _setStatus("Downloading...", Colors.blue);
    setState(() => _isLoading = true);

    try {
      // 2. Create Destination Folder
      // We create a folder with the ZIP name (minus .zip) to hold the files
      String folderName = _zipNameCtrl.text.replaceAll('.zip', '');
      final saveDir = Directory('$selectedDirectory/$folderName');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);

      // 3. Download & Write Files
      int count = 0;
      for (String path in _selectedFiles) {
        final node = _tree.firstWhere((n) => n.path == path);
        String content = await _fetchContent(node);
        
        // Recreate directory structure locally
        String localPath = "${saveDir.path}/${node.path}";
        File f = File(localPath);
        await f.parent.create(recursive: true); // Create parent dirs
        await f.writeAsString(content);
        count++;
      }

      _setStatus("Saved $count files to ${saveDir.path}", Colors.green);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Success! Saved to ${saveDir.path}"),
        backgroundColor: Colors.green,
      ));

    } catch (e) {
      _setStatus("Save Failed: $e", Colors.red);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        title: Text("Git Grabber", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.surfaceContainer,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.surfaceContainer, border: Border(bottom: BorderSide(color: theme.outlineVariant.withOpacity(0.2)))),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        decoration: InputDecoration(
                          hintText: "user/repo",
                          prefixIcon: Icon(Icons.search),
                          filled: true, fillColor: theme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16)
                        ),
                        onSubmitted: (_) => _fetchRepoInfo(),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _fetchRepoInfo, 
                      icon: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.onPrimary, strokeWidth: 2)) : Icon(Icons.arrow_forward),
                      style: IconButton.styleFrom(backgroundColor: theme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
                    )
                  ],
                ),
                if (_branches.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.fork_right, size: 16, color: theme.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _currentBranch,
                          isExpanded: true,
                          underline: SizedBox(),
                          items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) { if (val != null) _fetchTree(val); },
                        ),
                      ),
                      TextButton(onPressed: () => _selectAll(true), child: Text("All")),
                      TextButton(onPressed: () => _selectAll(false), child: Text("None")),
                    ],
                  )
                ]
              ],
            ),
          ),

          // Status
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _statusColor.withOpacity(0.1),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                SizedBox(width: 8),
                Text(_statusMsg, style: TextStyle(fontSize: 12, color: _statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Tree View
          Expanded(
            child: _tree.isEmpty 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.code, size: 64, color: theme.outlineVariant), SizedBox(height: 16), Text("Enter a repo to start", style: TextStyle(color: theme.onSurfaceVariant))]))
              : ListView.builder(
                  itemCount: _tree.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (ctx, i) {
                    final node = _tree[i];
                    if (!_shouldShow(node)) return SizedBox();
                    return _buildNodeTile(node, theme);
                  },
                ),
          ),

          // SAVE AS BAR (New)
          if (_tree.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surfaceContainer,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))]
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _zipNameCtrl,
                        decoration: InputDecoration(
                          labelText: "Filename",
                          prefixIcon: Icon(Icons.folder_zip, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saveAs,
                      icon: Icon(Icons.save_as),
                      label: Text("Save As"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: theme.onPrimary,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildNodeTile(GitNode node, ColorScheme theme) {
    final int depth = node.path.split('/').length - 1;
    final bool isFolder = node.type == NodeType.folder;
    final bool isExpanded = _expandedFolders.contains(node.path);
    final bool isSelected = _selectedFiles.contains(node.path);

    // Indentation line
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Indent Guides
          for(int k=0; k<depth; k++) 
            Container(width: 1, color: theme.outlineVariant.withOpacity(0.1), margin: EdgeInsets.only(left: 19, right: 0)),
          
          Expanded(
            child: InkWell(
              onTap: () {
                if (isFolder) _toggleFolder(node.path);
                else _toggleFileSelection(node.path, !isSelected);
              },
              child: Container(
                height: 44,
                padding: EdgeInsets.only(left: isFolder ? 8.0 : 8.0), // Reduced base padding
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.outlineVariant.withOpacity(0.05)))),
                child: Row(
                  children: [
                    // Icon
                    Icon(
                      isFolder ? (isExpanded ? Icons.folder_open : Icons.folder) : Icons.insert_drive_file,
                      size: 20, 
                      color: isFolder ? Colors.amber : theme.primary.withOpacity(0.7)
                    ),
                    SizedBox(width: 12),
                    
                    // Name
                    Expanded(child: Text(node.name, style: TextStyle(fontSize: 13, color: theme.onSurface))),
                    
                    // Actions
                    if (isFolder)
                      Checkbox(
                        value: false, // Folders don't hold state perfectly in this flat list without complex logic, so we make them toggle-only triggers
                        tristate: true, // Show dash if partial? Too complex. Let's just make it a "Select All Inside" button
                        onChanged: (v) => _toggleFolderSelection(node.path, true), // Always select all inside
                        shape: CircleBorder(), // Distinguish from file check
                        activeColor: theme.secondary,
                      )
                    else ...[
                      IconButton(
                        icon: Icon(Icons.visibility_outlined, size: 18, color: theme.outline),
                        onPressed: () => _showCodePreview(node),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 8),
                      Checkbox(
                        value: isSelected, 
                        onChanged: (v) => _toggleFileSelection(node.path, v),
                      )
                    ]
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

enum NodeType { file, folder }

class GitNode {
  final String path;
  final NodeType type;
  final String url; 
  final int? size;

  GitNode({required this.path, required this.type, required this.url, this.size});

  String get name => path.split('/').last;
}
