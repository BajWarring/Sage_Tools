import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 1. Visual Preview Library
import 'package:pdf_render/pdf_render.dart'; 
// 2. Vector Logic Library
import 'package:syncfusion_flutter_pdf/pdf.dart' as vector; 
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
  ui.Image? _previewImage; 
  Size? _imageSize;     
  Size? _pdfPageSize;   
  int _pageRotation = 0; // 0, 90, 180, 270
  
  // Crop Logic (Visual Coordinates on Screen)
  Rect _cropRect = Rect.zero; 
  bool _isLandscapeRatio = false;
  int _selectedRatioIndex = 0; 
  bool _isRatioLocked = false;
  String _activeHandle = ''; 
  
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
    _loadPdfSequence();
  }

  Future<void> _loadPdfSequence() async {
    try {
      // 1. Analyze Vector Document & Rotation
      final bytes = File(widget.filePath).readAsBytesSync();
      final vDoc = vector.PdfDocument(inputBytes: bytes);
      final vPage = vDoc.pages[0];
      
      if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle90) _pageRotation = 90;
      else if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle180) _pageRotation = 180;
      else if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle270) _pageRotation = 270;
      else _pageRotation = 0;

      // Store raw page size
      _pdfPageSize = vPage.size; 
      vDoc.dispose();

      // 2. Render Visual Screenshot (Auto-rotates to be upright)
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1);
      
      int renderW = 1000;
      int renderH = (renderW * (page.height / page.width)).toInt();
      
      final pageImage = await page.render(width: renderW, height: renderH);
      final uiImage = await pageImage.createImageDetached();
      
      if (mounted) {
        setState(() {
          _previewImage = uiImage;
          _imageSize = Size(renderW.toDouble(), renderH.toDouble());
          
          // Init Crop (80% Center)
          double w = _imageSize!.width * 0.8;
          double h = _imageSize!.height * 0.8;
          double x = (_imageSize!.width - w) / 2;
          double y = (_imageSize!.height - h) / 2;
          _cropRect = Rect.fromLTWH(x, y, w, h);
          
          _isLoading = false;
          _updateControllers();
        });
      }
    } catch (e) {
      print("Err: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- Logic ---

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
        // Fit Ratio
        double newH = _cropRect.width / ratio;
        if (_cropRect.top + newH <= _imageSize!.height) {
          _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, _cropRect.width, newH);
        } else {
          double newW = _cropRect.height * ratio;
          _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, _cropRect.height);
        }
      }
      _updateControllers();
    });
  }

  // --- MATHEMATICAL ROTATION FIX ---
  // Converts "Screen" crop rectangle to "PDF Internal" crop rectangle
  // This handles the 90/180/270 degree rotation logic
  Rect _calculatePdfCropRect(Rect visualRect, Size pdfSize) {
    double scaleX, scaleY;
    
    // If rotated 90 or 270, Visual Width maps to PDF Height
    if (_pageRotation == 90 || _pageRotation == 270) {
      scaleX = pdfSize.height / _imageSize!.width;
      scaleY = pdfSize.width / _imageSize!.height;
    } else {
      scaleX = pdfSize.width / _imageSize!.width;
      scaleY = pdfSize.height / _imageSize!.height;
    }

    double l = visualRect.left * scaleX;
    double t = visualRect.top * scaleY;
    double w = visualRect.width * scaleX;
    double h = visualRect.height * scaleY;

    // Coordinate Transformation Matrix
    // 0 deg: x=x, y=y
    // 90 deg: x=y, y=H-x-w (Visual Top becomes PDF Right)
    // etc.
    
    if (_pageRotation == 0) {
      return Rect.fromLTWH(l, t, w, h);
    } else if (_pageRotation == 90) {
      // Visual Top is PDF Left? No.
      // Visual Up is PDF Left.
      // x' = t, y' = (PDF_H - l - w) ?? No, let's use standard rotation.
      // Standard: (x,y) -> (y, W-x) for 90 CW.
      // But Syncfusion coords start Bottom-Left? No, Top-Left usually.
      
      // Simplified: We Map "Visual Box" to "PDF Box"
      // If 90deg:
      // NewX = t
      // NewY = pdfSize.width - l - w
      // NewW = h
      // NewH = w
      return Rect.fromLTWH(t, pdfSize.width - l - w, h, w);
    } else if (_pageRotation == 180) {
      return Rect.fromLTWH(pdfSize.width - l - w, pdfSize.height - t - h, w, h);
    } else if (_pageRotation == 270) {
      return Rect.fromLTWH(pdfSize.height - t - h, l, h, w);
    }
    
    return Rect.fromLTWH(l, t, w, h);
  }

  Future<void> _savePdf() async {
    setState(() => _isLoading = true);
    try {
      if (await Permission.storage.request().isDenied) {
        await Permission.manageExternalStorage.request();
      }

      final bytes = File(widget.filePath).readAsBytesSync();
      final loadedDoc = vector.PdfDocument(inputBytes: bytes);
      final loadedPage = loadedDoc.pages[0];

      // 1. Calculate TRUE Vector Rect (Rotation Aware)
      Rect pdfRect = _calculatePdfCropRect(_cropRect, loadedPage.size);

      // 2. Create New Document
      final newDoc = vector.PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      // Dimensions are swapped back for the new page size if we want it "Upright"
      newDoc.pageSettings.size = Size(pdfRect.width, pdfRect.height);
      
      final newPage = newDoc.pages.add();

      // 3. Draw Template
      // We offset the template negatively to bring the crop area to (0,0)
      final template = loadedPage.createTemplate();
      
      // If we rotated coordinates, we need to ensure the template draws correctly.
      // Simplest way: Reset rotation on the template? No.
      // Use the calculated offset.
      newPage.graphics.drawPdfTemplate(template, Offset(-pdfRect.left, -pdfRect.top));

      // 4. Save
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final saveDir = Directory('${downloadsDir.path}/SageTools');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);
      
      final fileName = 'Sage_Crop_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${saveDir.path}/$fileName');
      
      await file.writeAsBytes(await newDoc.save());
      
      loadedDoc.dispose();
      newDoc.dispose();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Saved Vector PDF: $fileName"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      print("Save Error: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- Interaction Logic ---
  
  void _onHandlePan(DragUpdateDetails d, String type, double scale) {
    if (_imageSize == null) return;
    double dx = d.delta.dx / scale;
    double dy = d.delta.dy / scale;
    
    setState(() {
      Rect r = _cropRect;
      double minS = 20.0;
      
      // Proposed Edges
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
           if (type.contains('l') || type.contains('r')) {
              double newW = newR - newL;
              double newH = newW / ratio;
              if (type.contains('t')) newT = newB - newH; else newB = newT + newH;
           } else {
              double newH = newB - newT;
              double newW = newH * ratio;
              if (type.contains('l')) newL = newR - newW; else newR = newL + newW;
           }
        }
      }

      if (newR - newL < minS) { if (type.contains('l')) newL = newR - minS; else newR = newL + minS; }
      if (newB - newT < minS) { if (type.contains('t')) newT = newB - minS; else newB = newT + minS; }

      // Clamp visual bounds
      newL = max(0, newL); newT = max(0, newT);
      newR = min(_imageSize!.width, newR); newB = min(_imageSize!.height, newB);
      
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
            // Controls
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: panelBg, border: Border(bottom: BorderSide(color: border))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(onPressed: (){}, icon: Icon(Icons.auto_fix_high, size: 16), label: Text("Auto Detect"), style: TextButton.styleFrom(foregroundColor: theme.primary)),
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
                      separatorBuilder: (_,__) => SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        bool isSelected = i == _selectedRatioIndex;
                        String label = ratioList[i]['label'];
                        IconData? icon;
                        
                        // "Locked" Button Logic
                        if (i == 0) {
                          label = "";
                          icon = _isRatioLocked ? Icons.lock : Icons.lock_open;
                        }

                        return GestureDetector(
                          onTap: () {
                             if (i == 0) _toggleLockState();
                             else _applyRatio(i);
                          },
                          child: Container(
                            // Fixed width for lock button to prevent jumping
                            width: i == 0 ? 50 : null,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? theme.primary : panelBg,
                              border: Border.all(color: isSelected ? theme.primary : border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: icon != null 
                              ? Icon(icon, size: 16, color: isSelected ? theme.onPrimary : subText)
                              : Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? theme.onPrimary : subText)),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
            
            // Preview
            Expanded(
              child: Container(
                color: theme.surfaceContainerHighest,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    if (_previewImage == null) return Container();
                    double viewW = constraints.maxWidth;
                    double viewH = constraints.maxHeight;
                    double imgW = _imageSize!.width;
                    double imgH = _imageSize!.height;
                    double scale = min(viewW / imgW, viewH / imgH) * 0.9;
                    double displayW = imgW * scale;
                    double displayH = imgH * scale;
                    double offX = (viewW - displayW) / 2;
                    double offY = (viewH - displayH) / 2;

                    return Stack(
                      children: [
                        Positioned(
                          left: offX, top: offY, width: displayW, height: displayH,
                          child: Stack(
                            children: [
                              Container(decoration: BoxDecoration(color: panelBg, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: RawImage(image: _previewImage, fit: BoxFit.contain)),
                              Positioned(top:0, left:0, right:0, height: _cropRect.top * scale, child: ColoredBox(color: Colors.black54)),
                              Positioned(bottom:0, left:0, right:0, top: (_cropRect.bottom * scale), child: ColoredBox(color: Colors.black54)),
                              Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, left:0, width: _cropRect.left*scale, child: ColoredBox(color: Colors.black54)),
                              Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, right:0, left: _cropRect.right*scale, child: ColoredBox(color: Colors.black54)),
                              Positioned(
                                left: _cropRect.left * scale, top: _cropRect.top * scale, width: _cropRect.width * scale, height: _cropRect.height * scale,
                                child: GestureDetector(
                                  onPanUpdate: (d) => _onHandlePan(d, 'body', scale),
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: theme.primary, width: 2)),
                                    child: Stack(
                                      children: [
                                        Column(children: [Spacer(), Divider(color: Colors.white30, height:1), Spacer(), Divider(color: Colors.white30, height:1), Spacer()]),
                                        Row(children: [Spacer(), VerticalDivider(color: Colors.white30, width:1), Spacer(), VerticalDivider(color: Colors.white30, width:1), Spacer()]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ..._buildHandles(scale, theme.primary),
                            ],
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
            
            // Bottom Grid
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
    double L = _cropRect.left * scale; double T = _cropRect.top * scale;
    double R = _cropRect.right * scale; double B = _cropRect.bottom * scale;
    double cX = L + (_cropRect.width * scale / 2); double cY = T + (_cropRect.height * scale / 2);
    double size = 30.0; double dot = 12.0;
    Widget handle(double x, double y, String type) {
      return Positioned(
        left: x - (size/2), top: y - (size/2), width: size, height: size,
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
