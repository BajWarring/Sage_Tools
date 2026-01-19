import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as vector_pdf;
import 'package:path_provider/path_provider.dart';

class PdfCropScreen extends StatefulWidget {
  final String filePath;
  PdfCropScreen({required this.filePath});

  @override
  _PdfCropScreenState createState() => _PdfCropScreenState();
}

class _PdfCropScreenState extends State<PdfCropScreen> {
  PdfDocument? _previewDoc;
  PdfPageImage? _pageImage;
  
  // State
  Rect _cropRect = Rect.zero; // Screen Coordinates
  Size? _layoutSize;          // The size of the image as rendered on screen
  Size? _pdfPageSize;         // The actual PDF point size (from vector lib)
  bool _isLoading = true;
  
  // UX Interaction
  String _activeHandle = ''; // 'topLeft', 'body', etc.
  Offset _dragStartOffset = Offset.zero;
  Rect _initialDragRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _initSequence();
  }

  Future<void> _initSequence() async {
    // 1. Get Vector Info (for aspect ratio calculation later)
    final bytes = File(widget.filePath).readAsBytesSync();
    final vectorDoc = vector_pdf.PdfDocument(inputBytes: bytes);
    final vectorPage = vectorDoc.pages[0];
    _pdfPageSize = vectorPage.size;
    vectorDoc.dispose();

    // 2. Render Bitmap Preview (Visuals)
    _previewDoc = await PdfDocument.openFile(widget.filePath);
    final page = await _previewDoc!.getPage(1);
    
    // Render at 2x density for sharpness
    final image = await page.render(
      width: (page.width * 2).toInt(), 
      height: (page.height * 2).toInt()
    );

    if (mounted) {
      setState(() {
        _pageImage = image;
        _isLoading = false;
        // Default Crop: Center 50%
        _cropRect = Rect.zero; // Will be set in LayoutBuilder
      });
    }
  }

  // --- Logic: Vector Save ---
  Future<void> _saveCroppedPdf() async {
    if (_layoutSize == null || _pdfPageSize == null) return;
    setState(() => _isLoading = true);

    try {
      final bytes = File(widget.filePath).readAsBytesSync();
      final document = vector_pdf.PdfDocument(inputBytes: bytes);
      final page = document.pages[0];

      // 1. Calculate Ratio (PDF Points / Screen Pixels)
      // We rely on the Width ratio to keep things square if aspect differs slightly
      double scale = _pdfPageSize!.width / _layoutSize!.width;

      // 2. Map Screen Rect -> PDF Rect
      double pdfLeft = _cropRect.left * scale;
      double pdfTop = _cropRect.top * scale;
      double pdfWidth = _cropRect.width * scale;
      double pdfHeight = _cropRect.height * scale;

      // 3. Apply CropBox (The Vector "Window")
      // Syncfusion uses CropBox to define the visible region.
      page.cropBox = Rect.fromLTWH(pdfLeft, pdfTop, pdfWidth, pdfHeight);
      
      // 4. Also set MediaBox to match (ensures the "paper size" changes too)
      page.mediaBox = Rect.fromLTWH(0, 0, pdfWidth, pdfHeight);
      
      // NOTE: Moving the content origin might be needed if crop is offset, 
      // but typically CropBox handles the "view".

      List<int> savedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Sage_Crop_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(savedBytes);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Saved Vector PDF: $fileName"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ));
    } catch (e) {
      print("Crop Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- Logic: Geometry ---
  void _onPanStart(DragStartDetails details, String handle) {
    _activeHandle = handle;
    _dragStartOffset = details.localPosition;
    _initialDragRect = _cropRect;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_layoutSize == null) return;
    
    // Total delta movement
    // We add delta to the specific edge associated with the handle
    Offset delta = details.delta;
    Rect newR = _cropRect;
    double minSize = 40.0; // Minimum touch target size

    // "Sejda" Style Controls
    switch (_activeHandle) {
      case 'body':
        newR = newR.shift(delta);
        break;
      case 'topLeft':
        newR = Rect.fromLTRB(
            min(newR.right - minSize, newR.left + delta.dx), 
            min(newR.bottom - minSize, newR.top + delta.dy), 
            newR.right, newR.bottom);
        break;
      case 'topRight':
        newR = Rect.fromLTRB(
            newR.left, 
            min(newR.bottom - minSize, newR.top + delta.dy), 
            max(newR.left + minSize, newR.right + delta.dx), 
            newR.bottom);
        break;
      case 'bottomLeft':
        newR = Rect.fromLTRB(
            min(newR.right - minSize, newR.left + delta.dx), 
            newR.top, 
            newR.right, 
            max(newR.top + minSize, newR.bottom + delta.dy));
        break;
      case 'bottomRight':
        newR = Rect.fromLTRB(
            newR.left, 
            newR.top, 
            max(newR.left + minSize, newR.right + delta.dx), 
            max(newR.top + minSize, newR.bottom + delta.dy));
        break;
      // ... Add edge centers if desired (top, bottom, left, right) ...
    }

    // Clamp to Image Bounds
    double left = max(0, newR.left);
    double top = max(0, newR.top);
    double right = min(_layoutSize!.width, newR.right);
    double bottom = min(_layoutSize!.height, newR.bottom);
    
    // Ensure width/height > min
    if (right - left < minSize) right = left + minSize;
    if (bottom - top < minSize) bottom = top + minSize;

    setState(() {
      _cropRect = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E), // Dark studio background
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20)
              ),
              child: Text("APPLY", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // 1. Calculate how to fit the image in the screen (Contain)
                double availW = constraints.maxWidth;
                double availH = constraints.maxHeight;
                double imgW = _pageImage!.width.toDouble();
                double imgH = _pageImage!.height.toDouble();
                
                double scale = min(availW / imgW, availH / imgH);
                double displayW = imgW * scale;
                double displayH = imgH * scale;

                // Center offsets
                double offX = (availW - displayW) / 2;
                double offY = (availH - displayH) / 2;

                // Update Logic State
                _layoutSize = Size(displayW, displayH);
                if (_cropRect == Rect.zero) {
                   // Initial centered square
                   double size = min(displayW, displayH) * 0.8;
                   _cropRect = Rect.fromCenter(
                     center: Offset(displayW/2, displayH/2), 
                     width: size, height: size
                   );
                }

                return Stack(
                  children: [
                    // A. Centered Image Canvas
                    Positioned(
                      left: offX, top: offY,
                      width: displayW, height: displayH,
                      child: Stack(
                        children: [
                          // 1. The Image
                          Image.memory(
                            _pageImage!.pixels,
                            width: displayW,
                            height: displayH,
                            fit: BoxFit.contain,
                          ),

                          // 2. Dark Scrim (The "Sejda" Dim Effect)
                          // We draw 4 dark rectangles around the crop box
                          // Top
                          Positioned(left: 0, top: 0, width: displayW, height: _cropRect.top, 
                            child: Container(color: Colors.black.withOpacity(0.5))),
                          // Bottom
                          Positioned(left: 0, top: _cropRect.bottom, width: displayW, height: displayH - _cropRect.bottom,
                            child: Container(color: Colors.black.withOpacity(0.5))),
                          // Left
                          Positioned(left: 0, top: _cropRect.top, width: _cropRect.left, height: _cropRect.height,
                            child: Container(color: Colors.black.withOpacity(0.5))),
                          // Right
                          Positioned(left: _cropRect.right, top: _cropRect.top, width: displayW - _cropRect.right, height: _cropRect.height,
                            child: Container(color: Colors.black.withOpacity(0.5))),

                          // 3. Crop Box & Handles
                          Positioned.fromRect(
                            rect: _cropRect,
                            child: GestureDetector(
                              onPanStart: (d) => _onPanStart(d, 'body'),
                              onPanUpdate: _onPanUpdate,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  // Transparent center to see content
                                  color: Colors.white.withOpacity(0.01), 
                                ),
                                child: Stack(
                                  children: [
                                    // Grid lines (Thirds)
                                    Column(children: [Spacer(), Divider(color: Colors.white24, height: 1), Spacer(), Divider(color: Colors.white24, height: 1), Spacer()]),
                                    Row(children: [Spacer(), VerticalDivider(color: Colors.white24, width: 1), Spacer(), VerticalDivider(color: Colors.white24, width: 1), Spacer()]),
                                    
                                    // Handles
                                    _buildHandle('topLeft', Alignment.topLeft),
                                    _buildHandle('topRight', Alignment.topRight),
                                    _buildHandle('bottomLeft', Alignment.bottomLeft),
                                    _buildHandle('bottomRight', Alignment.bottomRight),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // 4. Sejda Style Floating Info Label
                          // Positioned just above the crop rect
                          Positioned(
                            left: _cropRect.left,
                            top: max(0, _cropRect.top - 40), // Ensure it doesn't go offscreen
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "x:${(_cropRect.left).toInt()} y:${(_cropRect.top).toInt()}   w:${(_cropRect.width).toInt()} h:${(_cropRect.height).toInt()}",
                                style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildHandle(String id, Alignment align) {
    return Align(
      alignment: align,
      child: GestureDetector(
        onPanStart: (d) => _onPanStart(d, id),
        onPanUpdate: _onPanUpdate,
        child: Container(
          width: 24, height: 24, // Touch target
          color: Colors.transparent, 
          alignment: Alignment.center,
          child: Container(
            width: 12, height: 12, // Visual size
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]
            ),
          ),
        ),
      ),
    );
  }
}
