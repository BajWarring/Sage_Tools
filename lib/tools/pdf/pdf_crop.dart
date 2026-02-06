import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart'; // The new engine
import 'package:pdf/pdf.dart' as pw_core; // Standard PDF generator
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfCropScreen extends StatefulWidget {
  final String filePath;
  PdfCropScreen({required this.filePath});

  @override
  _PdfCropScreenState createState() => _PdfCropScreenState();
}

class _PdfCropScreenState extends State<PdfCropScreen> {
  // --- State ---
  bool _isLoading = true;
  PdfController? _pdfController;
  
  // Dimensions
  Size? _imageSize; // The size of the rendered preview on screen
  Size? _pageSize;  // The actual pixel size of the rendered page
  Uint8List? _renderedPageBytes; // The cached image of the page
  
  // Logic
  Rect _cropRect = Rect.zero; 
  bool _isLandscapeRatio = false;
  int _selectedRatioIndex = 0; 
  bool _isRatioLocked = false;
  
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  final List<Map<String, dynamic>> _ratiosPortrait = [
    {'label': 'Free', 'val': null}, {'label': '1:1', 'val': 1.0},
    {'label': '2:3', 'val': 2/3}, {'label': '3:4', 'val': 3/4}, {'label': '9:16', 'val': 9/16},
  ];
  final List<Map<String, dynamic>> _ratiosLandscape = [
    {'label': 'Free', 'val': null}, {'label': '1:1', 'val': 1.0},
    {'label': '3:2', 'val': 3/2}, {'label': '4:3', 'val': 4/3}, {'label': '16:9', 'val': 16/9},
  ];

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      // 1. Initialize Viewer Controller
      _pdfController = PdfController(document: PdfDocument.openFile(widget.filePath));
      
      // 2. Render Page 1 to Image for Crop Calculation
      // We use the renderer directly to get a high-quality "base" image.
      final document = await PdfDocument.openFile(widget.filePath);
      final page = await document.getPage(1);
      
      // Render at a high enough resolution for good quality, but manageable performance
      // Scale 2.0 provides crisp text.
      final rendered = await page.render(
        width: page.width * 2, 
        height: page.height * 2,
        format: PdfPageFormat.png
      );
      
      if (rendered != null) {
        _renderedPageBytes = rendered.bytes;
        _pageSize = Size(rendered.width.toDouble(), rendered.height.toDouble());
        
        // Default UI size (will be scaled down to fit screen in layout)
        // We calculate visual size later in LayoutBuilder
      }
      
      await page.close();
      await document.close();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Init Error: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _resetCropRect(Size viewSize) {
    // Set initial crop to 80% center
    double w = viewSize.width * 0.8;
    double h = viewSize.height * 0.8;
    double x = (viewSize.width - w) / 2;
    double y = (viewSize.height - h) / 2;
    setState(() {
      _imageSize = viewSize;
      _cropRect = Rect.fromLTWH(x, y, w, h);
      _updateControllers();
    });
  }

  void _updateControllers() {
    _xCtrl.text = _cropRect.left.toInt().toString();
    _yCtrl.text = _cropRect.top.toInt().toString();
    _wCtrl.text = _cropRect.width.toInt().toString();
    _hCtrl.text = _cropRect.height.toInt().toString();
  }

  void _onInputChanged() {
    double? x = double.tryParse(_xCtrl.text);
    double? y = double.tryParse(_yCtrl.text);
    double? w = double.tryParse(_wCtrl.text);
    double? h = double.tryParse(_hCtrl.text);
    if (x != null && y != null && w != null && h != null && _imageSize != null) {
      setState(() => _cropRect = Rect.fromLTWH(x, y, w, h));
    }
  }

  void _toggleLockState() {
    setState(() {
      _isRatioLocked = !_isRatioLocked;
      if (!_isRatioLocked) _selectedRatioIndex = 0;
    });
  }

  void _applyRatio(int index) {
    setState(() {
      var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
      double? ratio = list[index]['val'];

      if (ratio == null) {
        _isRatioLocked = false;
        _selectedRatioIndex = 0;
      } else {
        _isRatioLocked = true;
        _selectedRatioIndex = index;
        double currentW = _cropRect.width;
        double newH = currentW / ratio;
        
        if (_cropRect.top + newH > _imageSize!.height) {
           double maxH = _imageSize!.height - _cropRect.top;
           double newW = maxH * ratio;
           _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, maxH);
        } else {
           _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, currentW, newH);
        }
      }
      _updateControllers();
    });
  }

  // --- SAVE LOGIC (WYSIWYG) ---
  Future<void> _savePdf() async {
    if (_renderedPageBytes == null || _imageSize == null) return;
    
    setState(() => _isLoading = true);
    try {
      if (Platform.isAndroid) await Permission.storage.request();

      // 1. Calculate Ratio: Visual Crop -> Actual Image Pixels
      // No rotation math needed. The image is already upright.
      double scaleX = _pageSize!.width / _imageSize!.width;
      double scaleY = _pageSize!.height / _imageSize!.height;

      // The actual pixel region to grab
      double cropX = _cropRect.left * scaleX;
      double cropY = _cropRect.top * scaleY;
      double cropW = _cropRect.width * scaleX;
      double cropH = _cropRect.height * scaleY;

      // 2. Create PDF with correct Page Size
      final pdf = pw.Document();
      
      // Page format matches the CROP dimension exactly
      final pageFormat = pw_core.PdfPageFormat(cropW, cropH, marginAll: 0);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            // 3. Draw the Full Image, Shifted
            // We draw the massive original image, but shifted negatively
            // so that the cropped area aligns with the page's (0,0).
            // The PDF clips everything outside the page format.
            return pw.Stack(
              children: [
                pw.Positioned(
                  left: -cropX, // Shift left to reveal crop
                  top: -cropY,  // Shift up to reveal crop
                  child: pw.Image(
                    pw.MemoryImage(_renderedPageBytes!),
                    width: _pageSize!.width,
                    height: _pageSize!.height,
                    fit: pw.BoxFit.none // Do not scale, render actual pixels
                  ),
                )
              ]
            );
          },
        ),
      );

      // 4. Save
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final saveDir = Directory('${directory!.path}/SageTools');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);

      final fileName = 'Sage_Crop_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${saveDir.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Saved to: ${file.path}"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      print("Save Error: $e");
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- RESIZE LOGIC (HARD STOP) ---
  void _onHandlePan(DragUpdateDetails d, String type, double scale) {
    if (_imageSize == null) return;
    double dx = d.delta.dx / scale;
    double dy = d.delta.dy / scale;
    
    setState(() {
      Rect r = _cropRect;
      double minS = 20.0;
      
      double newL = r.left, newT = r.top, newR = r.right, newB = r.bottom;

      if (type == 'body') {
        double pL = newL + dx, pT = newT + dy;
        double w = r.width, h = r.height;
        if (pL < 0) pL = 0;
        if (pL + w > _imageSize!.width) pL = _imageSize!.width - w;
        if (pT < 0) pT = 0;
        if (pT + h > _imageSize!.height) pT = _imageSize!.height - h;
        _cropRect = Rect.fromLTWH(pL, pT, w, h);
        _updateControllers();
        return; 
      }

      if (type.contains('l')) newL += dx;
      if (type.contains('r')) newR += dx;
      if (type.contains('t')) newT += dy;
      if (type.contains('b')) newB += dy;

      if (_isRatioLocked) {
        var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
        double? ratio = list[_selectedRatioIndex]['val'];
        if (ratio != null) {
           bool drivingW = type.contains('l') || type.contains('r');
           if (drivingW) {
              double propW = newR - newL;
              double reqH = propW / ratio;
              double center = r.top + r.height/2;
              double pT = type.contains('t') ? newB - reqH : (type.contains('b') ? newT : center - reqH/2);
              double pB = type.contains('b') ? newT + reqH : (type.contains('t') ? newT : center + reqH / 2);
              
              if (pT < 0 || pB > _imageSize!.height || newL < 0 || newR > _imageSize!.width) return; // HARD STOP
              newT = pT; newB = pB;
           } else {
              double propH = newB - newT;
              double reqW = propH * ratio;
              double center = r.left + r.width/2;
              double pL = type.contains('l') ? newR - reqW : (type.contains('r') ? newL : center - reqW/2);
              double pR = type.contains('r') ? newL + reqW : (type.contains('l') ? newL : center + reqW/2);
              
              if (pL < 0 || pR > _imageSize!.width || newT < 0 || newB > _imageSize!.height) return; // HARD STOP
              newL = pL; newR = pR;
           }
        }
      }

      if (newR - newL < minS || newB - newT < minS) return;
      if (newL < 0 || newT < 0 || newR > _imageSize!.width || newB > _imageSize!.height) return;

      _cropRect = Rect.fromLTRB(newL, newT, newR, newB);
      _updateControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final ratioList = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
    Color bg = theme.surface;
    Color panelBg = theme.surfaceContainer;
    Color border = theme.outlineVariant.withOpacity(0.2);
    Color text = theme.onSurface;
    Color subText = theme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.chevron_left, color: subText, size: 28), onPressed: () => Navigator.pop(context)),
        title: Text("Crop PDF", style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Container(color: border, height: 1)),
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator()) : Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: panelBg, border: Border(bottom: BorderSide(color: border))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(onPressed: () {}, icon: Icon(Icons.auto_fix_high, size: 16), label: Text("Auto Detect"), style: TextButton.styleFrom(foregroundColor: theme.primary)),
                      OutlinedButton.icon(
                        onPressed: () => setState(() { _isLandscapeRatio = !_isLandscapeRatio; _selectedRatioIndex = 0; _isRatioLocked = false; }),
                        icon: Icon(_isLandscapeRatio ? Icons.crop_landscape : Icons.crop_portrait, size: 16),
                        label: Text(_isLandscapeRatio ? "Landscape" : "Portrait"),
                        style: OutlinedButton.styleFrom(foregroundColor: subText, side: BorderSide(color: border)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ratioList.length,
                      separatorBuilder: (_, __) => SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        bool isSelected = i == _selectedRatioIndex;
                        String label = ratioList[i]['label'];
                        IconData? icon;
                        if (i == 0) { label = ""; icon = _isRatioLocked ? Icons.lock : Icons.lock_open; }
                        return GestureDetector(
                          onTap: () { if (i == 0) _toggleLockState(); else _applyRatio(i); },
                          child: Container(
                            width: i == 0 ? 50 : null,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: isSelected ? theme.primary : panelBg, border: Border.all(color: isSelected ? theme.primary : border), borderRadius: BorderRadius.circular(12)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (icon != null) Icon(icon, size: 16, color: isSelected ? theme.onPrimary : subText), if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? theme.onPrimary : subText))]),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: theme.surfaceContainerHighest,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    if (_renderedPageBytes == null) return Container();
                    
                    // Init logic run once to center crop
                    if (_imageSize == null) {
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                          _resetCropRect(Size(constraints.maxWidth, constraints.maxHeight));
                       });
                       return Center(child: CircularProgressIndicator());
                    }

                    // For the preview, we just show the image filling the area
                    // But we need to maintain aspect ratio of the page itself
                    // Scale Aspect Fit Logic
                    double viewW = constraints.maxWidth;
                    double viewH = constraints.maxHeight;
                    double imgW = _pageSize!.width;
                    double imgH = _pageSize!.height;
                    double scale = min(viewW / imgW, viewH / imgH) * 0.9;
                    double displayW = imgW * scale;
                    double displayH = imgH * scale;
                    double offX = (viewW - displayW) / 2;
                    double offY = (viewH - displayH) / 2;
                    
                    // Update our tracked image size if layout changes
                    // (Actually we need to keep _imageSize consistent with the rendered pixels
                    // so we don't recalc. We just map the touches.)
                    // Wait: _imageSize is the "Screen Size of the Image".
                    // If we resize window, we might need to reset.
                    // For now, let's assume stable layout or simple scaling.
                    
                    // Actually, let's just update _imageSize on the fly? No, controls would jump.
                    // Let's force a fixed aspect view.
                    
                    return Stack(
                      children: [
                        Positioned(
                          left: offX, top: offY, width: displayW, height: displayH,
                          child: Listener( // Use Listener to grab size for first time setup if needed
                            onPointerDown: (_) {
                               if (_imageSize == null || _imageSize!.width != displayW) {
                                  _imageSize = Size(displayW, displayH);
                               }
                            },
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(color: panelBg, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                                  child: Image.memory(_renderedPageBytes!, fit: BoxFit.contain, width: displayW, height: displayH)
                                ),
                                Positioned(top: 0, left: 0, right: 0, height: _cropRect.top, child: ColoredBox(color: Colors.black54)),
                                Positioned(bottom: 0, left: 0, right: 0, top: _cropRect.bottom, child: ColoredBox(color: Colors.black54)),
                                Positioned(top: _cropRect.top, bottom: displayH - _cropRect.bottom, left: 0, width: _cropRect.left, child: ColoredBox(color: Colors.black54)),
                                Positioned(top: _cropRect.top, bottom: displayH - _cropRect.bottom, right: 0, left: _cropRect.right, child: ColoredBox(color: Colors.black54)),
                                Positioned(
                                  left: _cropRect.left, top: _cropRect.top, width: _cropRect.width, height: _cropRect.height,
                                  child: GestureDetector(
                                    onPanUpdate: (d) => _onHandlePan(d, 'body', 1.0), // Scale 1.0 because we are in local coords
                                    child: Container(
                                      decoration: BoxDecoration(border: Border.all(color: theme.primary, width: 2)),
                                      child: Stack(
                                        children: [
                                          Column(children: [Spacer(), Divider(color: Colors.white30, height: 1), Spacer(), Divider(color: Colors.white30, height: 1), Spacer()]),
                                          Row(children: [Spacer(), VerticalDivider(color: Colors.white30, width: 1), Spacer(), VerticalDivider(color: Colors.white30, width: 1), Spacer()]),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                ..._buildHandles(1.0, theme.primary),
                              ],
                            ),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -4))]),
              child: Column(
                children: [
                  Row(children: [_buildInput('X', _xCtrl, theme), SizedBox(width: 12), _buildInput('Y', _yCtrl, theme), SizedBox(width: 12), _buildInput('W', _wCtrl, theme), SizedBox(width: 12), _buildInput('H', _hCtrl, theme)]),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _savePdf,
                      icon: Icon(Icons.download_rounded, size: 20),
                      label: Text("Export PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: theme.onPrimary, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
    );
  }

  List<Widget> _buildHandles(double scale, Color color) {
    // scale is passed as 1.0 because we are drawing directly on the sized box
    double L = _cropRect.left; double T = _cropRect.top;
    double R = _cropRect.right; double B = _cropRect.bottom;
    double cX = L + (_cropRect.width / 2); double cY = T + (_cropRect.height / 2);
    double size = 30.0; double dot = 12.0;
    Widget handle(double x, double y, String type) {
      return Positioned(
        left: x - (size / 2), top: y - (size / 2), width: size, height: size,
        child: GestureDetector(
          onPanUpdate: (d) => _onHandlePan(d, type, scale),
          child: Container(alignment: Alignment.center, color: Colors.transparent, child: Container(width: dot, height: dot, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
        ),
      );
    }
    return [handle(L, T, 'tl'), handle(cX, T, 't'), handle(R, T, 'tr'), handle(L, cY, 'l'), handle(R, cY, 'r'), handle(L, B, 'bl'), handle(cX, B, 'b'), handle(R, B, 'br')];
  }

  Widget _buildInput(String label, TextEditingController ctrl, ColorScheme theme) {
    return Expanded(child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: theme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.outlineVariant.withOpacity(0.2))), child: Column(children: [Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.onSurfaceVariant)), TextField(controller: ctrl, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.onSurface), decoration: InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero), keyboardType: TextInputType.number, onSubmitted: (_) => _onInputChanged())])));
  }
}
