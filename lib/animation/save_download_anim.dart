import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class SavedDownloadsAnimation extends StatefulWidget {
  const SavedDownloadsAnimation({super.key});

  @override
  State<SavedDownloadsAnimation> createState() => _SavedDownloadsAnimationState();
}

class _SavedDownloadsAnimationState extends State<SavedDownloadsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _circleProgress;
  late Animation<double> _tickProgress;
  late Animation<double> _flareProgress;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _circleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Cubic(0.25, 0.46, 0.45, 0.94)),
      ),
    );

    _tickProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.375, 0.68, curve: Cubic(0.25, 0.46, 0.45, 0.94)),
      ),
    );

    _flareProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.9, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.625, 0.95, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 10), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.625, 0.95, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _IconPainter(
                  circleProgress: _circleProgress.value,
                  tickProgress: _tickProgress.value,
                  flareProgress: _flareProgress.value,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 15),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: _textSlide.value,
              child: Opacity(
                opacity: _textOpacity.value,
                child: const Text(
                  "Saved to Downloads",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _IconPainter extends CustomPainter {
  final double circleProgress;
  final double tickProgress;
  final double flareProgress;

  _IconPainter({
    required this.circleProgress,
    required this.tickProgress,
    required this.flareProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 100;

    final Paint mainPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (circleProgress > 0) {
      mainPaint.strokeWidth = 3 * scale;
      final double radius = 25 * scale;
      Path circlePath = Path();
      circlePath.addOval(Rect.fromCircle(center: center, radius: radius));
      PathMetrics metrics = circlePath.computeMetrics();
      for (PathMetric metric in metrics) {
        Path extract = metric.extractPath(0.0, metric.length * circleProgress);
        canvas.drawPath(extract, mainPaint);
      }
    }

    if (tickProgress > 0) {
      mainPaint.strokeWidth = 4 * scale;
      Path tickPath = Path();
      tickPath.moveTo(38 * scale, 50 * scale);
      tickPath.lineTo(48 * scale, 60 * scale);
      tickPath.lineTo(62 * scale, 40 * scale);
      PathMetrics metrics = tickPath.computeMetrics();
      for (PathMetric metric in metrics) {
        Path extract = metric.extractPath(0.0, metric.length * tickProgress);
        canvas.drawPath(extract, mainPaint);
      }
    }

    if (flareProgress > 0 && flareProgress < 1.0) {
      final double currentScale = lerpDouble(0.8, 1.4, flareProgress)!;
      final double currentOpacity = lerpDouble(1.0, 0.0, flareProgress)!;
      final double currentStroke = lerpDouble(3.0, 0.0, flareProgress)!;

      final Paint flarePaint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(currentOpacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = currentStroke * scale;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(currentScale);

      for (int i = 0; i < 8; i++) {
        double angle = (i * 45) * (math.pi / 180);
        double rInner = 35 * scale;
        double dx1 = rInner * math.cos(angle);
        double dy1 = rInner * math.sin(angle);
        double rOuter = 45 * scale;
        double dx2 = rOuter * math.cos(angle);
        double dy2 = rOuter * math.sin(angle);
        canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), flarePaint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.tickProgress != tickProgress ||
        oldDelegate.flareProgress != flareProgress;
  }
}
