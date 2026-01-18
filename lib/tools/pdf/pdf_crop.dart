import 'dart:io';
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
  PdfDocument? _doc;
  PdfPageImage? _pageImage;
  Rect _cropRect = Rect.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    _doc = await PdfDocument.openFile(widget.filePath);
    final page = await _doc!.getPage(1);
    // Render high quality for preview
    final image = await page.render(width: page.width.toInt() * 2, height: page.height.toInt() * 2);
    await page.close();
    
    setState(() {
      _pageImage = image;
      _isLoading = false;
      double w = image.width.toDouble();
      double h = image.height.toDouble();
      _cropRect = Rect.fromCenter(center: Offset(w/4, h/4), width: w/3, height: h/3); 
    });
  }

  Future<void> _saveCroppedPdf(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final bytes = File(widget.filePath).readAsBytesSync();
      final vector_pdf.PdfDocument document = vector_pdf.PdfDocument(inputBytes: bytes);
      
      // Vector Crop Logic (Simplified for demo)
      Size pdfPageSize = document.pages[0].size;
      document.pages[0].cropBox = Rect.fromLTWH(0, 0, pdfPageSize.width / 2, pdfPageSize.height);

      List<int> savedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Cropped_Sage_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(savedBytes);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved: ${file.path}")));
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Crop PDF", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => _saveCroppedPdf(context),
            child: Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep image contained logic
                return Stack(
                  children: [
                    RawImage(image: _pageImage!.image, fit: BoxFit.contain),
                    // Draggable Crop Box Overlay
                    Positioned.fromRect(
                      rect: _cropRect,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() => _cropRect = _cropRect.shift(d.delta)),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.greenAccent, width: 2),
                            color: Colors.greenAccent.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }
}
