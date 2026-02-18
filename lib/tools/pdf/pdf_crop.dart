import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
// Hide the conflicting classes from the 'pdf' package so that
// PdfDocument and PdfPage unambiguously resolve to pdf_render's versions.
import 'package:pdf/widgets.dart' as pw hide PdfDocument, PdfPage;
import 'package:pdf_render/pdf_render.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:permission_handler/permission_handler.dart';

class PdfCropScreen extends StatefulWidget {
  final String filePath;
  const PdfCropScreen({required this.filePath, super.key});

  @override
  _PdfCropScreenState createState() => _PdfCropScreenState();
}

class _PdfCropScreenState extends State<PdfCropScreen> {
  bool _isLoading = true;
  ui.Image? _previewImage;
  Size? _pageSize;

  Rect _cropRect = Rect.zero;
  bool _isLandscapeRatio = false;
  int _selectedRatioIndex = 0;
  bool _isRatioLocked = false;
  double _lockedRatio = 0;

  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
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
      final int w = (page.width * 2).toInt();
      final int h = (page.height * 2).toInt();
      final rendered = await page.render(width: w, height: h);
      final uiImg = await rendered.createImageDetached();

      if (mounted) {
        setState(() {
          _previewImage = uiImg;
          _pageSize = Size(w.toDouble(), h.toDouble());
          final double pw = w * 0.8, ph = h * 0.8;
          _cropRect = Rect.fromLTWH((w - pw) / 2, (h - ph) / 2, pw, ph);
          _isLoading = false;
          _updateControllers();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error loading PDF: $e")));
      }
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

  void _onInputChanged() {
    if (_updatingControllers || _pageSize == null) return;
    double? x = double.tryParse(_xCtrl.text);
    double? y = double.tryParse(_yCtrl.text);
    double? w = double.tryParse(_wCtrl.text);
    double? h = double.tryParse(_hCtrl.text);
    if (x == null || y == null || w == null || h == null) return;
    x = x.clamp(0, _pageSize!.width - 1);
    y = y.clamp(0, _pageSize!.height - 1);
    w = w.clamp(10, _pageSize!.width - x);
    h = h.clamp(10, _pageSize!.height - y);
    setState(() => _cropRect = Rect.fromLTWH(x!, y!, w!, h!));
  }

  void _toggleLockState() {
    setState(() {
      if (_isRatioLocked) {
        _isRatioLocked = false;
        _selectedRatioIndex = 0;
        _lockedRatio = 0;
      } else {
        _isRatioLocked = true;
        _lockedRatio = _cropRect.width / _cropRect.height;
        _selectedRatioIndex = 0;
      }
    });
  }

  void _applyRatio(int index) {
    setState(() {
      final list = _isLandscapeRatio ? _ratiosLandscape : _ratiosPortrait;
      final double? ratio = list[index]['val'];
      if (ratio == null) {
        _isRatioLocked = false;
        _selectedRatioIndex = 0;
        _lockedRatio = 0;
      } else {
        _isRatioLocked = true;
        _selectedRatioIndex = index;
        _lockedRatio = ratio;
        final double cw = _cropRect.width;
        final double nh = cw / ratio;
        if (_cropRect.top + nh > _pageSize!.height) {
          _cropRect = Rect.fromLTWH(
              _cropRect.left, _cropRect.top, _cropRect.height * ratio, _cropRect.height);
        } else {
          _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, cw, nh);
        }
      }
      _updateControllers();
    });
  }

  Future<void> _savePdf() async {
    if (_pageSize == null) return;
    setState(() => _isLoading = true);

    try {
      if (Platform.isAndroid) await Permission.storage.request();

      const double hiResMultiplier = 4.0;
      final int hiW = (_pageSize!.width * hiResMultiplier).toInt();
      final int hiH = (_pageSize!.height * hiResMultiplier).toInt();

      final PdfDocument renderDoc = await PdfDocument.openFile(widget.filePath);
      final PdfPage renderPage = await renderDoc.getPage(1);
      final PdfPageImage hiResPageImg =
          await renderPage.render(width: hiW, height: hiH);
      final ui.Image hiResImg = await hiResPageImg.createImageDetached();

      final double scX = hiW / _pageSize!.width;
      final double scY = hiH / _pageSize!.height;

      final Rect srcRect = Rect.fromLTWH(
        _cropRect.left * scX,
        _cropRect.top * scY,
        _cropRect.width * scX,
        _cropRect.height * scY,
      );
      final int outW = srcRect.width.round().clamp(1, hiW);
      final int outH = srcRect.height.round().clamp(1, hiH);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(
          recorder, Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()));
      canvas.drawImageRect(
        hiResImg,
        srcRect,
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImg = await picture.toImage(outW, outH);

      final ByteData? byteData =
          await croppedImg.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      hiResImg.dispose();
      croppedImg.dispose();

      final List<int> origBytes = await File(widget.filePath).readAsBytes();
      final syncfusion.PdfDocument sfDoc =
          syncfusion.PdfDocument(inputBytes: origBytes);
      final double pdfW = sfDoc.pages[0].size.width;
      final double pdfH = sfDoc.pages[0].size.height;
      sfDoc.dispose();

      final double rasterAspect = _pageSize!.width / _pageSize!.height;
      final double pdfAspect = pdfW / pdfH;
      final bool swapped = (pdfAspect - rasterAspect).abs() > 0.05 &&
          (pdfAspect - 1.0 / rasterAspect).abs() < 0.05;

      final double ptScaleX =
          swapped ? pdfH / _pageSize!.width : pdfW / _pageSize!.width;
      final double ptScaleY =
          swapped ? pdfW / _pageSize!.height : pdfH / _pageSize!.height;

      final double cropPtW = _cropRect.width * ptScaleX;
      final double cropPtH = _cropRect.height * ptScaleY;

      final pw.Document outputDoc = pw.Document(compress: true);
      final pw.MemoryImage pdfImage = pw.MemoryImage(pngBytes);

      outputDoc.addPage(pw.Page(
        pageFormat: PdfPageFormat(cropPtW, cropPtH),
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Image(pdfImage, fit: pw.BoxFit.fill),
      ));

      final List<int> outputBytes = await outputDoc.save();

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final Directory saveDir = Directory('${directory!.path}/SageTools');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);

      final String fileName =
          'Sage_Crop_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(outputBytes);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Saved to: ${file.path}"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _onHandlePan(DragUpdateDetails d, String type, double scale) {
    if (_pageSize == null) return;
    final double dx = d.delta.dx / scale;
    final double dy = d.delta.dy / scale;
    setState(() {
      final Rect r = _cropRect;
      const double minS = 50.0;
      double newL = r.left, newT = r.top, newR = r.right, newB = r.bottom;

      if (type == 'body') {
        _cropRect = Rect.fromLTWH(
          (newL + dx).clamp(0, _pageSize!.width - r.width),
          (newT + dy).clamp(0, _pageSize!.height - r.height),
          r.width,
          r.height,
        );
        _updateControllers();
        return;
      }

      if (type.contains('l')) newL += dx;
      if (type.contains('r')) newR += dx;
      if (type.contains('t')) newT += dy;
      if (type.contains('b')) newB += dy;

      if (_isRatioLocked && _lockedRatio > 0) {
        final double ratio = _lockedRatio;
        final bool drivingW = type.contains('l') || type.contains('r');
        if (drivingW) {
          final double reqH = (newR - newL) / ratio;
          final double center = r.top + r.height / 2;
          final double pT = type.contains('t')
              ? newB - reqH
              : (type.contains('b') ? newT : center - reqH / 2);
          final double pB = type.contains('b')
              ? newT + reqH
              : (type.contains('t') ? newT : center + reqH / 2);
          if (pT < 0 ||
              pB > _pageSize!.height ||
              newL < 0 ||
              newR > _pageSize!.width) return;
          newT = pT;
          newB = pB;
        } else {
          final double reqW = (newB - newT) * ratio;
          final double center = r.left + r.width / 2;
          final double pL = type.contains('l')
              ? newR - reqW
              : (type.contains('r') ? newL : center - reqW / 2);
          final double pR = type.contains('r')
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
    final Color bg = theme.surface;
    final Color panelBg = theme.surfaceContainer;
    final Color border = theme.outlineVariant.withOpacity(0.2);
    final Color text = theme.onSurface;
    final Color subText = theme.onSurfaceVariant;

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
            style:
                TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: border, height: 1)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: panelBg,
                    border: Border(bottom: BorderSide(color: border))),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text("Auto Detect"),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ratioList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final bool lockActive = i == 0 && _isRatioLocked;
                        final bool isSelected =
                            i != 0 && i == _selectedRatioIndex;
                        final bool highlighted =
                            i == 0 ? lockActive : isSelected;
                        String label = ratioList[i]['label'];
                        IconData? icon;
                        if (i == 0) {
                          label = "";
                          icon =
                              _isRatioLocked ? Icons.lock : Icons.lock_open;
                        }
                        return GestureDetector(
                          onTap: () =>
                              i == 0 ? _toggleLockState() : _applyRatio(i),
                          child: Container(
                            width: i == 0 ? 50 : null,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color:
                                    highlighted ? theme.primary : panelBg,
                                border: Border.all(
                                    color: highlighted
                                        ? theme.primary
                                        : border),
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
                  ),
                ]),
              ),

              Expanded(
                child: Container(
                  color: theme.surfaceContainerHighest,
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    if (_previewImage == null) return const SizedBox.shrink();
                    final double viewW = constraints.maxWidth;
                    final double viewH = constraints.maxHeight;
                    final double imgW = _pageSize!.width;
                    final double imgH = _pageSize!.height;
                    final double scale =
                        min(viewW / imgW, viewH / imgH) * 0.9;
                    final double displayW = imgW * scale;
                    final double displayH = imgH * scale;
                    final double offX = (viewW - displayW) / 2;
                    final double offY = (viewH - displayH) / 2;

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
                                  boxShadow: const [
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
                                  const ColoredBox(color: Colors.black54)),
                          Positioned(
                              top: _cropRect.bottom * scale,
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child:
                                  const ColoredBox(color: Colors.black54)),
                          Positioned(
                              top: _cropRect.top * scale,
                              bottom: (_pageSize!.height - _cropRect.bottom) *
                                  scale,
                              left: 0,
                              width: _cropRect.left * scale,
                              child:
                                  const ColoredBox(color: Colors.black54)),
                          Positioned(
                              top: _cropRect.top * scale,
                              bottom: (_pageSize!.height - _cropRect.bottom) *
                                  scale,
                              left: _cropRect.right * scale,
                              right: 0,
                              child:
                                  const ColoredBox(color: Colors.black54)),
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
                                // Remove const: Spacer/Divider inside Column
                                // is fine without it
                                child: Stack(children: [
                                  Column(children: [
                                    const Spacer(),
                                    const Divider(
                                        color: Colors.white30, height: 1),
                                    const Spacer(),
                                    const Divider(
                                        color: Colors.white30, height: 1),
                                    const Spacer(),
                                  ]),
                                  const Row(children: [
                                    Spacer(),
                                    VerticalDivider(
                                        color: Colors.white30, width: 1),
                                    Spacer(),
                                    VerticalDivider(
                                        color: Colors.white30, width: 1),
                                    Spacer(),
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

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: panelBg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4))
                    ]),
                child: Column(children: [
                  Row(children: [
                    _buildInput('X', _xCtrl, theme),
                    const SizedBox(width: 12),
                    _buildInput('Y', _yCtrl, theme),
                    const SizedBox(width: 12),
                    _buildInput('W', _wCtrl, theme),
                    const SizedBox(width: 12),
                    _buildInput('H', _hCtrl, theme),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _savePdf,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text("Export PDF",
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
              ),
            ]),
    );
  }

  List<Widget> _buildHandles(double scale, Color color) {
    final double L = _cropRect.left * scale;
    final double T = _cropRect.top * scale;
    final double R = _cropRect.right * scale;
    final double B = _cropRect.bottom * scale;
    final double cX = L + (_cropRect.width * scale / 2);
    final double cY = T + (_cropRect.height * scale / 2);
    const double size = 30.0, dot = 12.0;

    Widget handle(double x, double y, String type) => Positioned(
          left: x - size / 2,
          top: y - size / 2,
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

    return [
      handle(L, T, 'tl'), handle(cX, T, 't'), handle(R, T, 'tr'),
      handle(L, cY, 'l'),                      handle(R, cY, 'r'),
      handle(L, B, 'bl'), handle(cX, B, 'b'), handle(R, B, 'br'),
    ];
  }

  Widget _buildInput(
      String label, TextEditingController ctrl, ColorScheme theme) {
    return Expanded(
        child: Container(
            padding: const EdgeInsets.all(8),
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
                  decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _onInputChanged())
            ])));
  }
}
