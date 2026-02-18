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
  Size? _pageSize; // Raster pixel size of rendered preview

  Rect _cropRect = Rect.zero;
  bool _isLandscapeRatio = false;
  int _selectedRatioIndex = 0;
  bool _isRatioLocked = false;
  double _lockedRatio = 0; // stores W/H ratio when locked from current box

  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  // Prevent controller listener feedback loop when we set text programmatically
  bool _updatingControllers = false;

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

    // Fix 2: listen to every keystroke on all 4 inputs → live-update crop box
    for (final ctrl in [_xCtrl, _yCtrl, _wCtrl, _hCtrl]) {
      ctrl.addListener(_onInputChanged);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [_xCtrl, _yCtrl, _wCtrl, _hCtrl]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPdfSequence() async {
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1);

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
    _updatingControllers = true;
    _xCtrl.text = _cropRect.left.toInt().toString();
    _yCtrl.text = _cropRect.top.toInt().toString();
    _wCtrl.text = _cropRect.width.toInt().toString();
    _hCtrl.text = _cropRect.height.toInt().toString();
    _updatingControllers = false;
  }

  // Fix 2: called on every keystroke via listener
  void _onInputChanged() {
    if (_updatingControllers) return; // skip when we set text programmatically
    double? x = double.tryParse(_xCtrl.text);
    double? y = double.tryParse(_yCtrl.text);
    double? w = double.tryParse(_wCtrl.text);
    double? h = double.tryParse(_hCtrl.text);
    if (x == null || y == null || w == null || h == null) return;
    if (_pageSize == null) return;
    // Clamp to page bounds
    x = x.clamp(0, _pageSize!.width - 1);
    y = y.clamp(0, _pageSize!.height - 1);
    w = w.clamp(10, _pageSize!.width - x);
    h = h.clamp(10, _pageSize!.height - y);
    setState(() => _cropRect = Rect.fromLTWH(x!, y!, w!, h!));
  }

  // Fix 3: lock button now saves the CURRENT box ratio and locks it
  void _toggleLockState() {
    setState(() {
      if (_isRatioLocked) {
        // Unlock → free mode
        _isRatioLocked = false;
        _selectedRatioIndex = 0;
        _lockedRatio = 0;
      } else {
        // Lock current crop box ratio
        _isRatioLocked = true;
        _lockedRatio = _cropRect.width / _cropRect.height;
        // Deselect any preset ratio pill (we're using a custom ratio)
        _selectedRatioIndex = 0;
      }
    });
  }

  void _applyRatio(int index) {
    setState(() {
      var list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
      double? ratio = list[index]['val'];

      if (ratio == null) {
        _isRatioLocked = false;
        _selectedRatioIndex = 0;
        _lockedRatio = 0;
      } else {
        _isRatioLocked = true;
        _selectedRatioIndex = index;
        _lockedRatio = ratio;

        double currentW = _cropRect.width;
        double newH = currentW / ratio;

        if (_cropRect.top + newH > _pageSize!.height) {
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

  // ─── SAVE LOGIC ────────────────────────────────────────────────────────────
  Future<void> _savePdf() async {
    if (_pageSize == null) return;
    setState(() => _isLoading = true);

    try {
      if (Platform.isAndroid) await Permission.storage.request();

      // 1. Load original PDF bytes
      final List<int> originalBytes = await File(widget.filePath).readAsBytes();
      final syncfusion.PdfDocument sourceDoc =
          syncfusion.PdfDocument(inputBytes: originalBytes);
      final syncfusion.PdfPage sourcePage = sourceDoc.pages[0];

      // 2. Determine true PDF dimensions vs raster preview dimensions.
      //
      //    PROBLEM: Syncfusion may store a previously-saved landscape PDF
      //    with /Rotate=90, causing sourcePage.size to report W < H even
      //    though the page visually renders as landscape (W > H).
      //    This causes the scale factors to be computed with swapped axes,
      //    making the crop land in the wrong region.
      //
      //    DETECTION: Compare aspect ratios. If pdfW/pdfH ≈ rasterH/rasterW
      //    (i.e. they are reciprocals), the dimensions are stored rotated.
      double pdfW = sourcePage.size.width;
      double pdfH = sourcePage.size.height;
      final double rasterW = _pageSize!.width;
      final double rasterH = _pageSize!.height;

      final double pdfAspect = pdfW / pdfH;
      final double rasterAspect = rasterW / rasterH;
      final bool dimensionsSwapped =
          (pdfAspect - rasterAspect).abs() > 0.05 &&
          (pdfAspect - 1.0 / rasterAspect).abs() < 0.05;

      double scaleX, scaleY;
      if (dimensionsSwapped) {
        scaleX = pdfH / rasterW;
        scaleY = pdfW / rasterH;
      } else {
        scaleX = pdfW / rasterW;
        scaleY = pdfH / rasterH;
      }

      // 3. Crop rect in PDF point space
      double cropX = _cropRect.left * scaleX;
      double cropY = _cropRect.top * scaleY;
      double cropW = _cropRect.width * scaleX;
      double cropH = _cropRect.height * scaleY;

      // 4. Build destination document.
      //    IMPORTANT: Set orientation BEFORE size — Syncfusion silently swaps
      //    W/H to portrait order unless landscape is explicitly declared first.
      final syncfusion.PdfDocument destDoc = syncfusion.PdfDocument();
      destDoc.pageSettings.margins.all = 0;
      if (cropW > cropH) {
        destDoc.pageSettings.orientation =
            syncfusion.PdfPageOrientation.landscape;
      } else {
        destDoc.pageSettings.orientation =
            syncfusion.PdfPageOrientation.portrait;
      }
      destDoc.pageSettings.size = Size(cropW, cropH);

      // 5. Draw the source page as a vector template.
      //
      //    FIX for missing graphics (QR codes, images, shapes):
      //    createTemplate() captures vector/text content but may miss some
      //    embedded XObject images and form elements depending on Syncfusion
      //    version. The workaround is to use a PdfPageTemplate approach:
      //    draw into a fresh page using the source page's MediaBox-level
      //    graphics via a PdfTemplate created from the page, and pass the
      //    FULL source page size as the draw size parameter. This ensures
      //    Syncfusion maps ALL content streams (including image XObjects)
      //    correctly before the crop offset clips them to the dest page.
      //
      //    Passing Size(fullW, fullH) as the 3rd arg to drawPdfTemplate
      //    prevents Syncfusion's pre-clipping behaviour that silently drops
      //    content outside the dest page bounds before the offset is applied.
      final syncfusion.PdfTemplate template = sourcePage.createTemplate();
      final syncfusion.PdfPage destPage = destDoc.pages.add();

      final double templateW = dimensionsSwapped ? pdfH : pdfW;
      final double templateH = dimensionsSwapped ? pdfW : pdfH;

      destPage.graphics.drawPdfTemplate(
        template,
        Offset(-cropX, -cropY),
        Size(templateW, templateH),
      );

      // 6. Save to file
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Saved to: ${file.path}"),
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

  // ─── HANDLE DRAG ───────────────────────────────────────────────────────────
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

      // Use _lockedRatio which works for both preset ratios AND custom lock
      if (_isRatioLocked && _lockedRatio > 0) {
        final double ratio = _lockedRatio;
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
          if (pT < 0 || pB > _pageSize!.height || newL < 0 || newR > _pageSize!.width)
            return;
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
          if (pL < 0 || pR > _pageSize!.width || newT < 0 || newB > _pageSize!.height)
            return;
          newL = pL;
          newR = pR;
        }
      }

      if (newR - newL < minS || newB - newT < minS) return;
      if (newL < 0 || newT < 0 || newR > _pageSize!.width || newB > _pageSize!.height)
        return;
      _cropRect = Rect.fromLTRB(newL, newT, newR, newB);
      _updateControllers();
    });
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
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
          : Column(children: [
              // ── Top controls ────────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: panelBg,
                    border: Border(bottom: BorderSide(color: border))),
                child: Column(children: [
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
                          _lockedRatio = 0;
                        }),
                        icon: Icon(
                            _isLandscapeRatio
                                ? Icons.crop_landscape
                                : Icons.crop_portrait,
                            size: 16),
                        label:
                            Text(_isLandscapeRatio ? "Landscape" : "Portrait"),
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
                        // Lock button is "active" (highlighted) when locked
                        bool lockActive = i == 0 && _isRatioLocked;
                        String label = ratioList[i]['label'];
                        IconData? icon;
                        if (i == 0) {
                          label = "";
                          icon = _isRatioLocked ? Icons.lock : Icons.lock_open;
                        }
                        final bool highlighted = (i == 0) ? lockActive : isSelected;
                        return GestureDetector(
                          onTap: () {
                            if (i == 0)
                              _toggleLockState();
                            else
                              _applyRatio(i);
                          },
                          child: Container(
                            width: i == 0 ? 50 : null,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: highlighted ? theme.primary : panelBg,
                                border: Border.all(
                                    color: highlighted ? theme.primary : border),
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icon != null)
                                    Icon(icon,
                                        size: 16,
                                        color: highlighted
                                            ? theme.onPrimary
                                            : subText),
                                  if (label.isNotEmpty)
                                    Text(label,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: highlighted
                                                ? theme.onPrimary
                                                : subText))
                                ]),
                          ),
                        );
                      },
                    ),
                  )
                ]),
              ),

              // ── Preview canvas ──────────────────────────────────────────
              Expanded(
                child: Container(
                  color: theme.surfaceContainerHighest,
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    if (_previewImage == null) return Container();

                    double viewW = constraints.maxWidth;
                    double viewH = constraints.maxHeight;
                    double imgW = _pageSize!.width;
                    double imgH = _pageSize!.height;
                    double scale = min(viewW / imgW, viewH / imgH) * 0.9;
                    double displayW = imgW * scale;
                    double displayH = imgH * scale;
                    double offX = (viewW - displayW) / 2;
                    double offY = (viewH - displayH) / 2;

                    return Stack(children: [
                      Positioned(
                        left: offX,
                        top: offY,
                        width: displayW,
                        height: displayH,
                        child: Stack(children: [
                          Container(
                              decoration: BoxDecoration(
                                  color: panelBg,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black12, blurRadius: 10)
                                  ]),
                              child: RawImage(
                                  image: _previewImage,
                                  fit: BoxFit.contain)),
                          // Dark overlay — top
                          Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: _cropRect.top * scale,
                              child: ColoredBox(color: Colors.black54)),
                          // Dark overlay — bottom
                          Positioned(
                              top: _cropRect.bottom * scale,
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ColoredBox(color: Colors.black54)),
                          // Dark overlay — left
                          Positioned(
                              top: _cropRect.top * scale,
                              bottom:
                                  (_pageSize!.height - _cropRect.bottom) * scale,
                              left: 0,
                              width: _cropRect.left * scale,
                              child: ColoredBox(color: Colors.black54)),
                          // Dark overlay — right
                          Positioned(
                              top: _cropRect.top * scale,
                              bottom:
                                  (_pageSize!.height - _cropRect.bottom) * scale,
                              left: _cropRect.right * scale,
                              right: 0,
                              child: ColoredBox(color: Colors.black54)),
                          // Crop box body
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
                                        color: theme.primary, width: 2)),
                                child: Stack(children: [
                                  Column(children: [
                                    Spacer(),
                                    Divider(
                                        color: Colors.white30, height: 1),
                                    Spacer(),
                                    Divider(
                                        color: Colors.white30, height: 1),
                                    Spacer()
                                  ]),
                                  Row(children: [
                                    Spacer(),
                                    VerticalDivider(
                                        color: Colors.white30, width: 1),
                                    Spacer(),
                                    VerticalDivider(
                                        color: Colors.white30, width: 1),
                                    Spacer()
                                  ]),
                                ]),
                              ),
                            ),
                          ),
                          ..._buildHandles(scale, theme.primary),
                        ]),
                      )
                    ]);
                  }),
                ),
              ),

              // ── Bottom panel ────────────────────────────────────────────
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
                child: Column(children: [
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
                      icon: Icon(Icons.download_rounded, size: 20),
                      label: Text("Export PDF",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: theme.onPrimary,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                    ),
                  )
                ]),
              )
            ]),
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
                      border: Border.all(color: Colors.white, width: 2)))),
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

  Widget _buildInput(String label, TextEditingController ctrl, ColorScheme theme) {
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
                  // onSubmitted kept as fallback for keyboard "Done" button
                  onSubmitted: (_) => _onInputChanged())
            ])));
  }
}
