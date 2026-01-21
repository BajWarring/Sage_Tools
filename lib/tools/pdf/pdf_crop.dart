import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as vector_pdf;
import 'package:syncfusion_flutter_pdf/pdf.dart'; // Explicit import for brushes/colors
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
  PdfPageImage? _previewImage; // The "Screenshot"
  
  // Dimensions
  Size? _imageSize;     // Pixel size of the screenshot
  Size? _pdfPageSize;   // Point size of the vector page
  
  // Crop Logic
  Rect _cropRect = Rect.zero; // Coordinates relative to the _imageSize
  String _orientation = 'portrait'; // portrait | landscape
  
  // Settings
  int _selectedRatioIndex = 0;
  int _selectedUnitIndex = 1; // 0:CM, 1:Inch, 2:MM
  
  // Inputs
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  final List<String> _ratiosPortrait = ['Free', '1:1', '2:3', '3:4', '9:16'];
  final List<String> _ratiosLandscape = ['Free', '1:1', '3:2', '4:3', '16:9'];
  final List<String> _units = ['CM', 'Inch', 'MM'];

  // UX
  String _activeHandle = '';

  @override
  void initState() {
    super.initState();
    _loadPdfInfo();
  }

  Future<void> _loadPdfInfo() async {
    try {
      // 1. Get Vector Dimensions
      final bytes = File(widget.filePath).readAsBytesSync();
      final vDoc = vector_pdf.PdfDocument(inputBytes: bytes);
      final vPage = vDoc.pages[0];
      
      // Detect rotation
      int rotation = 0;
      if (vPage.rotation == PdfPageRotateAngle.rotateAngle90) rotation = 90;
      else if (vPage.rotation == PdfPageRotateAngle.rotateAngle180) rotation = 180;
      else if (vPage.rotation == PdfPageRotateAngle.rotateAngle270) rotation = 270;

      // Swap dimensions if rotated on side
      if (rotation == 90 || rotation == 270) {
        _pdfPageSize = Size(vPage.size.height, vPage.size.width);
      } else {
        _pdfPageSize = vPage.size;
      }
      
      // Set initial orientation
      _orientation = _pdfPageSize!.width > _pdfPageSize!.height ? 'landscape' : 'portrait';
      
      vDoc.dispose();

      // 2. Generate "Screenshot" (Bitmap Render)
      // We render at 72 DPI * 2 or 3 for crispness on screen
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1);
      
      // Calculate a render width that balances quality and memory (e.g., 1000px width)
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not load PDF")));
    }
  }

  // --- Logic ---

  void _updateControllers() {
    // Convert pixels to selected unit for display
    double scale = _pixelToUnitScale();
    _xCtrl.text = (_cropRect.left * scale).toStringAsFixed(2);
    _yCtrl.text = (_cropRect.top * scale).toStringAsFixed(2);
    _wCtrl.text = (_cropRect.width * scale).toStringAsFixed(2);
    _hCtrl.text = (_cropRect.height * scale).toStringAsFixed(2);
  }

  void _onInputChanged() {
    double scale = _pixelToUnitScale();
    // Prevent divide by zero
    if(scale == 0) return;

    double? x = double.tryParse(_xCtrl.text);
    double? y = double.tryParse(_yCtrl.text);
    double? w = double.tryParse(_wCtrl.text);
    double? h = double.tryParse(_hCtrl.text);

    if (x != null && y != null && w != null && h != null && _imageSize != null) {
      // Convert back to pixels
      double px = x / scale;
      double py = y / scale;
      double pw = w / scale;
      double ph = h / scale;

      setState(() {
        _cropRect = Rect.fromLTWH(px, py, pw, ph);
      });
    }
  }

  double _pixelToUnitScale() {
    if (_imageSize == null || _pdfPageSize == null) return 1.0;
    // 1. Pixels to PDF Points
    double pxToPt = _pdfPageSize!.width / _imageSize!.width;
    // 2. Points to Unit (72 points = 1 inch)
    double points = 72.0;
    
    if (_units[_selectedUnitIndex] == 'Inch') return pxToPt / 72.0;
    if (_units[_selectedUnitIndex] == 'CM') return pxToPt / 28.3465;
    if (_units[_selectedUnitIndex] == 'MM') return pxToPt / 2.83465;
    return 1.0;
  }

  void _toggleOrientation() {
    setState(() {
      _orientation = _orientation == 'portrait' ? 'landscape' : 'portrait';
      _selectedRatioIndex = 0; // Reset ratio to free/custom
    });
  }

  void _applyRatio(int index) {
    setState(() {
      _selectedRatioIndex = index;
      if (index == 0) return; // Free

      String rStr = _orientation == 'portrait' ? _ratiosPortrait[index] : _ratiosLandscape[index];
      List<String> parts = rStr.split(':');
      double rW = double.parse(parts[0]);
      double rH = double.parse(parts[1]);
      double targetRatio = rW / rH;

      // Keep width, adjust height
      double newH = _cropRect.width / targetRatio;
      
      // If fits, apply
      if (_cropRect.top + newH <= _imageSize!.height) {
        _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, _cropRect.width, newH);
      } else {
        // Fit to height, adjust width
        double newW = _cropRect.height * targetRatio;
        _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, _cropRect.height);
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

      final bytes = File(widget.filePath).readAsBytesSync();
      final vDoc = vector_pdf.PdfDocument(inputBytes: bytes);
      final vPage = vDoc.pages[0];

      // 1. Calculate Crop Rect in PDF Coordinates (Points)
      double scale = _pdfPageSize!.width / _imageSize!.width;
      
      double cX = _cropRect.left * scale;
      double cY = _cropRect.top * scale;
      double cW = _cropRect.width * scale;
      double cH = _cropRect.height * scale;

      // 2. Create Destination Document
      final newDoc = vector_pdf.PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      newDoc.pageSettings.size = Size(cW, cH);
      
      final newPage = newDoc.pages.add();

      // 3. Draw WHITE Background (Fixes missing text/transparency issues)
      newPage.graphics.drawRectangle(
        bounds: Rect.fromLTWH(0, 0, cW, cH),
        brush: vector_pdf.PdfSolidBrush(vector_pdf.PdfColor(255, 255, 255))
      );

      // 4. Draw the original content shifted
      final template = vPage.createTemplate();
      // Draw template at negative offset to shift the "view"
      newPage.graphics.drawPdfTemplate(template, Offset(-cX, -cY));

      // 5. Save
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
          content: Text("Exported to: Download/SageTools/$fileName"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: Duration(seconds: 5),
        ));
      }

    } catch (e) {
      print("Save Error: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  // --- Interaction ---
  void _onPanStart(DragStartDetails d, String handle) {
    _activeHandle = handle;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_imageSize == null) return;
    
    // Scale delta? No, LayoutBuilder coordinates usually match logical pixels
    // But our _cropRect is in "Image Pixels".
    // We need to map Screen Delta -> Image Pixels.
    // This is handled in the LayoutBuilder by calculating `renderScale`.
  }

  // --- UI Building Blocks ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    
    // Match the HTML CSS variables
    // --md-surface-container -> theme.surfaceContainer
    // --md-primary-container -> theme.primaryContainer
    
    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        title: Text("Crop PDF", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
        centerTitle: false,
        backgroundColor: theme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(icon: Icon(Icons.more_vert), onPressed: () {})
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Card 1: Controls
                  _buildCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FilledButton.icon(
                          onPressed: (){}, // Auto crop logic could go here
                          icon: Icon(Icons.auto_fix_high, size: 18),
                          label: Text("Auto crop"),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primaryContainer,
                            foregroundColor: theme.onPrimaryContainer,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _toggleOrientation,
                          child: Text(_orientation == 'portrait' ? "Portrait" : "Landscape"),
                        )
                      ],
                    )
                  ),
                  SizedBox(height: 16),

                  // Card 2: Ratios
                  _buildCard(
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _orientation == 'portrait' ? _ratiosPortrait.length : _ratiosLandscape.length,
                        separatorBuilder: (_,__) => SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          bool active = i == _selectedRatioIndex;
                          String label = _orientation == 'portrait' ? _ratiosPortrait[i] : _ratiosLandscape[i];
                          return GestureDetector(
                            onTap: () => _applyRatio(i),
                            child: Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: active ? theme.primaryContainer : theme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(label, style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: active ? theme.onPrimaryContainer : theme.onSurfaceVariant
                              )),
                            ),
                          );
                        },
                      ),
                    )
                  ),
                  SizedBox(height: 16),

                  // PREVIEW AREA
                  Container(
                    height: _orientation == 'portrait' ? 420 : 280,
                    decoration: BoxDecoration(
                      color: Color(0xFFDCDCDC), // HTML .preview color
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (_previewImage == null) return Container();
                        
                        // Calculate Aspect Fit
                        double viewW = constraints.maxWidth;
                        double viewH = constraints.maxHeight;
                        double imgW = _imageSize!.width;
                        double imgH = _imageSize!.height;
                        
                        double scale = min(viewW / imgW, viewH / imgH);
                        double displayW = imgW * scale;
                        double displayH = imgH * scale;
                        
                        // Centering
                        double offX = (viewW - displayW) / 2;
                        double offY = (viewH - displayH) / 2;

                        return GestureDetector(
                          // Simple pan logic for the crop box
                          onPanUpdate: (d) {
                            if (_activeHandle == '') return;
                            
                            // Convert Screen Delta -> Image Pixels
                            double deltaX = d.delta.dx / scale;
                            double deltaY = d.delta.dy / scale;
                            
                            setState(() {
                              Rect r = _cropRect;
                              if (_activeHandle == 'body') {
                                r = r.shift(Offset(deltaX, deltaY));
                              } else if (_activeHandle == 'br') {
                                r = Rect.fromLTRB(r.left, r.top, r.right + deltaX, r.bottom + deltaY);
                              }
                              // ... other handles omitted for brevity but logic is same
                              
                              // Clamp
                              double nLeft = max(0, r.left);
                              double nTop = max(0, r.top);
                              double nRight = min(_imageSize!.width, r.right);
                              double nBottom = min(_imageSize!.height, r.bottom);
                              
                              _cropRect = Rect.fromLTRB(nLeft, nTop, nRight, nBottom);
                              _updateControllers();
                            });
                          },
                          onPanStart: (d) => _activeHandle = 'body', // Simplification: drag whole body
                          onPanEnd: (d) => _activeHandle = '',
                          
                          child: Stack(
                            children: [
                              // 1. Image
                              Positioned(
                                left: offX, top: offY,
                                width: displayW, height: displayH,
                                child: Image.memory(
                                  _previewImage!.pixels,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // 2. Overlay
                              Positioned(
                                left: offX, top: offY,
                                width: displayW, height: displayH,
                                child: Stack(
                                  children: [
                                    // Dimmed Areas
                                    // (Simplified visual for clarity)
                                    // Top
                                    Positioned(top:0, left:0, right:0, height: _cropRect.top * scale, child: ColoredBox(color: Colors.black54)),
                                    // Bottom
                                    Positioned(bottom:0, left:0, right:0, top: (_cropRect.bottom * scale), child: ColoredBox(color: Colors.black54)),
                                    // Left
                                    Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, left:0, width: _cropRect.left*scale, child: ColoredBox(color: Colors.black54)),
                                    // Right
                                    Positioned(top: _cropRect.top*scale, bottom: (_imageSize!.height - _cropRect.bottom)*scale, right:0, left: _cropRect.right*scale, child: ColoredBox(color: Colors.black54)),
                                    
                                    // Crop Box Border
                                    Positioned(
                                      left: _cropRect.left * scale,
                                      top: _cropRect.top * scale,
                                      width: _cropRect.width * scale,
                                      height: _cropRect.height * scale,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.white, width: 2),
                                          borderRadius: BorderRadius.circular(12)
                                        ),
                                        // Corner Handle
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned(
                                              right: -10, bottom: -10,
                                              child: GestureDetector(
                                                onPanStart: (d) => _activeHandle = 'br',
                                                child: Container(
                                                  width: 30, height: 30,
                                                  decoration: BoxDecoration(
                                                    color: theme.primary,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2)
                                                  ),
                                                  child: Icon(Icons.crop_free, size: 16, color: theme.onPrimary),
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
                  SizedBox(height: 16),

                  // Card 3: Units
                  _buildCard(
                    child: Row(
                      children: List.generate(_units.length, (i) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedUnitIndex = i;
                                _updateControllers();
                              });
                            },
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedUnitIndex == i ? theme.primaryContainer : Colors.transparent,
                                border: Border.all(color: _selectedUnitIndex == i ? Colors.transparent : theme.outlineVariant),
                                borderRadius: BorderRadius.circular(20)
                              ),
                              child: Text(_units[i], style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: _selectedUnitIndex == i ? theme.onPrimaryContainer : theme.onSurface
                              )),
                            ),
                          ),
                        ),
                      )),
                    )
                  ),
                  SizedBox(height: 16),

                  // Card 4: Inputs
                  _buildCard(
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      childAspectRatio: 2.5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        _buildField("X", _xCtrl),
                        _buildField("Y", _yCtrl),
                        _buildField("Width", _wCtrl),
                        _buildField("Height", _hCtrl),
                      ],
                    )
                  )
                ],
              ),
            ),
            
            // Bottom Bar
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surfaceContainer,
                border: Border(top: BorderSide(color: theme.outlineVariant))
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _savePdf,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.onPrimary,
                  ),
                  child: Text("Export cropped PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            )
          ],
        )
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24)
      ),
      child: child,
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        SizedBox(height: 4),
        Expanded(
          child: TextField(
            controller: ctrl,
            onSubmitted: (_) => _onInputChanged(),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        )
      ],
    );
  }
}
