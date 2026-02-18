import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// 1. INITIALIZATION FUNCTION
// Replace the body of this function with your real startup tasks.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> initializeApp() async {
  // Run tasks concurrently where possible
  await Future.wait([
    _openDatabase(),
    _loadSettings(),
    _checkAuth(),
  ]);
}

Future<void> _openDatabase() async {
  // TODO: replace with your actual DB init, e.g. sqflite or Hive
  await Future.delayed(const Duration(milliseconds: 800));
}

Future<void> _loadSettings() async {
  // TODO: replace with SharedPreferences / Riverpod state init
  await Future.delayed(const Duration(milliseconds: 600));
}

Future<void> _checkAuth() async {
  // TODO: replace with your auth check (Firebase, JWT, etc.)
  await Future.delayed(const Duration(milliseconds: 500));
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SPLASH SCREEN
// Waits for initializeApp() and shows the animation while loading.
// Navigates to HomePage once done — no blank frame.
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Kick off initialization exactly once; the Future is stored so
  // FutureBuilder doesn't restart it on rebuilds.
  late final Future<void> _initFuture = initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        // Navigate as soon as init finishes — no extra frame needed because
        // addPostFrameCallback schedules the push after the current build.
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // Surface errors during development; swap for a proper error UI
            // in production.
            return _ErrorScreen(error: snapshot.error.toString());
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HomePage(),
                // Fade transition so there is no jarring cut.
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          });
        }

        // Keep showing the animation while loading (and briefly during the
        // post-frame navigation call).
        return const _SplashView();
      },
    );
  }
}

// Pure UI — the animation lives here, separate from navigation logic.
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double size =
                math.min(constraints.maxWidth, constraints.maxHeight) * 0.45;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: const DocDistillerLogo(),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Sage Tools',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                    letterSpacing: 1.2,
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

// ─────────────────────────────────────────────────────────────────────────────
// 3. HOME PAGE (placeholder)
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace this with your real MainScaffold / root widget.
    return const Scaffold(
      body: Center(child: Text('Home')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. ERROR SCREEN (shown only if initializeApp throws)
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Startup failed:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATION WIDGET (unchanged drawing logic)
// ─────────────────────────────────────────────────────────────────────────────
class DocDistillerLogo extends StatefulWidget {
  const DocDistillerLogo({super.key});

  @override
  State<DocDistillerLogo> createState() => _DocDistillerLogoState();
}

class _DocDistillerLogoState extends State<DocDistillerLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: FlaskPainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class FlaskPainter extends CustomPainter {
  final double progress;

  const FlaskPainter(this.progress);

  static const Color flaskStrokeColor = Color(0xFF3B82F6);
  static final Color flaskFillColor =
      const Color(0xFF1E3A8A).withOpacity(0.1);
  static const List<Color> lineColors = [
    Color(0xFF60A5FA),
    Color(0xFF93C5FD),
    Color(0xFFBFDBFE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 100.0;
    double s(double v) => v * scale;

    // Animated lines (behind flask)
    const List<double> offsets = [0.0, 0.32, 0.64];
    for (int i = 0; i < 3; i++) {
      double t = (progress + (1.0 - offsets[i])) % 1.0;

      final double currentY = 75.0 + (20.0 - 75.0) * t;
      final double currentW = 30.0 + (10.0 - 30.0) * t;
      final double currentX = 50.0 - (currentW / 2.0);

      double opacity;
      if (t < 0.2) {
        opacity = t / 0.2;
      } else if (t < 0.6) {
        opacity = 1.0;
      } else {
        opacity = 1.0 - ((t - 0.6) / 0.4);
      }

      final paint = Paint()
        ..color = lineColors[i].withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s(currentX), s(currentY), s(currentW), s(4)),
          Radius.circular(s(1)),
        ),
        paint,
      );
    }

    // Flask (on top)
    final Path flaskPath = Path()
      ..moveTo(s(42), s(15))
      ..lineTo(s(58), s(15))
      ..lineTo(s(58), s(35))
      ..lineTo(s(75), s(85))
      ..lineTo(s(25), s(85))
      ..lineTo(s(42), s(35))
      ..lineTo(s(42), s(15))
      ..close();

    canvas.drawPath(
      flaskPath,
      Paint()
        ..color = flaskFillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      flaskPath,
      Paint()
        ..color = flaskStrokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s(4)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant FlaskPainter old) => old.progress != progress;
}
