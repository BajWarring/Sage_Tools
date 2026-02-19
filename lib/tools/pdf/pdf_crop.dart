import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
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
  Uint8List? _highResBytes;
  Size? _imageSize;
  Size? _pageSize; // Raster pixel size of rendered preview

  Rect _cropRect = Rect.zero;
  bool _isLandscapeRatio = false;
  int _selectedRatioIndex = 0;
  bool _isRatioLocked = false;

  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  final List<Map<String, dynamic>> _ratiosPortrait = [
    {'label': 'Free', 'val': null},
    {'label': '1:1', 'val': 1.0},
    {'label': '2:3', 'val': 2 / 3},
    {'label': '3:4', 'val': 3 / 4},
    {'label': '9:16', 'val': 9 / 16},
  ];
  final List<Map<String, dynamic>> _ratiosLandscape = [
    {'label': 'Free', 'val': null},
    {'label': '1:1', 'val': 1.0},
    {'label': '3:2', 'val': 3 / 2},
    {'label': '4:3', 'val': 4 / 3},
    {'label': '16:9', 'val': 16 / 9},
  ];

  @override
  void initState() {
    super.initState();
    _loadPdfSequence();
  }

  Future<void> _loadPdfSequence() async {
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1);

      int width = (page.width * 2).toInt();
      int height = (page.height * 2).toInt();

      final pageImage = await page.render(width: width, height: height);
      final uiImage = await pageImage.createImageDetached();

      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      if (mounted) {
        setState(() {
          _previewImage = uiImage;
          _highResBytes = bytes;
          _pageSize = Size(width.toDouble(), height.toDouble());
          _imageSize = Size(width.toDouble(), height.toDouble());

          double w = width * 0.8;
          double h = height * 0.8;
          double x = (width - w) / 2;
          double y = (height - h) / 2;
          _cropRect = Rect.fromLTWH(x, y, w, h);

          _isLoading = false;
          _updateControllers();
        });
      }
    } catch (e) {
      print("Err: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
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
    if (x != null && y != null && w != null && h != null && _pageSize != null) {
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

        if (_cropRect.top + newH > _pageSize!.height) {
          double newW = _cropRect.height * ratio;
          _cropRect = Rect.fromLTWH(
              _cropRect.left, _cropRect.top, newW, _cropRect.height);
        } else {
          _cropRect =
              Rect.fromLTWH(_cropRect.left, _cropRect.top, currentW, newH);
        }
      }
      _updateControllers();
    });
  }

  // ─── SAVE LOGIC ────────────────────────────────────────────────────────────
  Future<void> _savePdf() async {
    if (_pageSize == null) return;
    setState(() => _isLoading = true);

    try {
      if (Platform.isAndroid) await Permission.storage.request();

      // 1. Load original PDF bytes
      final List<int> originalBytes =
          await File(widget.filePath).readAsBytes();
      final syncfusion.PdfDocument sourceDoc =
          syncfusion.PdfDocument(inputBytes: originalBytes);
      final syncfusion.PdfPage sourcePage = sourceDoc.pages[0];

      // 2. Scale factors: raster preview pixels → PDF points
      //    Syncfusion reports sourcePage.size in PDF points.
      //    Syncfusion uses TOP-LEFT origin for graphics (same as Flutter),
      //    so NO Y-axis flip is needed.
      final double pdfW = sourcePage.size.width;
      final double pdfH = sourcePage.size.height;
      final double rasterW = _pageSize!.width;
      final double rasterH = _pageSize!.height;

      double scaleX = pdfW / rasterW;
      double scaleY = pdfH / rasterH;

      // 3. Crop rect in PDF point space (top-left origin, no flip needed)
      double cropX = _cropRect.left * scaleX;
      double cropY = _cropRect.top * scaleY;
      double cropW = _cropRect.width * scaleX;
      double cropH = _cropRect.height * scaleY;

      // 4. Build destination document
      final syncfusion.PdfDocument destDoc = syncfusion.PdfDocument();
      destDoc.pageSettings.margins.all = 0;

      // Set page size and orientation for the new document
      // This is crucial for defining the canvas for the cropped content.
      if (cropW > cropH) {
        destDoc.pageSettings.orientation = syncfusion.PdfPageOrientation.landscape;
      } else {
        destDoc.pageSettings.orientation = syncfusion.PdfPageOrientation.portrait;
      }
      destDoc.pageSettings.size = ui.Size(cropW, cropH);

      // Add a new page to the destination document
      final syncfusion.PdfPage destPage = destDoc.pages.add();

      // 5. Create a graphics state for the destination page
      final syncfusion.PdfGraphics graphics = destPage.graphics;

      // 6. Apply the crop transformation directly to the graphics context.
      //    This ensures that only the desired region of the original page
      //    is drawn onto the new page, preserving all vector content.
      graphics.save();
      graphics.translateTransform(-cropX, -cropY);
      sourcePage.draw(graphics, Rect.fromLTWH(0, 0, pdfW, pdfH));
      graphics.restore();

      // 7. Save to file
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists())
          directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final saveDir = Directory('${directory!.path}/SageTools');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);

      final fileName =
          'Sage_Vector_Crop_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(await destDoc.save());

      sourceDoc.dispose();
      destDoc.dispose();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF cropped and saved to ${file.path}'))
        );
      }
    } catch (e) {
      print("Error saving PDF: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error saving PDF: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    _previewImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Crop PDF'),
        backgroundColor: theme.surface,
        actions: [
          IconButton(
            icon: Icon(_isRatioLocked ? Icons.lock : Icons.lock_open),
            onPressed: _toggleLockState,
            tooltip: 'Toggle Ratio Lock',
          ),
          PopupMenuButton<int>(
            icon: Icon(Icons.aspect_ratio),
            onSelected: _applyRatio,
            itemBuilder: (context) {
              var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
              return list.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, dynamic> ratio = entry.value;
                return PopupMenuItem<int>(
                  value: idx,
                  child: Text(ratio['label']),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.save),
            onPressed: _isLoading ? null : _savePdf,
            tooltip: 'Save Cropped PDF',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    boundaryMargin: EdgeInsets.all(20),
                    minScale: 0.1,
                    maxScale: 4.0,
                    child: Stack(
                      children: [
                        // PDF Preview Image
                        if (_previewImage != null)
                          CustomPaint(
                            size: _imageSize!,
                            painter: _ImagePainter(_previewImage!),
                          ),
                        // Crop Overlay
                        Positioned.fromRect(
                          rect: _cropRect,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _cropRect = _cropRect.translate(
                                    details.delta.dx,
                                    details.delta.dy);
                                _cropRect = Rect.fromLTWH(
                                  max(0, _cropRect.left),
                                  max(0, _cropRect.top),
                                  _cropRect.width,
                                  _cropRect.height,
                                );
                                _cropRect = Rect.fromLTWH(
                                  min(_cropRect.left,
                                      _imageSize!.width - _cropRect.width),
                                  min(_cropRect.top,
                                      _imageSize!.height - _cropRect.height),
                                  _cropRect.width,
                                  _cropRect.height,
                                );
                                _updateControllers();
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: theme.primary, width: 2),
                              ),
                              child: Stack(
                                children: [
                                  // Corners for resizing
                                  _buildCorner(Alignment.topLeft),
                                  _buildCorner(Alignment.topRight),
                                  _buildCorner(Alignment.bottomLeft),
                                  _buildCorner(Alignment.bottomRight),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Crop controls
                Container(
                  padding: EdgeInsets.all(16),
                  color: theme.surfaceContainer,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('X', _xCtrl)),
                          SizedBox(width: 8),
                          Expanded(child: _buildTextField('Y', _yCtrl)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('W', _wCtrl)),
                          SizedBox(width: 8),
                          Expanded(child: _buildTextField('H', _hCtrl)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (val) => _onInputChanged(),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            double newLeft = _cropRect.left;
            double newTop = _cropRect.top;
            double newWidth = _cropRect.width;
            double newHeight = _cropRect.height;

            if (alignment == Alignment.topLeft ||
                alignment == Alignment.bottomLeft) {
              newLeft += details.delta.dx;
              newWidth -= details.delta.dx;
            }
            if (alignment == Alignment.topLeft ||
                alignment == Alignment.topRight) {
              newTop += details.delta.dy;
              newHeight -= details.delta.dy;
            }
            if (alignment == Alignment.topRight ||
                alignment == Alignment.bottomRight) {
              newWidth += details.delta.dx;
            }
            if (alignment == Alignment.bottomLeft ||
                alignment == Alignment.bottomRight) {
              newHeight += details.delta.dy;
            }

            // Ensure minimum size
            newWidth = max(10, newWidth);
            newHeight = max(10, newHeight);

            // Ensure crop rect stays within image bounds
            newLeft = max(0, newLeft);
            newTop = max(0, newTop);
            if (newLeft + newWidth > _imageSize!.width) {
              newWidth = _imageSize!.width - newLeft;
            }
            if (newTop + newHeight > _imageSize!.height) {
              newHeight = _imageSize!.height - newTop;
            }

            _cropRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);

            if (_isRatioLocked) {
              var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
              double? ratio = list[_selectedRatioIndex]['val'];
              if (ratio != null) {
                if (newWidth / newHeight > ratio) {
                  newWidth = newHeight * ratio;
                } else {
                  newHeight = newWidth / ratio;
                }
                _cropRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
              }
            }

            _updateControllers();
          });
        },
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: theme.primary, // Adjust color as needed
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;

  _ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: image,
      fit: BoxFit.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
