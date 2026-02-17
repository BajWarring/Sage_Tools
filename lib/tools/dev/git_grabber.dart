import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// Note: Add 'archive' to pubspec.yaml for real zipping.
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
  Map<String, String> _fileCache = {}; // Cache content

  // --- API LOGIC ---

  Future<void> _fetchRepoInfo() async {
    FocusScope.of(context).unfocus();
    String url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    if (!url.contains('github.com')) url = 'https://github.com/$url';
    final uri = Uri.parse(url);
    if (uri.pathSegments.length < 2) {
      _setStatus("Invalid URL", Colors.red);
      return;
    }

    _owner = uri.pathSegments[0];
    _repo = uri.pathSegments[1].replaceAll('.git', '');

    setState(() => _isLoading = true);
    _setStatus("Fetching repo info...", Colors.blue);

    try {
      final client = HttpClient();
      
      // 1. Get Repo Details (Default Branch)
      final req1 = await client.getUrl(Uri.parse("https://api.github.com/repos/$_owner/$_repo"));
      req1.headers.set('User-Agent', 'SageTools');
      final resp1 = await req1.close();
      
      if (resp1.statusCode != 200) throw Exception("Repo private or not found");
      final json1 = jsonDecode(await resp1.transform(utf8.decoder).join());
      String defaultBranch = json1['default_branch'];

      // 2. Get Branches
      final req2 = await client.getUrl(Uri.parse("https://api.github.com/repos/$_owner/$_repo/branches"));
      req2.headers.set('User-Agent', 'SageTools');
      final resp2 = await req2.close();
      final json2 = jsonDecode(await resp2.transform(utf8.decoder).join()) as List;
      
      _branches = json2.map((e) => e['name'].toString()).toList();
      _currentBranch = defaultBranch;
      _zipNameCtrl.text = "$_repo.zip";

      // 3. Fetch Tree
      await _fetchTree(defaultBranch);

    } catch (e) {
      _setStatus("Error: $e", Colors.red);
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
      
      // Process Nodes
      _tree = raw.map((e) => GitNode(
        path: e['path'],
        type: e['type'] == 'tree' ? NodeType.folder : NodeType.file,
        url: e['url'], // Blob URL for content
        size: e['size'],
      )).toList();

      // Sort: Folders top, then files. Alphabetical.
      _tree.sort((a, b) {
        if (a.type != b.type) return a.type == NodeType.folder ? -1 : 1;
        return a.path.compareTo(b.path);
      });

      setState(() {
        _currentBranch = branch;
        _isLoading = false;
        _expandedFolders.clear();
        _selectedFiles.clear();
        // Auto-expand top level folders
        for(var node in _tree) {
           if (node.type == NodeType.folder && !node.path.contains('/')) {
             _expandedFolders.add(node.path);
           }
        }
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
      
      // Content is Base64 encoded
      String raw = json['content'].toString().replaceAll('\n', '');
      String decoded = utf8.decode(base64.decode(raw));
      
      _fileCache[node.path] = decoded;
      return decoded;
    } catch (e) {
      return "Error loading content: $e";
    }
  }

  // --- HELPERS ---

  void _setStatus(String msg, Color color) {
    if(mounted) setState(() { _statusMsg = msg; _statusColor = color; });
  }

  void _toggleFolder(String path) {
    setState(() {
      if (_expandedFolders.contains(path)) {
        _expandedFolders.remove(path);
        // Also collapse subfolders? Optional.
      } else {
        _expandedFolders.add(path);
      }
    });
  }

  void _toggleSelect(String path, bool? val) {
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

  Future<void> _downloadZip() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No files selected")));
      return;
    }
    
    // NOTE: This logic mimics Zipping. 
    // To enable real zipping, uncommment Archive imports and logic.
    
    _setStatus("Preparing download...", Colors.blue);
    setState(() => _isLoading = true);

    try {
      if (Platform.isAndroid) await Permission.storage.request();
      
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/SageGit');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (!await dir.exists()) await dir.create(recursive: true);

      // Simple Save Logic (Saves individual files to a folder instead of ZIP if archive package missing)
      // If you have 'package:archive', create an Archive object here.
      
      int count = 0;
      for (String path in _selectedFiles) {
        final node = _tree.firstWhere((n) => n.path == path);
        String content = await _fetchContent(node);
        
        File f = File('${dir.path}/${node.name}'); 
        await f.writeAsString(content);
        count++;
      }

      _setStatus("Saved $count files to ${dir.path}", Colors.green);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Downloaded to ${dir.path}")));

    } catch (e) {
      _setStatus("Download Failed: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI BUILD ---

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
          // 1. Search Header
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
                          hintText: "user/repo (e.g. flutter/flutter)",
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: theme.surface,
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
                          onChanged: (val) {
                            if (val != null) _fetchTree(val);
                          },
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

          // 2. Status Bar
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

          // 3. Tree View
          Expanded(
            child: _tree.isEmpty 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.code, size: 64, color: theme.outlineVariant), SizedBox(height: 16), Text("Enter a repo to start", style: TextStyle(color: theme.onSurfaceVariant))]))
              : ListView.builder(
                  itemCount: _tree.length,
                  padding: EdgeInsets.only(bottom: 100),
                  itemBuilder: (ctx, i) {
                    final node = _tree[i];
                    // Visibility Logic based on expanded folders
                    if (!_shouldShow(node)) return SizedBox();

                    return _buildNodeTile(node, theme);
                  },
                ),
          ),
        ],
      ),
      
      // 4. Download FAB
      floatingActionButton: _tree.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _downloadZip,
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        icon: Icon(Icons.download),
        label: Text("Download (${_selectedFiles.length})"),
      ) : null,
    );
  }

  // Check if all parent folders are expanded
  bool _shouldShow(GitNode node) {
    if (!node.path.contains('/')) return true; // Root file
    final parentPath = node.path.substring(0, node.path.lastIndexOf('/'));
    // We need to check if the immediate parent is expanded. 
    // And if that parent is visible (its parent is expanded), etc.
    // Simplified: Check if parent path is in _expanded set.
    // Note: This logic assumes if "src" is expanded, "src/lib" is visible.
    // If "src/lib" is NOT expanded, "src/lib/main.dart" should be hidden.
    
    // Check direct parent
    return _expandedFolders.contains(parentPath);
  }

  Widget _buildNodeTile(GitNode node, ColorScheme theme) {
    final int depth = node.path.split('/').length - 1;
    final bool isFolder = node.type == NodeType.folder;
    final bool isExpanded = _expandedFolders.contains(node.path);
    final bool isSelected = _selectedFiles.contains(node.path);

    return InkWell(
      onTap: () {
        if (isFolder) _toggleFolder(node.path);
        else _toggleSelect(node.path, !isSelected);
      },
      child: Container(
        height: 40,
        padding: EdgeInsets.only(left: 16.0 + (depth * 20)),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.outlineVariant.withOpacity(0.1))),
          color: isSelected ? theme.primaryContainer.withOpacity(0.3) : null
        ),
        child: Row(
          children: [
            // Guide Line logic is tricky in flat list without custom painter, 
            // but left padding gives the effect.
            
            // Icon
            if (isFolder) 
              Icon(isExpanded ? Icons.folder_open : Icons.folder, size: 20, color: Colors.amber)
            else 
              Icon(Icons.insert_drive_file, size: 18, color: theme.primary),
            
            SizedBox(width: 12),
            
            // Name
            Expanded(child: Text(node.name, style: TextStyle(fontSize: 13, color: theme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
            
            // Actions
            if (!isFolder) ...[
              IconButton(
                icon: Icon(Icons.visibility, size: 16, color: theme.primary),
                onPressed: () => _showCodePreview(node),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 8),
              Checkbox(
                value: isSelected, 
                onChanged: (v) => _toggleSelect(node.path, v),
                visualDensity: VisualDensity.compact,
              )
            ]
          ],
        ),
      ),
    );
  }
}

enum NodeType { file, folder }

class GitNode {
  final String path;
  final NodeType type;
  final String url; // API URL to fetch content
  final int? size;

  GitNode({required this.path, required this.type, required this.url, this.size});

  String get name => path.split('/').last;
}
