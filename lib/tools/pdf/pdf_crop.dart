import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 1. Visual Preview Library
import 'package:pdf_render/pdf_render.dart'; 
// 2. Vector Logic Library (Prefixed to avoid conflicts)
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
  PdfPageImage? _previewImage; // Bitmap for display
  
  // Dimensions
  Size? _imageSize;     // Size of the bitmap
  Size? _pdfPageSize;   // Size of the vector page (Points)
  
  // Crop Logic (Visual Coordinates)
  Rect _cropRect = Rect.zero; 
  String _orientation = 'portrait';
  
  // UX State
  int _selectedRatioIndex = 0; // 0 = Free
  String _activeHandle = ''; 
  
  // Controllers
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  // Configuration
  final List<Map<String, dynamic>> _ratios = [
    {'label': 'Free', 'val': null},
    {'label': '1:1', 'val': 1.0},
    {'label': '2:3', 'val': 2/3},
    {'label': '3:4', 'val': 3/4},
    {'label': '9:16', 'val': 9/16},
    {'label': '16:9', 'val': 16/9},
  ];

  @override
  void initState() {
    super.initState();
    _loadPdfSequence();
  }

  Future<void> _loadPdfSequence() async {
    try {
      // 1. Analyze Vector Document (Dimensions & Rotation)
      final bytes = File(widget.filePath).readAsBytesSync();
      final vDoc = vector.PdfDocument(inputBytes: bytes);
      final vPage = vDoc.pages[0];
      
      // Handle Rotation (Swap width/height if rotated 90 or 270)
      int rotation = 0;
      if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle90) rotation = 90;
      else if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle180) rotation = 180;
      else if (vPage.rotation == vector.PdfPageRotateAngle.rotateAngle270) rotation = 270;

      if (rotation == 90 || rotation == 270) {
        _pdfPageSize = Size(vPage.size.height, vPage.size.width);
      } else {
        _pdfPageSize = vPage.size;
      }
      
      _orientation = _pdfPageSize!.width > _pdfPageSize!.height ? 'landscape' : 'portrait';
      vDoc.dispose();

      // 2. Render Visual Screenshot
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1);
      
      // Render at high density (e.g., width 1000px)
      int renderW = 1000;
      int renderH = (renderW * (page.height / page.width)).toInt();
      
      final image = await page.render(width: renderW, height: renderH);
      
      if (mounted) {
        setState(() {
          _previewImage = image;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not load PDF: $e")));
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

  void _applyRatio(int index) {
    setState(() {
      _selectedRatioIndex = index;
      double? ratio = _ratios[index]['val'];
      if (ratio == null) return;

      // Keep width, adjust height
      double newH = _cropRect.width / ratio;
      if (_cropRect.top + newH <= _imageSize!.height) {
        _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, _cropRect.width, newH);
      } else {
        // Fit height, adjust width
        double newW = _cropRect.height * ratio;
        _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, _cropRect.height);
      }
      _updateControllers();
    });
  }

  Future<void> _savePdf() async {
    setState(() => _isLoading = true);
    try {
      // 1. Permission
      if (await Permission.storage.request().isDenied) {
        await Permission.manageExternalStorage.request();
      }

      final bytes = File(widget.filePath).readAsBytesSync();
      final vDoc = vector.PdfDocument(inputBytes: bytes);
      final vPage = vDoc.pages[0];

      // 2. Math: Calculate Scaling Factor (Visual Pixels -> PDF Points)
      double scale = _pdfPageSize!.width / _imageSize!.width;
      
      double cX = _cropRect.left * scale;
      double cY = _cropRect.top * scale;
      double cW = _cropRect.width * scale;
      double cH = _cropRect.height * scale;

      // 3. Create New PDF
      final newDoc = vector.PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      newDoc.pageSettings.size = Size(cW, cH);
      
      final newPage = newDoc.pages.add();

      // 4. White Background Layer (Fixes Transparency/Black Text issues)
      newPage.graphics.drawRectangle(
        bounds: Rect.fromLTWH(0, 0, cW, cH),
        brush: vector.PdfSolidBrush(vector.PdfColor(255, 255, 255))
      );

      // 5. Draw Content (Offset to act as crop)
      final template = vPage.createTemplate();
      newPage.graphics.drawPdfTemplate(template, Offset(-cX, -cY));

      // 6. Save
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final saveDir = Directory('${downloadsDir.path}/SageTools');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);
      
      final fileName = 'Sage_Crop_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${saveDir.path}/$fileName');
      
      await file.writeAsBytes(await newDoc.save());
      
      vDoc.dispose();
      newDoc.dispose();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Saved to Downloads/SageTools"),
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

  // --- UI Construction ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.white, // Match HTML
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
            // --- Top Controls (Auto, Orientation, Ratios) ---
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[100]!))
              ),
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
                        onPressed: () {}, // Orientation logic placeholder
                        icon: Icon(Icons.screen_lock_portrait, size: 16),
                        label: Text(_orientation == 'portrait' ? "Portrait" : "Landscape"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: StadiumBorder()
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _ratios.length,
                      separatorBuilder: (_,__) => SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        bool isActive = i == _selectedRatioIndex;
                        return GestureDetector(
                          onTap: () => _applyRatio(i),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActive ? theme.primary : Colors.white,
                              border: Border.all(color: isActive ? theme.primary : Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isActive ? [BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 4, offset: Offset(0,2))] : []
                            ),
                            child: Text(
                              _ratios[i]['label'], 
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.white : Colors.grey[600]
                              )
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),

            // --- Main Preview Area ---
            Expanded(
              child: Container(
                color: Color(0xFFF1F5F9), // Slate-100/50 match
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    if (_previewImage == null) return Container();

                    // Calculate Aspect Fit
                    double viewW = constraints.maxWidth;
                    double viewH = constraints.maxHeight;
                    double imgW = _imageSize!.width;
                    double imgH = _imageSize!.height;
                    
                    double scale = min(viewW / imgW, viewH / imgH) * 0.9; // 90% padding
                    double displayW = imgW * scale;
                    double displayH = imgH * scale;
                    double offX = (viewW - displayW) / 2;
                    double offY = (viewH - displayH) / 2;

                    return GestureDetector(
                      onPanUpdate: (d) {
                        if (_activeHandle == '') return;
                        
                        double dx = d.delta.dx / scale;
                        double dy = d.delta.dy / scale;
                        
                        setState(() {
                          Rect r = _cropRect;
                          // Basic Body Drag
                          if (_activeHandle == 'body') {
                            r = r.shift(Offset(dx, dy));
                          } 
                          // Simple Handle Logic (Bottom Right only for brevity, user can add others)
                          else if (_activeHandle == 'br') {
                            r = Rect.fromLTRB(r.left, r.top, r.right + dx, r.bottom + dy);
                          }
                          // Clamp
                          double nLeft = max(0, r.left);
                          double nTop = max(0, r.top);
                          double nRight = min(imgW, r.right);
                          double nBottom = min(imgH, r.bottom);
                          _cropRect = Rect.fromLTWH(nLeft, nTop, nRight - nLeft, nBottom - nTop);
                          _updateControllers();
                        });
                      },
                      onPanStart: (d) => _activeHandle = 'body',
                      onPanEnd: (d) => _activeHandle = '',
                      child: Stack(
                        children: [
                          Positioned(
                            left: offX, top: offY,
                            width: displayW, height: displayH,
                            child: Stack(
                              children: [
                                // Image
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
                                  ),
                                  child: Image.memory(_previewImage!.pixels, fit: BoxFit.contain)
                                ),
                                // Scrims
                                Positioned(top:0, left:0, right:0, height: _cropRect.top * scale, child: ColoredBox(color: Colors.black54)),
                                Positioned(bottom:0, left:0, right:0, top: (_cropRect.bottom * scale), child: ColoredBox(color: Colors.black54)),
                                Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, left:0, width: _cropRect.left*scale, child: ColoredBox(color: Colors.black54)),
                                Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, right:0, left: _cropRect.right*scale, child: ColoredBox(color: Colors.black54)),
                                // Crop Box
                                Positioned(
                                  left: _cropRect.left * scale,
                                  top: _cropRect.top * scale,
                                  width: _cropRect.width * scale,
                                  height: _cropRect.height * scale,
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: theme.primary, width: 2)),
                                    child: Stack(
                                      children: [
                                        // Grid
                                        Column(children: [Spacer(), Divider(color: Colors.white30, height:1), Spacer(), Divider(color: Colors.white30, height:1), Spacer()]),
                                        Row(children: [Spacer(), VerticalDivider(color: Colors.white30, width:1), Spacer(), VerticalDivider(color: Colors.white30, width:1), Spacer()]),
                                        // Handle (Bottom Right)
                                        Positioned(
                                          right: -6, bottom: -6,
                                          child: GestureDetector(
                                            onPanStart: (d) => _activeHandle = 'br',
                                            child: Container(
                                              width: 12, height: 12,
                                              decoration: BoxDecoration(
                                                color: theme.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2)
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // --- Bottom Panel ---
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -4))]
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildInput('X', _xCtrl), SizedBox(width: 12),
                      _buildInput('Y', _yCtrl), SizedBox(width: 12),
                      _buildInput('W', _wCtrl), SizedBox(width: 12),
                      _buildInput('H', _hCtrl),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _savePdf,
                      icon: Icon(Icons.download_rounded, size: 20),
                      label: Text("Export PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50], // Slate-50
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400])),
            TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              decoration: InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _onInputChanged(),
            )
          ],
        ),
      ),
    );
  }
}
