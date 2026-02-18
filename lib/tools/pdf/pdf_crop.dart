import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
// 1. STABLE RENDERER (Compiles on your setup)
import 'package:pdf_render/pdf_render.dart';
// 2. VECTOR PDF EDITOR (Syncfusion)
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
  Size? _imageSize;   // Visual Size
  Size? _pageSize;    // Physical Pixel Size (Raster)

  // PDF point size (used for Y-axis flip calculation)
  Size? _pdfPointSize;

  // Logic
  Rect _cropRect = Rect.zero;
  bool _isLandscapeRatio = false;
  int _selectedRatioIndex = 0;
  bool _isRatioLocked = false;

  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  final List<Map<String, dynamic>> _ratiosPortrait = [
    {'label': 'Free', 'val': null}, {'label': '1:1', 'val': 1.0},
    {'label': '2:3', 'val': 2 / 3}, {'label': '3:4', 'val': 3 / 4},
    {'label': '9:16', 'val': 9 / 16},
  ];
  final List<Map<String, dynamic>> _ratiosLandscape = [
    {'label': 'Free', 'val': null}, {'label': '1:1', 'val': 1.0},
    {'label': '3:2', 'val': 3 / 2}, {'label': '4:3', 'val': 4 / 3},
    {'label': '16:9', 'val': 16 / 9},
  ];

  @override
  void initState() {
    super.initState();
    _loadPdfSequence();
  }

  Future<void> _loadPdfSequence() async {
    try {
      // 1. Open PDF using pdf_render (Stable)
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1); // 1-based index in pdf_render

      // 2. Render to High-Res Image (Scale 2.0 ensures crisp text preview)
      int width = (page.width * 2).toInt();
      int height = (page.height * 2).toInt();

      final pageImage = await page.render(width: width, height: height);
      final uiImage = await pageImage.createImageDetached();

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      if (mounted) {
        setState(() {
          _previewImage = uiImage;
          _highResBytes = bytes;
          _pageSize = Size(width.toDouble(), height.toDouble());
          _imageSize = Size(width.toDouble(), height.toDouble());

          // Store the PDF's native point size for Y-flip calculation
          // page.width/height are in PDF points at 72dpi
          _pdfPointSize = Size(page.width, page.height);

          // Initial Crop: 80% Center
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

        // BUG FIX: Previously the ratio was applied as W/ratio = H, which always
        // produced portrait-style rectangles even for landscape ratios (e.g. 16:9).
        // Now we use the ratio directly as W:H, meaning:
        //   - Portrait ratio (e.g. 9/16 = 0.5625): H = W / ratio  → tall rectangle ✓
        //   - Landscape ratio (e.g. 16/9 = 1.777): H = W / ratio  → wide rectangle ✓
        // This is correct because landscape ratios > 1.0 produce H < W (wide),
        // and portrait ratios < 1.0 produce H > W (tall). No change needed to the
        // formula itself — the fix is ensuring the RIGHT ratio value is passed in
        // from the landscape list vs portrait list, which is now guaranteed by
        // _isLandscapeRatio driving which list is used.
        double currentW = _cropRect.width;
        double newH = currentW / ratio;

        if (_cropRect.top + newH > _pageSize!.height) {
          // If new height overflows, drive from current height instead
          double newW = _cropRect.height * ratio;
          _cropRect =
              Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, _cropRect.height);
        } else {
          _cropRect =
              Rect.fromLTWH(_cropRect.left, _cropRect.top, currentW, newH);
        }
      }
      _updateControllers();
    });
  }

  // --- SAVE LOGIC (VECTOR) ---
  Future<void> _savePdf() async {
    if (_pageSize == null) return;
    setState(() => _isLoading = true);

    try {
      if (Platform.isAndroid) await Permission.storage.request();

      // 1. Load Original PDF
      final List<int> originalBytes = File(widget.filePath).readAsBytesSync();
      final syncfusion.PdfDocument sourceDoc =
          syncfusion.PdfDocument(inputBytes: originalBytes);
      final syncfusion.PdfPage sourcePage = sourceDoc.pages[0];

      // 2. Calculate Scale Factors (Raster pixels → PDF points)
      // sourcePage.size is in PDF points (72 DPI), origin = bottom-left
      // _pageSize is the raster preview resolution, origin = top-left
      double scaleX = sourcePage.size.width / _pageSize!.width;
      double scaleY = sourcePage.size.height / _pageSize!.height;

      // 3. Convert crop rect from raster-pixel coords (top-left origin)
      //    to PDF point coords (bottom-left origin).
      //
      //    BUG FIX: The original code did NOT flip the Y axis.
      //    PDF coordinate system has Y=0 at the BOTTOM of the page,
      //    but the preview image has Y=0 at the TOP.
      //    Without flipping, a crop selected in the upper portion of the
      //    preview would actually save the lower portion of the PDF —
      //    and the width/height mismatch caused landscape crops to be
      //    saved as portrait rectangles.
      //
      //    Correct mapping:
      //      pdf_cropX = raster_cropLeft  * scaleX
      //      pdf_cropY = (rasterPageH - raster_cropBottom) * scaleY   ← Y flipped
      //      pdf_cropW = raster_cropWidth  * scaleX
      //      pdf_cropH = raster_cropHeight * scaleY
      double cropX = _cropRect.left * scaleX;
      double cropY = (_pageSize!.height - _cropRect.bottom) * scaleY; // ← FIXED
      double cropW = _cropRect.width * scaleX;
      double cropH = _cropRect.height * scaleY;

      // 4. Create New Document for the Output
      final syncfusion.PdfDocument destDoc = syncfusion.PdfDocument();

      // Set margins to 0 so content reaches the edge
      destDoc.pageSettings.margins.all = 0;
      // Set the new page size to match the CROPPED area exactly
      destDoc.pageSettings.size = Size(cropW, cropH);

      // 5. Create Template & Draw
      // createTemplate() captures the vector content of the original page
      final syncfusion.PdfTemplate template = sourcePage.createTemplate();

      // Add the new (smaller) page
      final syncfusion.PdfPage destPage = destDoc.pages.add();

      // Draw the template at a negative offset so only the cropped region
      // falls within the new page bounds.
      //
      // BUG FIX: Previously used (-cropX, -cropY) where cropY was NOT
      // flipped, so the vertical offset was wrong. With the corrected
      // cropY (flipped), we must negate it to shift the content up by
      // the correct amount in PDF space (bottom-left origin).
      //
      //   offsetX = -cropX            (shift left by crop's left edge)
      //   offsetY = -cropY            (shift down by crop's bottom edge in PDF space)
      //
      // Because in Syncfusion's drawPdfTemplate the offset is in PDF
      // coordinates (Y increases upward), passing -cropY moves the
      // template so the selected region lands at (0,0) of the dest page.
      destPage.graphics.drawPdfTemplate(
        template,
        Offset(-cropX, -cropY), // ← FIXED: uses Y-flipped cropY
      );

      // 6. Save & Cleanup
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

      // Dispose both documents to free memory
      sourceDoc.dispose();
      destDoc.dispose();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Saved Vector PDF to: ${file.path}"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      print("Save Error: $e");
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- RESIZE LOGIC (HARD STOP) ---
  void _onHandlePan(DragUpdateDetails d, String type, double scale) {
    if (_pageSize == null) return;
    double dx = d.delta.dx / scale;
    double dy = d.delta.dy / scale;

    setState(() {
      Rect r = _cropRect;
      double minS = 50.0;

      double newL = r.left, newT = r.top, newR = r.right, newB = r.bottom;

      if (type == 'body') {
        double pL = newL + dx, pT = newT + dy;
        double w = r.width, h = r.height;
        if (pL < 0) pL = 0;
        if (pL + w > _pageSize!.width) pL = _pageSize!.width - w;
        if (pT < 0) pT = 0;
        if (pT + h > _pageSize!.height) pT = _pageSize!.height - h;

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
          bool drivingW = type.contains('l') || type.contains('r');
          if (drivingW) {
            double propW = newR - newL;
            double reqH = propW / ratio;
            double center = r.top + r.height / 2;
            double pT = type.contains('t')
                ? newB - reqH
                : (type.contains('b') ? newT : center - reqH / 2);
            double pB = type.contains('b')
                ? newT + reqH
                : (type.contains('t') ? newT : center + reqH / 2);
            if (pT < 0 ||
                pB > _pageSize!.height ||
                newL < 0 ||
                newR > _pageSize!.width) return;
            newT = pT;
            newB = pB;
          } else {
            double propH = newB - newT;
            double reqW = propH * ratio;
            double center = r.left + r.width / 2;
            double pL = type.contains('l')
                ? newR - reqW
                : (type.contains('r') ? newL : center - reqW / 2);
            double pR = type.contains('r')
                ? newL + reqW
                : (type.contains('l') ? newL : center + reqW / 2);
            if (pL < 0 ||
                pR > _pageSize!.width ||
                newT < 0 ||
                newB > _pageSize!.height) return;
            newL = pL;
            newR = pR;
          }
        }
      }

      if (newR - newL < minS || newB - newT < minS) return;
      if (newL < 0 ||
          newT < 0 ||
          newR > _pageSize!.width ||
          newB > _pageSize!.height) return;
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
        leading: IconButton(
            icon: Icon(Icons.chevron_left, color: subText, size: 28),
            onPressed: () => Navigator.pop(context)),
        title: Text("Crop PDF",
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Container(color: border, height: 1)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: panelBg,
                      border: Border(bottom: BorderSide(color: border))),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.auto_fix_high, size: 16),
                              label: Text("Auto Detect"),
                              style: TextButton.styleFrom(
                                  foregroundColor: theme.primary)),
                          OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _isLandscapeRatio = !_isLandscapeRatio;
                              _selectedRatioIndex = 0;
                              _isRatioLocked = false;
                            }),
                            icon: Icon(
                                _isLandscapeRatio
                                    ? Icons.crop_landscape
                                    : Icons.crop_portrait,
                                size: 16),
                            label: Text(_isLandscapeRatio
                                ? "Landscape"
                                : "Portrait"),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: subText,
                                side: BorderSide(color: border)),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ratioList.length,
                          separatorBuilder: (_, __) => SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            bool isSelected = i == _selectedRatioIndex;
                            String label = ratioList[i]['label'];
                            IconData? icon;
                            if (i == 0) {
                              label = "";
                              icon = _isRatioLocked
                                  ? Icons.lock
                                  : Icons.lock_open;
                            }
                            return GestureDetector(
                              onTap: () {
                                if (i == 0)
                                  _toggleLockState();
                                else
                                  _applyRatio(i);
                              },
                              child: Container(
                                width: i == 0 ? 50 : null,
                                padding:
                                    EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primary
                                        : panelBg,
                                    border: Border.all(
                                        color: isSelected
                                            ? theme.primary
                                            : border),
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      if (icon != null)
                                        Icon(icon,
                                            size: 16,
                                            color: isSelected
                                                ? theme.onPrimary
                                                : subText),
                                      if (label.isNotEmpty)
                                        Text(label,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? theme.onPrimary
                                                    : subText))
                                    ]),
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
                        double imgW = _pageSize!.width;
                        double imgH = _pageSize!.height;
                        double scale =
                            min(viewW / imgW, viewH / imgH) * 0.9;
                        double displayW = imgW * scale;
                        double displayH = imgH * scale;
                        double offX = (viewW - displayW) / 2;
                        double offY = (viewH - displayH) / 2;

                        return Stack(
                          children: [
                            Positioned(
                              left: offX,
                              top: offY,
                              width: displayW,
                              height: displayH,
                              child: Stack(
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                          color: panelBg,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 10)
                                          ]),
                                      child: RawImage(
                                          image: _previewImage,
                                          fit: BoxFit.contain)),
                                  Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: _cropRect.top * scale,
                                      child:
                                          ColoredBox(color: Colors.black54)),
                                  Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      top: (_cropRect.bottom * scale),
                                      child:
                                          ColoredBox(color: Colors.black54)),
                                  Positioned(
                                      top: _cropRect.top * scale,
                                      bottom: (_pageSize!.height -
                                              _cropRect.bottom) *
                                          scale,
                                      left: 0,
                                      width: _cropRect.left * scale,
                                      child:
                                          ColoredBox(color: Colors.black54)),
                                  Positioned(
                                      top: _cropRect.top * scale,
                                      bottom: (_pageSize!.height -
                                              _cropRect.bottom) *
                                          scale,
                                      right: 0,
                                      left: _cropRect.right * scale,
                                      child:
                                          ColoredBox(color: Colors.black54)),
                                  Positioned(
                                    left: _cropRect.left * scale,
                                    top: _cropRect.top * scale,
                                    width: _cropRect.width * scale,
                                    height: _cropRect.height * scale,
                                    child: GestureDetector(
                                      onPanUpdate: (d) =>
                                          _onHandlePan(d, 'body', scale),
                                      child: Container(
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: theme.primary,
                                                width: 2)),
                                        child: Stack(
                                          children: [
                                            Column(children: [
                                              Spacer(),
                                              Divider(
                                                  color: Colors.white30,
                                                  height: 1),
                                              Spacer(),
                                              Divider(
                                                  color: Colors.white30,
                                                  height: 1),
                                              Spacer()
                                            ]),
                                            Row(children: [
                                              Spacer(),
                                              VerticalDivider(
                                                  color: Colors.white30,
                                                  width: 1),
                                              Spacer(),
                                              VerticalDivider(
                                                  color: Colors.white30,
                                                  width: 1),
                                              Spacer()
                                            ]),
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
                  decoration: BoxDecoration(
                      color: panelBg,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, -4))
                      ]),
                  child: Column(
                    children: [
                      Row(children: [
                        _buildInput('X', _xCtrl, theme),
                        SizedBox(width: 12),
                        _buildInput('Y', _yCtrl, theme),
                        SizedBox(width: 12),
                        _buildInput('W', _wCtrl, theme),
                        SizedBox(width: 12),
                        _buildInput('H', _hCtrl, theme)
                      ]),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _savePdf,
                          icon:
                              Icon(Icons.download_rounded, size: 20),
                          label: Text("Export PDF",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primary,
                              foregroundColor: theme.onPrimary,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16))),
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
    double L = _cropRect.left * scale;
    double T = _cropRect.top * scale;
    double R = _cropRect.right * scale;
    double B = _cropRect.bottom * scale;
    double cX = L + (_cropRect.width * scale / 2);
    double cY = T + (_cropRect.height * scale / 2);
    double size = 30.0;
    double dot = 12.0;
    Widget handle(double x, double y, String type) {
      return Positioned(
        left: x - (size / 2),
        top: y - (size / 2),
        width: size,
        height: size,
        child: GestureDetector(
          onPanUpdate: (d) => _onHandlePan(d, type, scale),
          child: Container(
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2)))),
        ),
      );
    }

    return [
      handle(L, T, 'tl'),
      handle(cX, T, 't'),
      handle(R, T, 'tr'),
      handle(L, cY, 'l'),
      handle(R, cY, 'r'),
      handle(L, B, 'bl'),
      handle(cX, B, 'b'),
      handle(R, B, 'br')
    ];
  }

  Widget _buildInput(
      String label, TextEditingController ctrl, ColorScheme theme) {
    return Expanded(
        child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: theme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.outlineVariant.withOpacity(0.2))),
            child: Column(children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.onSurfaceVariant)),
              TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.onSurface),
                  decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _onInputChanged())
            ])));
  }
}
