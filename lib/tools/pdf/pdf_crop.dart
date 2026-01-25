import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_render/pdf_render.dart'; 
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
  
  // Crop Logic
  Rect _cropRect = Rect.zero; 
  bool _isLandscapeRatio = false;
  int _selectedRatioIndex = 0; 
  bool _isRatioLocked = false;
  String _activeHandle = ''; 
  
  // Controllers
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
      // 1. Analyze Vector Document (Get Real Dimensions including Rotation)
      final bytes = File(widget.filePath).readAsBytesSync();
      final vDoc = vector.PdfDocument(inputBytes: bytes);
      final vPage = vDoc.pages[0];
      
      // Calculate "Visual" Size based on rotation
      int rotation = 0;
      if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle90) rotation = 90;
      else if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle180) rotation = 180;
      else if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle270) rotation = 270;

      if (rotation == 90 || rotation == 270) {
        _pdfPageSize = Size(vPage.size.height, vPage.size.width);
      } else {
        _pdfPageSize = vPage.size;
      }
      vDoc.dispose();

      // 2. Render Visual Screenshot
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
          
          // Initial Crop: 80% Center
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
        
        // Fit Ratio inside current bounds
        double currentW = _cropRect.width;
        double newH = currentW / ratio;
        
        // If height overflows, fit to height instead
        if (_cropRect.top + newH > _imageSize!.height) {
           double currentH = _cropRect.height;
           double newW = currentH * ratio;
           _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, currentH);
        } else {
           _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, currentW, newH);
        }
      }
      _updateControllers();
    });
  }

  Future<void> _savePdf() async {
    setState(() => _isLoading = true);
    try {
      if (await Permission.storage.request().isDenied) {
        await Permission.manageExternalStorage.request();
      }

      // 1. Calculate Crop Scale
      double scale = _pdfPageSize!.width / _imageSize!.width;
      
      // Visual Crop Rect
      double vX = _cropRect.left * scale;
      double vY = _cropRect.top * scale;
      double vW = _cropRect.width * scale;
      double vH = _cropRect.height * scale;

      // 2. Load Original
      final bytes = File(widget.filePath).readAsBytesSync();
      final loadedDoc = vector.PdfDocument(inputBytes: bytes);
      final loadedPage = loadedDoc.pages[0];
      
      // 3. Coordinate Rotation Logic
      // If the original page is rotated (e.g. Landscape 90deg), the "Top Left" visually
      // is NOT (0,0) in the PDF coordinate system.
      // We must map the Visual Rect to the PDF Rect.
      
      int rot = 0;
      if (loadedPage.rotation == vector.PdfPageRotateAngle.rotateAngle90) rot = 90;
      else if (loadedPage.rotation == vector.PdfPageRotateAngle.rotateAngle180) rot = 180;
      else if (loadedPage.rotation == vector.PdfPageRotateAngle.rotateAngle270) rot = 270;

      // Create New PDF
      final newDoc = vector.PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      
      // Set new page size to the crop dimensions
      // Note: If rotated, width/height meaning swaps relative to the user,
      // but 'size' property is absolute points.
      newDoc.pageSettings.size = Size(vW, vH);
      
      final newPage = newDoc.pages.add();

      // 4. Draw Template with Transformation
      final template = loadedPage.createTemplate();
      
      // MATRIX MATH for Rotation Correction
      // We essentially "undo" the rotation on the new page or offset accordingly.
      // The easiest fix is to Propagate Rotation:
      if (rot == 90) {
         newPage.graphics.translateTransform(0, 0); // Reset? No.
         // If source is 90, standard template draw usually draws it 90 rotated.
         // We need to shift the window.
         
         // Fix: If the page is rotated, we essentially need to "pan" the view.
         // For 90deg, Visual X matches PDF Top (Y), Visual Y matches PDF Right (X inverted?).
         
         // Simpler Fix:
         // Just use the Visual Dimensions (vW, vH) for the new page size.
         // And draw the template offset by (-vX, -vY).
         // BUT we must rotate the new page to match the old one so the text renders upright.
         newPage.rotation = loadedPage.rotation;
         
         // If we set rotation, the coordinate system rotates too.
         // So (-vX, -vY) should work perfectly.
         
         // HOWEVER, Syncfusion has a quirk where template dimensions swap on rotation.
         // We might need to swap the new page size.
         newDoc.pageSettings.size = Size(vH, vW); // Swap for Landscape storage
      } else if (rot == 270) {
         newPage.rotation = loadedPage.rotation;
         newDoc.pageSettings.size = Size(vH, vW);
      } else {
         // Portrait / 180
         newPage.rotation = loadedPage.rotation;
      }

      // Draw
      newPage.graphics.drawPdfTemplate(template, Offset(-vX, -vY));

      // Save
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

  // --- No-Squish Resize Logic ---
  void _onHandlePan(DragUpdateDetails d, String type, double scale) {
    if (_imageSize == null) return;
    double dx = d.delta.dx / scale;
    double dy = d.delta.dy / scale;
    
    setState(() {
      Rect r = _cropRect;
      double minS = 20.0;
      
      double newL = r.left, newT = r.top, newR = r.right, newB = r.bottom;

      // 1. Move Body (Clamp only, no size change)
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

      // 2. Resize Calculations
      if (type.contains('l')) newL += dx;
      if (type.contains('r')) newR += dx;
      if (type.contains('t')) newT += dy;
      if (type.contains('b')) newB += dy;

      // 3. Ratio Locking with Hard Stop (No Squish)
      if (_isRatioLocked) {
        var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
        double? ratio = list[_selectedRatioIndex]['val'];
        if (ratio != null) {
           // Decide constraint based on handle
           bool drivingW = type.contains('l') || type.contains('r');
           // Corner handles prioritize Width, unless dragging mostly vertical? 
           // Standard behavior: Width drives Height.
           
           if (drivingW) {
              double proposedW = newR - newL;
              double requiredH = proposedW / ratio;
              
              // Does required Height fit?
              double proposedT = type.contains('t') ? newB - requiredH : newT;
              double proposedB = type.contains('b') ? newT + requiredH : newB;
              
              // Boundary Check
              bool hFits = (proposedT >= 0) && (proposedB <= _imageSize!.height);
              bool wFits = (newL >= 0) && (newR <= _imageSize!.width);
              
              if (hFits && wFits) {
                 // Apply
                 if (type.contains('t')) newT = proposedT; else newB = proposedB;
              } else {
                 // HIT WALL: Stop resizing! Revert to previous valid state
                 // Or easier: clamp to limit
                 return; // Hard stop prevents squishing
              }
           } else {
              // Driving Height (Top/Bottom center handles)
              double proposedH = newB - newT;
              double requiredW = proposedH * ratio;
              
              double proposedL = type.contains('l') ? newR - requiredW : newL; // Center anchor logic? No, center handles expand symmetric usually, but here simple
              // Simple: Top handle moves Top, expands Width symmetrically or Right?
              // Let's assume symmetric expansion for center handles if we implemented it, 
              // but here we just have edge handles.
              // Just check bounds.
              double center = r.left + r.width/2;
              double pL = center - requiredW/2;
              double pR = center + requiredW/2;
              
              if (pL >= 0 && pR <= _imageSize!.width && newT >= 0 && newB <= _imageSize!.height) {
                 newL = pL; newR = pR;
              } else {
                 return; // Hard stop
              }
           }
        }
      }

      // Min Size
      if (newR - newL < minS) return;
      if (newB - newT < minS) return;

      // Boundary Clamp
      if (newL < 0 || newT < 0 || newR > _imageSize!.width || newB > _imageSize!.height) {
         if (!_isRatioLocked) {
            // Free mode: just clamp edges
            newL = max(0, newL); newT = max(0, newT);
            newR = min(_imageSize!.width, newR); newB = min(_imageSize!.height, newB);
         } else {
            return; // Locked mode: Hard stop if ANY edge hits
         }
      }

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
                            width: i == 0 ? 50 : null,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? theme.primary : panelBg,
                              border: Border.all(color: isSelected ? theme.primary : border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (icon != null) Icon(icon, size: 16, color: isSelected ? theme.onPrimary : subText),
                                if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? theme.onPrimary : subText)),
                              ],
                            ),
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
