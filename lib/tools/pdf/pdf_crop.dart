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
  Rect _cropRect = Rect.zero; 
  Size? _layoutSize;          
  Size? _pdfPageSize;         
  bool _isLoading = true;
  
  // UX Interaction
  String _activeHandle = ''; 
  Offset _dragStartOffset = Offset.zero;
  Rect _initialDragRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _initSequence();
  }

  Future<void> _initSequence() async {
    // 1. Get Vector Info
    final bytes = File(widget.filePath).readAsBytesSync();
    final vectorDoc = vector_pdf.PdfDocument(inputBytes: bytes);
    final vectorPage = vectorDoc.pages[0];
    _pdfPageSize = vectorPage.size;
    vectorDoc.dispose();

    // 2. Render Bitmap Preview
    _previewDoc = await PdfDocument.openFile(widget.filePath);
    final page = await _previewDoc!.getPage(1);
    
    final image = await page.render(
      width: (page.width * 2).toInt(), 
      height: (page.height * 2).toInt()
    );

    if (mounted) {
      setState(() {
        _pageImage = image;
        _isLoading = false;
        _cropRect = Rect.zero; 
      });
    }
  }

  // --- Logic: Vector Save (Template Method) ---
  Future<void> _saveCroppedPdf() async {
    if (_layoutSize == null || _pdfPageSize == null) return;
    setState(() => _isLoading = true);

    try {
      final bytes = File(widget.filePath).readAsBytesSync();
      final loadedDoc = vector_pdf.PdfDocument(inputBytes: bytes);
      final loadedPage = loadedDoc.pages[0];

      // 1. Calculate Scale & Crop Dimensions
      double scale = _pdfPageSize!.width / _layoutSize!.width;
      
      double cropX = _cropRect.left * scale;
      double cropY = _cropRect.top * scale;
      double cropW = _cropRect.width * scale;
      double cropH = _cropRect.height * scale;

      // 2. Create NEW Document
      final newDoc = vector_pdf.PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      newDoc.pageSettings.size = Size(cropW, cropH);
      
      final newPage = newDoc.pages.add();

      // 3. Create Template & Draw Offset
      // We draw the original page at a negative offset (-x, -y).
      // This effectively "slides" the page so only the crop area is visible on the new canvas.
      final template = loadedPage.createTemplate();
      newPage.graphics.drawPdfTemplate(
        template, 
        Offset(-cropX, -cropY) 
      );

      // 4. Save
      List<int> savedBytes = await newDoc.save();
      newDoc.dispose();
      loadedDoc.dispose();

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
    if (right - left < minSize) right = left + minSize;
    if (bottom - top < minSize) bottom = top + minSize;

    setState(() => _cropRect = Rect.fromLTRB(left, top, right, bottom));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                double availW = constraints.maxWidth;
                double availH = constraints.maxHeight;
                double imgW = _pageImage!.width.toDouble();
                double imgH = _pageImage!.height.toDouble();
                double scale = min(availW / imgW, availH / imgH);
                double displayW = imgW * scale;
                double displayH = imgH * scale;
                double offX = (availW - displayW) / 2;
                double offY = (availH - displayH) / 2;

                _layoutSize = Size(displayW, displayH);
                if (_cropRect == Rect.zero) {
                   double size = min(displayW, displayH) * 0.8;
                   _cropRect = Rect.fromCenter(center: Offset(displayW/2, displayH/2), width: size, height: size);
                }

                return Stack(
                  children: [
                    Positioned(
                      left: offX, top: offY, width: displayW, height: displayH,
                      child: Stack(
                        children: [
                          Image.memory(_pageImage!.pixels, width: displayW, height: displayH, fit: BoxFit.contain),
                          Positioned(left: 0, top: 0, width: displayW, height: _cropRect.top, child: Container(color: Colors.black.withOpacity(0.5))),
                          Positioned(left: 0, top: _cropRect.bottom, width: displayW, height: displayH - _cropRect.bottom, child: Container(color: Colors.black.withOpacity(0.5))),
                          Positioned(left: 0, top: _cropRect.top, width: _cropRect.left, height: _cropRect.height, child: Container(color: Colors.black.withOpacity(0.5))),
                          Positioned(left: _cropRect.right, top: _cropRect.top, width: displayW - _cropRect.right, height: _cropRect.height, child: Container(color: Colors.black.withOpacity(0.5))),
                          
                          // Crop Box
                          Positioned.fromRect(
                            rect: _cropRect,
                            child: GestureDetector(
                              onPanStart: (d) => _onPanStart(d, 'body'),
                              onPanUpdate: _onPanUpdate,
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), color: Colors.white.withOpacity(0.01)),
                                child: Stack(
                                  children: [
                                    Column(children: [Spacer(), Divider(color: Colors.white24, height: 1), Spacer(), Divider(color: Colors.white24, height: 1), Spacer()]),
                                    Row(children: [Spacer(), VerticalDivider(color: Colors.white24, width: 1), Spacer(), VerticalDivider(color: Colors.white24, width: 1), Spacer()]),
                                    _buildHandle('topLeft', Alignment.topLeft), _buildHandle('topRight', Alignment.topRight),
                                    _buildHandle('bottomLeft', Alignment.bottomLeft), _buildHandle('bottomRight', Alignment.bottomRight),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Info Label
                          Positioned(
                            left: _cropRect.left, top: max(0, _cropRect.top - 40),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
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
    return Align(alignment: align, child: GestureDetector(
      onPanStart: (d) => _onPanStart(d, id), onPanUpdate: _onPanUpdate,
      child: Container(width: 24, height: 24, color: Colors.transparent, alignment: Alignment.center,
        child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)])),
      ),
    ));
  }
}
