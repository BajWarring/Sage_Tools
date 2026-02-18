import 'package:flutter/material.dart';
import 'dart:math' as math;

class PixelSortLoader extends StatefulWidget {
  const PixelSortLoader({super.key});

  @override
  State<PixelSortLoader> createState() => _PixelSortLoaderState();
}

class _PixelSortLoaderState extends State<PixelSortLoader> with TickerProviderStateMixin {
  late AnimationController _controller;

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              _AnimatedPixel(
                controller: _controller,
                startOffset: const Offset(-40, -40),
                finalPosition: const Offset(30, 30),
                delay: 0.0,
              ),
              _AnimatedPixel(
                controller: _controller,
                startOffset: const Offset(40, -40),
                finalPosition: const Offset(54, 30),
                delay: 0.05,
              ),
              _AnimatedPixel(
                controller: _controller,
                startOffset: const Offset(-40, 40),
                finalPosition: const Offset(30, 54),
                delay: 0.1,
              ),
              _AnimatedPixel(
                controller: _controller,
                startOffset: const Offset(40, 40),
                finalPosition: const Offset(54, 54),
                delay: 0.15,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _AnimatedLoadingText(),
      ],
    );
  }
}

class _AnimatedPixel extends StatelessWidget {
  final AnimationController controller;
  final Offset startOffset;
  final Offset finalPosition;
  final double delay;

  const _AnimatedPixel({
    required this.controller,
    required this.startOffset,
    required this.finalPosition,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    const colorStart = Color(0xFF3B82F6);
    const colorEnd = Color(0xFF1D4ED8);

    final enterInterval = Interval(0.0 + delay, 0.3 + delay, curve: const Cubic(0.2, 0.8, 0.2, 1.0));

    final Animation<Offset> translateIn = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: enterInterval));

    final Animation<double> scaleIn = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: controller, curve: enterInterval));

    final Animation<double> opacityIn = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: controller, curve: enterInterval));

    final colorInterval = Interval(0.3 + delay, 0.7 + delay, curve: Curves.easeInOut);
    final Animation<Color?> colorAnim = ColorTween(begin: colorStart, end: colorEnd)
        .animate(CurvedAnimation(parent: controller, curve: colorInterval));

    final exitInterval = Interval(0.7 + delay, 1.0, curve: Curves.easeIn);
    final Animation<double> scaleOut = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: controller, curve: exitInterval));

    final Animation<double> opacityOut = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: controller, curve: exitInterval));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;

        double currentScale = 1.0;
        double currentOpacity = 1.0;
        Offset currentOffset = Offset.zero;
        Color currentColor = colorStart;

        if (t < (0.3 + delay)) {
          currentOffset = translateIn.value;
          currentScale = scaleIn.value;
          currentOpacity = opacityIn.value;
        } else if (t < (0.7 + delay)) {
          currentScale = 1.0;
          currentOpacity = 1.0;
          currentOffset = Offset.zero;
          currentColor = colorAnim.value ?? colorStart;
        } else {
          currentScale = scaleOut.value;
          currentOpacity = opacityOut.value;
          currentColor = colorEnd;
        }

        return Positioned(
          left: finalPosition.dx + currentOffset.dx,
          top: finalPosition.dy + currentOffset.dy,
          child: Opacity(
            opacity: currentOpacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: currentScale,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedLoadingText extends StatefulWidget {
  const _AnimatedLoadingText();

  @override
  State<_AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<_AnimatedLoadingText> with SingleTickerProviderStateMixin {
  late AnimationController _textController;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _buildDot(double startInterval) {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        final t = _textController.value;
        double opacity = (t >= startInterval && t < 0.8) ? 1.0 : 0.0;

        return Opacity(
          opacity: opacity,
          child: const Text(".", style: TextStyle(
            color: Color(0xFF3B82F6),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          )),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          "COMPRESSING",
          style: TextStyle(
            color: Color(0xFF3B82F6),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        Container(
          transform: Matrix4.translationValues(2, 4, 0),
          child: Row(
            children: [
              _buildDot(0.0),
              _buildDot(0.1),
              _buildDot(0.2),
            ],
          ),
        )
      ],
    );
  }
}
