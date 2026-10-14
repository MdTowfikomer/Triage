import 'dart:math' as math;
import 'package:flutter/material.dart';

enum GhostState {
  idle,
  listening,
  thinking,
  success,
  permissionRequired,
  error,
}

/// An expressive, calm Ghost Avatar that serves as the Assist hero.
/// Reacts to real-time controller states, breathing gently at idle,
/// pulsating with audio responsiveness when listening, rotating slightly during thinking,
/// and flashing cyan on success or amber on permission required.
class GhostAvatarWidget extends StatefulWidget {
  final GhostState state;
  final double rmsDb;
  final double size;

  const GhostAvatarWidget({
    super.key,
    required this.state,
    this.rmsDb = -2.0,
    this.size = 150.0,
  });

  @override
  State<GhostAvatarWidget> createState() => _GhostAvatarWidgetState();
}

class _GhostAvatarWidgetState extends State<GhostAvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GhostAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      if (widget.state == GhostState.thinking) {
        _animCtrl.duration = const Duration(milliseconds: 1400);
        _animCtrl.repeat(reverse: true);
      } else if (widget.state == GhostState.listening) {
        _animCtrl.duration = const Duration(milliseconds: 2000);
        _animCtrl.repeat(reverse: true);
      } else {
        _animCtrl.duration = const Duration(milliseconds: 3200);
        _animCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color _resolvePrimaryColor() {
    switch (widget.state) {
      case GhostState.idle:
        return const Color(0xFF8B5CF6); // Restrained violet
      case GhostState.listening:
        return const Color(0xFFA78BFA); // Bright violet
      case GhostState.thinking:
        return const Color(0xFFC4B5FD); // Lighter pulsing violet
      case GhostState.success:
        return const Color(0xFF06B6D4); // Verified cyan
      case GhostState.permissionRequired:
        return const Color(0xFFF59E0B); // Amber warning
      case GhostState.error:
        return const Color(0xFFEF4444); // Error red
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final primaryColor = _resolvePrimaryColor();

    if (disableAnimations) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _GhostPainter(
            progress: 0.5,
            rmsIntensity: 0.0,
            color: primaryColor,
            state: widget.state,
          ),
        ),
      );
    }

    final normalizedRms = ((widget.rmsDb + 2.0) / 12.0).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _GhostPainter(
              progress: _animCtrl.value,
              rmsIntensity: widget.state == GhostState.listening ? normalizedRms : 0.0,
              color: primaryColor,
              state: widget.state,
            ),
          ),
        );
      },
    );
  }
}

class _GhostPainter extends CustomPainter {
  final double progress;
  final double rmsIntensity;
  final Color color;
  final GhostState state;

  _GhostPainter({
    required this.progress,
    required this.rmsIntensity,
    required this.color,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    // Breath vertical offset
    final bobY = math.sin(progress * math.pi * 2) * 4.0;
    final scale = 1.0 + (progress * 0.03) + (rmsIntensity * 0.12);

    canvas.save();
    canvas.translate(center.dx, center.dy + bobY);
    canvas.scale(scale);

    // 1. Soft Ambient Aura Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.35 + (rmsIntensity * 0.2)),
          color.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0.2, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 1.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset.zero, radius * 1.4, glowPaint);

    // 2. Ghost Body Silhouette
    final bodyPath = Path();
    final topY = -radius * 0.9;
    final botY = radius * 0.85;

    // Dome head
    bodyPath.moveTo(-radius * 0.8, 0);
    bodyPath.cubicTo(
      -radius * 0.8,
      topY,
      radius * 0.8,
      topY,
      radius * 0.8,
      0,
    );

    // Torso sides and wavy ripples at bottom
    bodyPath.lineTo(radius * 0.8, botY - 8);
    // 3 subtle waves
    final waveW = (radius * 1.6) / 3;
    final wavePhase = progress * math.pi * 2;
    for (int i = 0; i < 3; i++) {
      final x1 = radius * 0.8 - (i * waveW);
      final x2 = x1 - (waveW / 2);
      final x3 = x1 - waveW;
      final wavePeak = botY + (math.sin(wavePhase + i) * 3.5);
      bodyPath.quadraticBezierTo(x2, wavePeak, x3, botY - 8);
    }
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.4),
        colors: [
          Colors.white,
          color.withValues(alpha: 0.85),
          color,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

    canvas.drawPath(bodyPath, bodyPaint);

    // 3. Specular rim highlight
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.7),
          color.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawPath(bodyPath, rimPaint);

    // 4. Expressive Eyes
    final eyePaint = Paint()
      ..color = const Color(0xFF18181B)
      ..style = PaintingStyle.fill;

    final eyeGlintPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final eyeSpacing = radius * 0.32;
    final eyeY = -radius * 0.15;
    final eyeRadius = radius * 0.085;

    if (state == GhostState.thinking) {
      // Slanted thinking eyes
      canvas.drawCircle(Offset(-eyeSpacing, eyeY), eyeRadius * 0.9, eyePaint);
      canvas.drawCircle(Offset(eyeSpacing, eyeY - 2), eyeRadius * 1.1, eyePaint);
    } else if (state == GhostState.success) {
      // Cheerful curved closed eyes
      final happyEyePaint = Paint()
        ..color = const Color(0xFF18181B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(-eyeSpacing, eyeY), radius: eyeRadius * 1.1),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        happyEyePaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(eyeSpacing, eyeY), radius: eyeRadius * 1.1),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        happyEyePaint,
      );
    } else {
      // Normal attentive open eyes
      canvas.drawCircle(Offset(-eyeSpacing, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(eyeSpacing, eyeY), eyeRadius, eyePaint);

      // Cute white catchlights
      canvas.drawCircle(Offset(-eyeSpacing + 1.2, eyeY - 1.2), eyeRadius * 0.35, eyeGlintPaint);
      canvas.drawCircle(Offset(eyeSpacing + 1.2, eyeY - 1.2), eyeRadius * 0.35, eyeGlintPaint);
    }

    // 5. Subtle blush spots
    final blushPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-eyeSpacing - 4, eyeY + 9), width: 8, height: 4),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(eyeSpacing + 4, eyeY + 9), width: 8, height: 4),
      blushPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GhostPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rmsIntensity != rmsIntensity ||
        oldDelegate.color != color ||
        oldDelegate.state != state;
  }
}
