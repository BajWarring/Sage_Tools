import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white, // Setting white bg to match preview, but widget is transparent
      body: Center(
        child: PixelSortLoader(),
      ),
    ),
  ));
}

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
    // Total duration matching the CSS (2.5s)
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
        // --- THE ICON ---
        SizedBox(
          width: 120, // Scaled slightly up from SVG 100x100 logic
          height: 120,
          child: Stack(
            children: [
              // Pixel 1: Top Left (Fly in from -40, -40)
              _AnimatedPixel(
                controller: _controller,
                startOffset: const Offset(-40, -40),
                finalPosition: const Offset(30, 30),
                delay: 0.0,
              ),
              // Pixel 2: Top Right (Fly in from 40, -40)
              _AnimatedPixel(
                controller: _controller,
                startOffset: const Offset(40, -40),
                finalPosition: const Offset(54, 30), // 30 + 18 + gap(6)
                delay: 0.05,
              ),
              // Pixel 3: Bottom Left (Fly in from -40, 40)
              _AnimatedPixel(
                controller: _controller,
                startOffset: const Offset(-40, 40),
                finalPosition: const Offset(30, 54),
                delay: 0.1,
              ),
              // Pixel 4: Bottom Right (Fly in from 40, 40)
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

        // --- THE TEXT ---
        const _AnimatedLoadingText(),
      ],
    );
  }
}

class _AnimatedPixel extends StatelessWidget {
  final AnimationController controller;
  final Offset startOffset;
  final Offset finalPosition;
  final double delay; // Normalized delay (0.0 to 1.0 based on duration)

  const _AnimatedPixel({
    required this.controller,
    required this.startOffset,
    required this.finalPosition,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    // Colors from CSS
    const colorStart = Color(0xFF3B82F6); // Electric Blue
    const colorEnd = Color(0xFF1D4ED8);   // Darker Blue

    // 1. Entrance: Fly In & Scale Up (0% -> 30%)
    final enterInterval = Interval(0.0 + delay, 0.3 + delay, curve: const Cubic(0.2, 0.8, 0.2, 1.0));
    
    final Animation<Offset> translateIn = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: enterInterval));

    final Animation<double> scaleIn = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: controller, curve: enterInterval));

    final Animation<double> opacityIn = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: controller, curve: enterInterval));

    // 2. Color Shift (30% -> 70%)
    final colorInterval = Interval(0.3 + delay, 0.7 + delay, curve: Curves.easeInOut);
    final Animation<Color?> colorAnim = ColorTween(begin: colorStart, end: colorEnd)
        .animate(CurvedAnimation(parent: controller, curve: colorInterval));

    // 3. Exit: Shrink & Fade (70% -> 100%)
    final exitInterval = Interval(0.7 + delay, 1.0, curve: Curves.easeIn);
    final Animation<double> scaleOut = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: controller, curve: exitInterval));

    final Animation<double> opacityOut = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: controller, curve: exitInterval));


    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Determine current phase based on controller value
        final t = controller.value;
        
        // Calculate current state
        double currentScale = 1.0;
        double currentOpacity = 1.0;
        Offset currentOffset = Offset.zero;
        Color currentColor = colorStart;

        if (t < (0.3 + delay)) {
          // Phase 1: Entering
          currentOffset = translateIn.value;
          currentScale = scaleIn.value;
          currentOpacity = opacityIn.value;
        } else if (t < (0.7 + delay)) {
          // Phase 2: Holding & Color Shifting
          currentScale = 1.0;
          currentOpacity = 1.0;
          currentOffset = Offset.zero;
          currentColor = colorAnim.value ?? colorStart;
        } else {
          // Phase 3: Exiting
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
                  borderRadius: BorderRadius.circular(4), // rx: 2 roughly scales to 4 here
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
    // 2s cycle for dots
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
        double opacity = 0.0;

        // Logic: Appear at startInterval, stay, vanish at 0.8
        if (t >= startInterval && t < 0.8) {
          opacity = 1.0;
        } else {
          opacity = 0.0;
        }

        return Opacity(
          opacity: opacity,
          child: const Text(".", style: TextStyle(
            color: Color(0xFF3B82F6),
            fontSize: 24, // 1.5rem approx
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
            fontSize: 18, // 1.2rem approx
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5, // 0.05em approx
          ),
        ),
        // Baseline alignment for dots
        Container(
          transform: Matrix4.translationValues(2, 4, 0), // Slight nudge for alignment
          child: Row(
            children: [
              _buildDot(0.0), // d1
              _buildDot(0.1), // d2
              _buildDot(0.2), // d3
            ],
          ),
        )
      ],
    );
  }
}
