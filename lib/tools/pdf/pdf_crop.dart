import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 1. Visual Preview Library (Screen only)
import 'package:pdf_render/pdf_render.dart'; 
// 2. Vector Logic Library (The Real Export Engine)
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
  ui.Image? _previewImage; // Bitmap for display
  
  // Dimensions
  Size? _imageSize;     // Size of the bitmap
  Size? _pdfPageSize;   // Size of the actual vector page (Points)
  
  // Crop Logic
  Rect _cropRect = Rect.zero; 
  bool _isLandscapeRatio = false;
  
  // UX State
  int _selectedRatioIndex = 0; // 0 = Free
  bool _isRatioLocked = false;
  String _activeHandle = ''; 
  
  // Controllers
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  // Ratios
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
      // 1. Analyze Vector Document (Get Real Dimensions)
      final bytes = File(widget.filePath).readAsBytesSync();
      final vDoc = vector.PdfDocument(inputBytes: bytes);
      final vPage = vDoc.pages[0];
      
      // Handle Rotation for accurate mapping
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
      
      // High density render for UI
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

  // --- Logic Methods ---

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
      setState(() {
        _cropRect = Rect.fromLTWH(x, y, w, h);
      });
    }
  }

  void _toggleLockState() {
    setState(() {
      if (_isRatioLocked) {
        // Unlock
        _isRatioLocked = false;
        _selectedRatioIndex = 0; // Set to "Free"
      } else {
        // No action for clicking "Free" directly, users pick a ratio to lock
      }
    });
  }

  void _applyRatio(int index) {
    setState(() {
      var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
      double? ratio = list[index]['val'];

      if (ratio == null) {
        // "Free" selected
        _isRatioLocked = false;
        _selectedRatioIndex = 0;
      } else {
        // Specific Ratio -> Lock it
        _isRatioLocked = true;
        _selectedRatioIndex = index;
        
        // Apply immediately
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

  // --- True Vector Export ---
  Future<void> _savePdf() async {
    setState(() => _isLoading = true);
    try {
      if (await Permission.storage.request().isDenied) {
        await Permission.manageExternalStorage.request();
      }

      // 1. Calculate Crop Region in Real PDF Points
      double scale = _pdfPageSize!.width / _imageSize!.width;
      
      double cX = _cropRect.left * scale;
      double cY = _cropRect.top * scale;
      double cW = _cropRect.width * scale;
      double cH = _cropRect.height * scale;

      // 2. Load Original Vector PDF
      final bytes = File(widget.filePath).readAsBytesSync();
      final loadedDoc = vector.PdfDocument(inputBytes: bytes);
      final loadedPage = loadedDoc.pages[0];

      // 3. Create Destination PDF
      final newDoc = vector.PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      newDoc.pageSettings.size = Size(cW, cH);
      
      final newPage = newDoc.pages.add();

      // 4. FIX TEXT VISIBILITY: Draw White Background Layer
      // This ensures black text on transparent layers is visible
      newPage.graphics.drawRectangle(
        bounds: Rect.fromLTWH(0, 0, cW, cH),
        brush: vector.PdfSolidBrush(vector.PdfColor(255, 255, 255))
      );

      // 5. TRUE VECTOR CROP: Draw Template with Offset
      // We do NOT render to image. We clone the vector paths.
      final template = loadedPage.createTemplate();
      
      // Draw the template shifted so the cropped area is at (0,0)
      newPage.graphics.drawPdfTemplate(template, Offset(-cX, -cY));

      // 6. Save
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

  // --- Interaction Logic (Handles + Locking) ---
  
  void _onHandlePan(DragUpdateDetails d, String type, double scale) {
    if (_imageSize == null) return;
    
    double dx = d.delta.dx / scale;
    double dy = d.delta.dy / scale;
    
    setState(() {
      Rect r = _cropRect;
      double minS = 20.0;
      
      double newL = r.left;
      double newT = r.top;
      double newR = r.right;
      double newB = r.bottom;

      // 1. Body Move
      if (type == 'body') {
        double pL = newL + dx;
        double pT = newT + dy;
        double w = r.width;
        double h = r.height;

        if (pL < 0) pL = 0;
        if (pL + w > _imageSize!.width) pL = _imageSize!.width - w;
        if (pT < 0) pT = 0;
        if (pT + h > _imageSize!.height) pT = _imageSize!.height - h;

        _cropRect = Rect.fromLTWH(pL, pT, w, h);
        _updateControllers();
        return; 
      }

      // 2. Handle Resizing
      if (type.contains('l')) newL += dx;
      if (type.contains('r')) newR += dx;
      if (type.contains('t')) newT += dy;
      if (type.contains('b')) newB += dy;

      // 3. Aspect Ratio Locking
      if (_isRatioLocked) {
        var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
        double? ratio = list[_selectedRatioIndex]['val'];
        if (ratio != null) {
           // If changing width (L/R), force Height
           if (type.contains('l') || type.contains('r')) {
              double newW = newR - newL;
              double newH = newW / ratio;
              
              if (type.contains('t')) newT = newB - newH;
              else newB = newT + newH;
           } 
           // If changing height (T/B), force Width
           else {
              double newH = newB - newT;
              double newW = newH * ratio;
              
              if (type.contains('l')) newL = newR - newW;
              else newR = newL + newW;
           }
        }
      }

      // 4. Min Size & Clamping
      if (newR - newL < minS) {
        if (type.contains('l')) newL = newR - minS; else newR = newL + minS;
      }
      if (newB - newT < minS) {
        if (type.contains('t')) newT = newB - minS; else newB = newT + minS;
      }

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
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: Colors.grey[600], size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Crop PDF", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : Column(
          children: [
            // Controls
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: (){}, 
                        icon: Icon(Icons.auto_fix_high, size: 16),
                        label: Text("Auto Detect"),
                        style: TextButton.styleFrom(foregroundColor: theme.primary),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _isLandscapeRatio = !_isLandscapeRatio;
                          _selectedRatioIndex = 0;
                          _isRatioLocked = false;
                        }),
                        icon: Icon(_isLandscapeRatio ? Icons.crop_landscape : Icons.crop_portrait, size: 16),
                        label: Text(_isLandscapeRatio ? "Landscape" : "Portrait"),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[600], side: BorderSide(color: Colors.grey[300]!)),
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
                        // Logic for label: If this index is selected AND it's not "Free" (0), show "Locked"
                        // But actually user requested: "Free" button becomes "Locked"
                        String label = ratioList[i]['label'];
                        
                        // Special handling for the first button (Free/Locked toggle)
                        if (i == 0) {
                          label = _isRatioLocked ? "Locked" : "Free";
                          // If locked, highlight it red or secondary color to indicate lock state
                        }

                        return GestureDetector(
                          onTap: () {
                            if (i == 0 && _isRatioLocked) {
                               _toggleLockState(); // Unlock
                            } else {
                               _applyRatio(i);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? theme.primary : Colors.white,
                              border: Border.all(color: isSelected ? theme.primary : Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                if (i==0 && _isRatioLocked) ...[Icon(Icons.lock, size:12, color: Colors.white), SizedBox(width:4)],
                                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[600])),
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

            // Preview
            Expanded(
              child: Container(
                color: Color(0xFFF1F5F9),
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
                              Container(
                                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                                child: RawImage(image: _previewImage, fit: BoxFit.contain)
                              ),
                              Positioned(top:0, left:0, right:0, height: _cropRect.top * scale, child: ColoredBox(color: Colors.black54)),
                              Positioned(bottom:0, left:0, right:0, top: (_cropRect.bottom * scale), child: ColoredBox(color: Colors.black54)),
                              Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, left:0, width: _cropRect.left*scale, child: ColoredBox(color: Colors.black54)),
                              Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, right:0, left: _cropRect.right*scale, child: ColoredBox(color: Colors.black54)),
                              
                              Positioned(
                                left: _cropRect.left * scale,
                                top: _cropRect.top * scale,
                                width: _cropRect.width * scale,
                                height: _cropRect.height * scale,
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -4))]),
              child: Column(
                children: [
                  Row(children: [_buildInput('X', _xCtrl), SizedBox(width: 12), _buildInput('Y', _yCtrl), SizedBox(width: 12), _buildInput('W', _wCtrl), SizedBox(width: 12), _buildInput('H', _hCtrl)]),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _savePdf,
                      icon: Icon(Icons.download_rounded, size: 20),
                      label: Text("Export PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
          child: Container(
            alignment: Alignment.center, color: Colors.transparent,
            child: Container(width: dot, height: dot, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
          ),
        ),
      );
    }
    return [handle(L, T, 'tl'), handle(cX, T, 't'), handle(R, T, 'tr'), handle(L, cY, 'l'), handle(R, cY, 'r'), handle(L, B, 'bl'), handle(cX, B, 'b'), handle(R, B, 'br')];
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400])),
            TextField(controller: ctrl, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]), decoration: InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero), keyboardType: TextInputType.number, onSubmitted: (_) => _onInputChanged()),
          ],
        ),
      ),
    );
  }
}
