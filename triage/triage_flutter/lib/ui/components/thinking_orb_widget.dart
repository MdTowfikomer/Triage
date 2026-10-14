import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The states of the assistant that drive the Thinking Orb animation and lighting.
enum OrbState {
  idle,
  listening,
  processing,
  success,
  permissionRequired,
  error;

  String get defaultLabel {
    switch (this) {
      case OrbState.idle:
        return 'Ready offline';
      case OrbState.listening:
        return 'Listening...';
      case OrbState.processing:
        return 'Processing...';
      case OrbState.success:
        return 'Done';
      case OrbState.permissionRequired:
        return 'Permission needed';
      case OrbState.error:
        return 'Try again';
    }
  }
}

/// A prominent, organic thinking orb widget with restrained violet light,
/// breathing, rotation, audio-reactive ripples, and flare accents.
/// Fully respects `MediaQuery.disableAnimations` for reduced motion.
class ThinkingOrbWidget extends StatefulWidget {
  final OrbState state;
  final double rmsDb; // Normalized or decibel audio input (0.0 to 10.0+)
  final double size;

  const ThinkingOrbWidget({
    super.key,
    required this.state,
    this.rmsDb = 0.0,
    this.size = 200.0,
  });

  @override
  State<ThinkingOrbWidget> createState() => _ThinkingOrbWidgetState();
}

class _ThinkingOrbWidgetState extends State<ThinkingOrbWidget>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _rotationController;
  late final AnimationController _flareController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _flareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant ThinkingOrbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      if (widget.state == OrbState.success ||
          widget.state == OrbState.permissionRequired ||
          widget.state == OrbState.error) {
        _flareController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _rotationController.dispose();
    _flareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathController,
        _rotationController,
        _flareController,
      ]),
      builder: (context, _) {
        final breath = disableAnimations ? 0.5 : _breathController.value;
        final rotation = disableAnimations
            ? 0.0
            : (widget.state == OrbState.processing
                ? _rotationController.value * 2 * math.pi * 2.5
                : _rotationController.value * 2 * math.pi);
        final flare = disableAnimations ? 0.0 : _flareController.value;

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ThinkingOrbPainter(
            state: widget.state,
            rmsDb: widget.rmsDb,
            breathProgress: breath,
            rotationAngle: rotation,
            flareProgress: flare,
            disableAnimations: disableAnimations,
          ),
        );
      },
    );
  }
}

class _ThinkingOrbPainter extends CustomPainter {
  final OrbState state;
  final double rmsDb;
  final double breathProgress;
  final double rotationAngle;
  final double flareProgress;
  final bool disableAnimations;

  _ThinkingOrbPainter({
    required this.state,
    required this.rmsDb,
    required this.breathProgress,
    required this.rotationAngle,
    required this.flareProgress,
    required this.disableAnimations,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.36;

    // Determine state accent colors
    Color coreColor = const Color(0xFF6C5CE7); // Restrained violet
    Color glowColor = const Color(0xFF8A76FF);
    Color flareColor = Colors.transparent;

    switch (state) {
      case OrbState.idle:
        coreColor = const Color(0xFF6C5CE7);
        glowColor = const Color(0xFF5E48C8).withValues(alpha: 0.35);
        break;
      case OrbState.listening:
        coreColor = const Color(0xFF8272FF);
        glowColor = const Color(0xFFA29BFE).withValues(alpha: 0.65);
        break;
      case OrbState.processing:
        coreColor = const Color(0xFF9D84FE);
        glowColor = const Color(0xFF6C5CE7).withValues(alpha: 0.8);
        break;
      case OrbState.success:
        coreColor = const Color(0xFF00CEC9); // Cyan flare
        glowColor = const Color(0xFF00B894).withValues(alpha: 0.7);
        flareColor = const Color(0xFF55EFC4);
        break;
      case OrbState.permissionRequired:
        coreColor = const Color(0xFFF39C12); // Amber warning
        glowColor = const Color(0xFFE67E22).withValues(alpha: 0.7);
        flareColor = const Color(0xFFF1C40F);
        break;
      case OrbState.error:
        coreColor = const Color(0xFFE74C3C); // Crimson / red
        glowColor = const Color(0xFFC0392B).withValues(alpha: 0.7);
        flareColor = const Color(0xFFFF7675);
        break;
    }

    // Outer subtle ambient glow
    final glowRadius = baseRadius * (1.3 + (state == OrbState.listening ? 0.15 : 0.05 * breathProgress));
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: 0.45),
          glowColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.2, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // Audio-reactive ripples while listening
    if (state == OrbState.listening && !disableAnimations) {
      final normRms = (rmsDb.clamp(0.0, 10.0) / 10.0);
      final rippleRadius = baseRadius * (1.1 + normRms * 0.45);
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + normRms * 3.0
        ..color = const Color(0xFFA29BFE).withValues(alpha: 0.5 - normRms * 0.2);
      canvas.drawCircle(center, rippleRadius, ripplePaint);

      final secondRipple = baseRadius * (1.25 + normRms * 0.6);
      final secondPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF74B9FF).withValues(alpha: 0.35);
      canvas.drawCircle(center, secondRipple, secondPaint);
    }

    // Success/amber flare wave
    if (flareProgress > 0.0 && flareProgress < 1.0 && !disableAnimations) {
      final flareRadius = baseRadius * (1.0 + flareProgress * 0.75);
      final flareAlpha = (1.0 - flareProgress).clamp(0.0, 1.0) * 0.6;
      final flarePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - flareProgress)
        ..color = flareColor.withValues(alpha: flareAlpha);
      canvas.drawCircle(center, flareRadius, flarePaint);
    }

    // Core Orb with gentle rotation gradient
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    final breathScale = disableAnimations ? 1.0 : (0.97 + 0.06 * breathProgress);
    final coreR = baseRadius * breathScale;

    final orbGradient = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.95,
      colors: [
        Color.lerp(Colors.white, coreColor, 0.4)!,
        coreColor,
        coreColor.withValues(alpha: 0.85),
        const Color(0xFF1B1429),
      ],
      stops: const [0.0, 0.45, 0.8, 1.0],
    );

    final corePaint = Paint()
      ..shader = orbGradient.createShader(Rect.fromCircle(center: Offset.zero, radius: coreR));
    canvas.drawCircle(Offset.zero, coreR, corePaint);

    // Specular inner reflection highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.45),
        radius: 0.5,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: coreR));
    canvas.drawCircle(Offset.zero, coreR, highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThinkingOrbPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.rmsDb != rmsDb ||
        oldDelegate.breathProgress != breathProgress ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.flareProgress != flareProgress ||
        oldDelegate.disableAnimations != disableAnimations;
  }
}
