import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as vector_pdf;
import 'package:permission_handler/permission_handler.dart';

class PdfCropScreen extends StatefulWidget {
  final String filePath;
  PdfCropScreen({required this.filePath});

  @override
  _PdfCropScreenState createState() => _PdfCropScreenState();
}

class _PdfCropScreenState extends State<PdfCropScreen> {
  // Logic & State
  PdfPageImage? _pageImage;
  Rect _cropRect = Rect.zero; 
  Size? _layoutSize;          
  Size? _pdfPageSize;         
  bool _isLoading = true;
  int _rotation = 0; 
  
  // UX Interaction
  String _activeHandle = ''; 
  
  // Controllers for Inputs
  final TextEditingController _xCtrl = TextEditingController();
  final TextEditingController _yCtrl = TextEditingController();
  final TextEditingController _wCtrl = TextEditingController();
  final TextEditingController _hCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSequence();
  }

  Future<void> _initSequence() async {
    try {
      // 1. Get Vector Info (Dimensions & Rotation)
      final bytes = File(widget.filePath).readAsBytesSync();
      final vectorDoc = vector_pdf.PdfDocument(inputBytes: bytes);
      final vectorPage = vectorDoc.pages[0];
      
      // FIX: Use PdfPageRotateAngle instead of PdfRotation
      _rotation = 0;
      if (vectorPage.rotation == vector_pdf.PdfPageRotateAngle.rotateAngle90) _rotation = 90;
      else if (vectorPage.rotation == vector_pdf.PdfPageRotateAngle.rotateAngle180) _rotation = 180;
      else if (vectorPage.rotation == vector_pdf.PdfPageRotateAngle.rotateAngle270) _rotation = 270;

      // If rotated 90/270, swap W and H for the 'Visual' size calculation
      if (_rotation == 90 || _rotation == 270) {
        _pdfPageSize = Size(vectorPage.size.height, vectorPage.size.width);
      } else {
        _pdfPageSize = vectorPage.size;
      }
      
      vectorDoc.dispose();

      // 2. Render Bitmap Preview (Visuals)
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1); // 1-based index
      
      // Render at high density
      final image = await page.render(
        width: (page.width * 2).toInt(), 
        height: (page.height * 2).toInt()
      );

      if (mounted) {
        setState(() {
          _pageImage = image;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load PDF preview")));
    }
  }

  // --- Input Handlers ---
  void _updateControllers() {
    if (!mounted) return;
    _xCtrl.text = _cropRect.left.toInt().toString();
    _yCtrl.text = _cropRect.top.toInt().toString();
    _wCtrl.text = _cropRect.width.toInt().toString();
    _hCtrl.text = _cropRect.height.toInt().toString();
  }

  void _onTextChange() {
    if (_layoutSize == null) return;
    
    double? x = double.tryParse(_xCtrl.text);
    double? y = double.tryParse(_yCtrl.text);
    double? w = double.tryParse(_wCtrl.text);
    double? h = double.tryParse(_hCtrl.text);

    if (x != null && y != null && w != null && h != null) {
      double right = x + w;
      double bottom = y + h;
      
      if (right <= _layoutSize!.width && bottom <= _layoutSize!.height) {
        setState(() {
          _cropRect = Rect.fromLTWH(x, y, w, h);
        });
      }
    }
  }

  // --- Logic: Save (Vector Crop) ---
  Future<void> _saveCroppedPdf() async {
    if (_layoutSize == null || _pdfPageSize == null) return;
    setState(() => _isLoading = true);

    try {
      // Permissions
      if (await Permission.storage.request().isDenied) {
        await Permission.manageExternalStorage.request();
      }

      final bytes = File(widget.filePath).readAsBytesSync();
      final loadedDoc = vector_pdf.PdfDocument(inputBytes: bytes);
      final loadedPage = loadedDoc.pages[0];

      // 1. Calculate Scale based on the VISUAL (Rotation Corrected) size
      double scale = _pdfPageSize!.width / _layoutSize!.width;
      
      double cropX = _cropRect.left * scale;
      double cropY = _cropRect.top * scale;
      double cropW = _cropRect.width * scale;
      double cropH = _cropRect.height * scale;

      // 2. Create New Document
      final newDoc = vector_pdf.PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      newDoc.pageSettings.size = Size(cropW, cropH);
      final newPage = newDoc.pages.add();

      // 3. Draw Template with Transformations
      final template = loadedPage.createTemplate();
      
      // Draw the template offset by the crop amount
      newPage.graphics.drawPdfTemplate(template, Offset(-cropX, -cropY));

      // 4. Save to Downloads/SageTools
      List<int> savedBytes = await newDoc.save();
      newDoc.dispose();
      loadedDoc.dispose();

      final Directory? downloadsDir = Directory('/storage/emulated/0/Download');
      final sageDir = Directory('${downloadsDir!.path}/SageTools');
      if (!await sageDir.exists()) {
        await sageDir.create(recursive: true);
      }

      final fileName = 'Sage_Crop_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${sageDir.path}/$fileName');
      await file.writeAsBytes(savedBytes);

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Saved to: Download/SageTools/$fileName"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 5),
        action: SnackBarAction(label: "OK", onPressed: (){}, textColor: Colors.white),
      ));
    } catch (e) {
      print("Save Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  // --- Logic: Touch Interaction ---
  void _onPanStart(DragStartDetails details, String handle) {
    _activeHandle = handle;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_layoutSize == null) return;
    Offset delta = details.delta;
    Rect newR = _cropRect;
    double minSize = 40.0;

    switch (_activeHandle) {
      case 'body': newR = newR.shift(delta); break;
      case 'topLeft':
        newR = Rect.fromLTRB(min(newR.right - minSize, newR.left + delta.dx), min(newR.bottom - minSize, newR.top + delta.dy), newR.right, newR.bottom); break;
      case 'topRight':
        newR = Rect.fromLTRB(newR.left, min(newR.bottom - minSize, newR.top + delta.dy), max(newR.left + minSize, newR.right + delta.dx), newR.bottom); break;
      case 'bottomLeft':
        newR = Rect.fromLTRB(min(newR.right - minSize, newR.left + delta.dx), newR.top, newR.right, max(newR.top + minSize, newR.bottom + delta.dy)); break;
      case 'bottomRight':
        newR = Rect.fromLTRB(newR.left, newR.top, max(newR.left + minSize, newR.right + delta.dx), max(newR.top + minSize, newR.bottom + delta.dy)); break;
    }

    double left = max(0, newR.left);
    double top = max(0, newR.top);
    double right = min(_layoutSize!.width, newR.right);
    double bottom = min(_layoutSize!.height, newR.bottom);
    
    // Clamp
    if (right - left < minSize) right = left + minSize;
    if (bottom - top < minSize) bottom = top + minSize;

    setState(() {
      _cropRect = Rect.fromLTRB(left, top, right, bottom);
      _updateControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Crop PDF", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveCroppedPdf,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(20)),
              child: Text("APPLY", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Coordinates Bar
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.black45,
            child: Row(
              children: [
                _buildInput("X", _xCtrl), SizedBox(width: 10),
                _buildInput("Y", _yCtrl), SizedBox(width: 10),
                _buildInput("W", _wCtrl), SizedBox(width: 10),
                _buildInput("H", _hCtrl),
              ],
            ),
          ),
          
          // 2. Editor Surface
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (_pageImage == null) return Center(child: Text("Error loading image", style: TextStyle(color: Colors.white)));

                    double availW = constraints.maxWidth;
                    double availH = constraints.maxHeight;
                    double imgW = _pageImage!.width.toDouble();
                    double imgH = _pageImage!.height.toDouble();
                    
                    // Fit logic (Contain)
                    double scale = min(availW / imgW, availH / imgH);
                    double displayW = imgW * scale;
                    double displayH = imgH * scale;
                    double offX = (availW - displayW) / 2;
                    double offY = (availH - displayH) / 2;

                    _layoutSize = Size(displayW, displayH);
                    
                    if (_cropRect == Rect.zero) {
                       double size = min(displayW, displayH) * 0.8;
                       _cropRect = Rect.fromCenter(center: Offset(displayW/2, displayH/2), width: size, height: size);
                       WidgetsBinding.instance.addPostFrameCallback((_) => _updateControllers());
                    }

                    return Stack(
                      children: [
                        Positioned(
                          left: offX, top: offY, width: displayW, height: displayH,
                          child: Stack(
                            children: [
                              // A. White Base (For Transparency)
                              Container(width: displayW, height: displayH, color: Colors.white),
                              
                              // B. PDF Image
                              Image.memory(_pageImage!.pixels, width: displayW, height: displayH, fit: BoxFit.contain),
                              
                              // C. Dark Scrim
                              Positioned(left: 0, top: 0, width: displayW, height: _cropRect.top, child: Container(color: Colors.black.withOpacity(0.5))),
                              Positioned(left: 0, top: _cropRect.bottom, width: displayW, height: displayH - _cropRect.bottom, child: Container(color: Colors.black.withOpacity(0.5))),
                              Positioned(left: 0, top: _cropRect.top, width: _cropRect.left, height: _cropRect.height, child: Container(color: Colors.black.withOpacity(0.5))),
                              Positioned(left: _cropRect.right, top: _cropRect.top, width: displayW - _cropRect.right, height: _cropRect.height, child: Container(color: Colors.black.withOpacity(0.5))),
                              
                              // D. Crop Box
                              Positioned.fromRect(
                                rect: _cropRect,
                                child: GestureDetector(
                                  onPanStart: (d) => _onPanStart(d, 'body'),
                                  onPanUpdate: _onPanUpdate,
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), color: Colors.white.withOpacity(0.01)),
                                    child: Stack(
                                      children: [
                                        // Grid Lines
                                        Column(children: [Spacer(), Divider(color: Colors.white24, height: 1), Spacer(), Divider(color: Colors.white24, height: 1), Spacer()]),
                                        Row(children: [Spacer(), VerticalDivider(color: Colors.white24, width: 1), Spacer(), VerticalDivider(color: Colors.white24, width: 1), Spacer()]),
                                        // Corners
                                        _buildHandle('topLeft', Alignment.topLeft), _buildHandle('topRight', Alignment.topRight),
                                        _buildHandle('bottomLeft', Alignment.bottomLeft), _buildHandle('bottomRight', Alignment.bottomRight),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(bottom: 2)),
                onSubmitted: (_) => _onTextChange(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(String id, Alignment align) {
    return Align(alignment: align, child: GestureDetector(
      onPanStart: (d) => _onPanStart(d, id), onPanUpdate: _onPanUpdate,
      child: Container(width: 30, height: 30, color: Colors.transparent, alignment: Alignment.center,
        child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)])),
      ),
    ));
  }
}
