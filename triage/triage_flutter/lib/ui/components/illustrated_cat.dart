import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CatState {
  idle,
  listening,
  thinking,
  speaking,
  success,
  permissionRequired,
  error,
  sleeping,
}

/// A small hand-drawn character. Motion follows real assistant state only.
class IllustratedCat extends StatefulWidget {
  const IllustratedCat({super.key, required this.state, this.size = 220});
  final CatState state;
  final double size;

  @override
  State<IllustratedCat> createState() => _IllustratedCatState();
}

class _IllustratedCatState extends State<IllustratedCat>
    with TickerProviderStateMixin {
  late final AnimationController _breathClock;
  late final AnimationController _blinkClock;
  late final AnimationController _tailClock;
  late final AnimationController _wiggleClock;

  @override
  void initState() {
    super.initState();
    // Continuous gentle breathing
    _breathClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Periodic blinking (stays open most of the time, quick blink at end)
    _blinkClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    // Tail sway / wagging
    _tailClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Dynamic twitch / wiggle for thinking & listening
    _wiggleClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _breathClock.dispose();
    _blinkClock.dispose();
    _tailClock.dispose();
    _wiggleClock.dispose();
    super.dispose();
  }

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _breathClock.stop();
      _blinkClock.stop();
      _tailClock.stop();
      _wiggleClock.stop();
    } else {
      if (!_breathClock.isAnimating) _breathClock.repeat(reverse: true);
      if (!_blinkClock.isAnimating) _blinkClock.repeat();
      if (!_tailClock.isAnimating) _tailClock.repeat(reverse: true);
      if (!_wiggleClock.isAnimating) _wiggleClock.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _breathClock,
            _blinkClock,
            _tailClock,
            _wiggleClock,
          ]),
          builder: (context, _) {
            return CustomPaint(
              painter: _CatPainter(
                state: widget.state,
                breath: _breathClock.value,
                blink: _blinkClock.value,
                tail: _tailClock.value,
                wiggle: _wiggleClock.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  _CatPainter({
    required this.state,
    required this.breath,
    required this.blink,
    required this.tail,
    required this.wiggle,
  });

  final CatState state;
  final double breath; // 0.0 -> 1.0 (reverse)
  final double blink; // 0.0 -> 1.0 (loop)
  final double tail; // 0.0 -> 1.0 (reverse)
  final double wiggle; // 0.0 -> 1.0 (loop)

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 240);

    // Paints
    final bodyFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final ink = Paint()
      ..color = const Color(0xFF242521)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final thinInk = Paint()
      ..color = const Color(0xFF242521)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final blushPaint = Paint()
      ..color = const Color(0xFFFCA5A5).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final innerEarPaint = Paint()
      ..color = const Color(0xFFFFD1D1).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Breathing Bob & Scale
    final double bobY;
    final double breathScale;
    if (state == CatState.listening) {
      bobY = math.sin(wiggle * math.pi * 2) * 2.5;
      breathScale = 1.0 + math.sin(wiggle * math.pi * 2) * 0.02;
    } else if (state == CatState.thinking) {
      bobY = math.sin(wiggle * math.pi * 2) * 1.5;
      breathScale = 1.0;
    } else if (state == CatState.success) {
      bobY = -math.sin(breath * math.pi) * 3.5; // Happy upward bounce
      breathScale = 1.02;
    } else if (state == CatState.error) {
      bobY = 3.0 + math.sin(breath * math.pi) * 1.0; // Drooped posture
      breathScale = 0.98;
    } else {
      // Idle & default
      bobY = math.sin(breath * math.pi) * 2.0;
      breathScale = 1.0 + (breath * 0.015);
    }

    // Anchor around base
    canvas.translate(120, 205);
    canvas.scale(breathScale, breathScale);
    canvas.translate(-120, -205 + bobY);

    // ==========================================
    // 1. TAIL (Behind Body)
    // ==========================================
    final tailPath = Path();
    final double tailSway;
    if (state == CatState.success) {
      // Rapid happy wag
      tailSway = math.sin(wiggle * math.pi * 4) * 14.0;
    } else if (state == CatState.listening) {
      // Alert high wag
      tailSway = math.sin(wiggle * math.pi * 2) * 8.0 - 5.0;
    } else if (state == CatState.error) {
      // Down and still
      tailSway = 12.0;
    } else {
      // Relaxed idle sway
      tailSway = (tail - 0.5) * 12.0;
    }

    tailPath.moveTo(178, 191);
    tailPath.cubicTo(
      210 + tailSway,
      195,
      222 + tailSway * 1.4,
      165,
      198 + tailSway * 0.8,
      148,
    );
    canvas.drawPath(tailPath, ink..strokeWidth = 3.6);

    // ==========================================
    // 2. BODY
    // ==========================================
    final body = Path()
      ..moveTo(69, 156)
      ..quadraticBezierTo(53, 168, 61, 204)
      ..quadraticBezierTo(91, 220, 148, 207)
      ..quadraticBezierTo(184, 204, 179, 173)
      ..quadraticBezierTo(174, 154, 159, 150)
      ..close();

    // Body Fill & Stroke
    canvas.drawPath(body, bodyFill);
    canvas.drawPath(body, ink..strokeWidth = 3.2);

    // ==========================================
    // 3. HEAD & EARS
    // ==========================================
    // Head tilt for thinking / permission
    final double headTilt;
    if (state == CatState.thinking) {
      headTilt = -0.06 + math.sin(wiggle * math.pi * 2) * 0.02;
    } else if (state == CatState.permissionRequired) {
      headTilt = 0.08;
    } else {
      headTilt = 0.0;
    }

    canvas.save();
    if (headTilt != 0.0) {
      canvas.translate(120, 120);
      canvas.rotate(headTilt);
      canvas.translate(-120, -120);
    }

    // Ear tip adjustments
    double leftEarTipX = 64;
    double leftEarTipY = 54;
    double rightEarTipX = 179;
    double rightEarTipY = 53;

    if (state == CatState.listening) {
      // Perked upright & twitching
      final earTwitch = math.sin(wiggle * math.pi * 4) * 2.0;
      leftEarTipY -= 4 + earTwitch;
      rightEarTipY -= 4 - earTwitch;
    } else if (state == CatState.error) {
      // Drooped ears
      leftEarTipX -= 6;
      leftEarTipY += 8;
      rightEarTipX += 6;
      rightEarTipY += 8;
    } else if (state == CatState.permissionRequired) {
      // One ear up, one ear cocked
      leftEarTipY -= 4;
      rightEarTipX += 5;
      rightEarTipY += 6;
    }

    final head = Path()
      ..moveTo(60, 111)
      ..lineTo(leftEarTipX, leftEarTipY)
      ..quadraticBezierTo(
        leftEarTipX + 3,
        leftEarTipY - 7,
        leftEarTipX + 11,
        leftEarTipY + 2,
      )
      ..lineTo(95, 75)
      ..quadraticBezierTo(121, 67, 147, 75)
      ..lineTo(rightEarTipX - 10, rightEarTipY + 2)
      ..quadraticBezierTo(
        rightEarTipX - 2,
        rightEarTipY - 7,
        rightEarTipX,
        rightEarTipY,
      )
      ..lineTo(181, 112)
      ..quadraticBezierTo(191, 156, 153, 170)
      ..quadraticBezierTo(120, 183, 88, 169)
      ..quadraticBezierTo(49, 153, 60, 111)
      ..close();

    // Draw Head Fill & Outline
    canvas.drawPath(head, bodyFill);
    canvas.drawPath(head, ink..strokeWidth = 3.2);

    // Inner Ears
    final leftInnerEar = Path()
      ..moveTo(leftEarTipX + 8, leftEarTipY + 12)
      ..lineTo(89, 78)
      ..lineTo(76, 78)
      ..close();
    final rightInnerEar = Path()
      ..moveTo(rightEarTipX - 8, rightEarTipY + 12)
      ..lineTo(153, 78)
      ..lineTo(166, 78)
      ..close();

    canvas.drawPath(leftInnerEar, innerEarPaint);
    canvas.drawPath(rightInnerEar, innerEarPaint);

    canvas.drawPath(
      Path()
        ..moveTo(leftEarTipX + 8, leftEarTipY + 12)
        ..lineTo(89, 78)
        ..moveTo(rightEarTipX - 8, rightEarTipY + 12)
        ..lineTo(153, 78),
      thinInk,
    );

    // ==========================================
    // 4. EYES & EXPRESSIONS
    // ==========================================
    // Blink cycle: blinks when blink > 0.94
    final isBlinking =
        (state == CatState.idle ||
            state == CatState.thinking ||
            state == CatState.speaking) &&
        (blink > 0.93 && blink < 0.98);

    if (state == CatState.success) {
      // Joyful upward curved arcs ^ ^
      final happyEyes = Path()
        ..moveTo(87, 123)
        ..quadraticBezierTo(98, 109, 109, 123)
        ..moveTo(133, 123)
        ..quadraticBezierTo(144, 109, 155, 123);
      canvas.drawPath(happyEyes, ink..strokeWidth = 3.4);

      // Star sparkles next to eyes
      _drawSparkle(canvas, const Offset(74, 110), 4.5, ink);
      _drawSparkle(canvas, const Offset(168, 108), 5.5, ink);
    } else if (state == CatState.error) {
      // Pouting / squinting x . x or slanted flat brows
      final sadEyes = Path()
        ..moveTo(89, 120)
        ..lineTo(105, 126)
        ..moveTo(137, 126)
        ..lineTo(153, 120);
      canvas.drawPath(sadEyes, ink..strokeWidth = 3.2);

      // Small sweat drop
      final sweat = Path()
        ..moveTo(170, 112)
        ..quadraticBezierTo(174, 118, 172, 122)
        ..quadraticBezierTo(170, 125, 168, 122)
        ..quadraticBezierTo(166, 118, 170, 112);
      canvas.drawPath(sweat, thinInk);
    } else if (state == CatState.listening) {
      // Wide attentive circular eyes with highlights
      final leftPupil = Offset(97, 121);
      final rightPupil = Offset(145, 121);

      canvas.drawCircle(leftPupil, 5.2, Paint()..color = ink.color);
      canvas.drawCircle(rightPupil, 5.2, Paint()..color = ink.color);

      // Eye glimmer
      canvas.drawCircle(
        Offset(leftPupil.dx - 1.5, leftPupil.dy - 1.5),
        1.8,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(rightPupil.dx - 1.5, rightPupil.dy - 1.5),
        1.8,
        Paint()..color = Colors.white,
      );
    } else if (state == CatState.permissionRequired) {
      // Asymmetric curious / puzzled look: left eye wide, right eye squint
      canvas.drawCircle(const Offset(97, 120), 5.0, Paint()..color = ink.color);
      canvas.drawCircle(
        const Offset(95.5, 118.5),
        1.6,
        Paint()..color = Colors.white,
      );

      final rightSquint = Path()
        ..moveTo(137, 122)
        ..quadraticBezierTo(145, 116, 153, 122);
      canvas.drawPath(rightSquint, ink..strokeWidth = 3.0);
    } else if (state == CatState.speaking) {
      // Warm, attentive, calm expression while Gemini or TTS is speaking:
      // Natural soft open eyes with highlights and relaxed gaze (no rapid shifting)
      final leftPupil = const Offset(98, 122);
      final rightPupil = const Offset(145, 122);

      canvas.drawCircle(leftPupil, 4.4, Paint()..color = ink.color);
      canvas.drawCircle(rightPupil, 4.4, Paint()..color = ink.color);

      // Warm eye glimmers
      canvas.drawCircle(
        const Offset(96.8, 120.6),
        1.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        const Offset(143.8, 120.6),
        1.5,
        Paint()..color = Colors.white,
      );
    } else if (isBlinking) {
      // Closed line eyes during natural periodic blink
      final blinkPath = Path()
        ..moveTo(91, 122)
        ..lineTo(105, 122)
        ..moveTo(137, 122)
        ..lineTo(151, 122);
      canvas.drawPath(blinkPath, ink..strokeWidth = 2.8);
    } else {
      // Idle / Thinking default cute dots with gentle, steady look
      final double eyeShiftX = state == CatState.thinking
          ? 1.2 * math.cos(wiggle * math.pi * 2)
          : 0.0;
      final double eyeShiftY = state == CatState.thinking ? -0.8 : 0.0;

      canvas.drawCircle(
        Offset(98 + eyeShiftX, 122 + eyeShiftY),
        4.0,
        Paint()..color = ink.color,
      );
      canvas.drawCircle(
        Offset(145 + eyeShiftX, 122 + eyeShiftY),
        4.0,
        Paint()..color = ink.color,
      );

      // Glimmer
      canvas.drawCircle(
        Offset(97 + eyeShiftX, 120.5 + eyeShiftY),
        1.2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(144 + eyeShiftX, 120.5 + eyeShiftY),
        1.2,
        Paint()..color = Colors.white,
      );
    }

    // ==========================================
    // 5. NOSE, MOUTH & BLUSH CHEEKS
    // ==========================================
    // Nose
    canvas.drawOval(
      const Rect.fromLTWH(116, 136, 10, 6),
      Paint()..color = ink.color,
    );

    // Mouth
    final mouth = Path();
    if (state == CatState.success) {
      // Wide happy cat smile :3
      mouth.moveTo(121, 142);
      mouth.lineTo(121, 147);
      mouth.quadraticBezierTo(113, 155, 107, 149);
      mouth.moveTo(121, 147);
      mouth.quadraticBezierTo(129, 155, 135, 149);
      canvas.drawPath(mouth, ink..strokeWidth = 2.2);
    } else if (state == CatState.error) {
      // Small wavy pout
      mouth.moveTo(112, 149);
      mouth.quadraticBezierTo(121, 144, 130, 149);
      canvas.drawPath(mouth, ink..strokeWidth = 2.2);
    } else {
      // Classic cute closed cat mouth (w) for idle, listening, thinking, etc.
      mouth.moveTo(121, 142);
      mouth.lineTo(121, 147);
      mouth.quadraticBezierTo(114, 153, 109, 148);
      mouth.moveTo(121, 147);
      mouth.quadraticBezierTo(128, 153, 133, 148);
      canvas.drawPath(mouth, ink..strokeWidth = 2.0);
    }

    // Soft Blush Ovals
    final double blushScale = state == CatState.success ? 1.3 : 1.0;
    canvas.save();
    canvas.translate(84, 142);
    canvas.scale(blushScale, blushScale);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 11),
      blushPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(158, 142);
    canvas.scale(blushScale, blushScale);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 11),
      blushPaint,
    );
    canvas.restore();

    // Whiskers (3 on each side with subtle sway)
    final double whiskerWiggle = state == CatState.listening
        ? math.sin(wiggle * math.pi * 4) * 2.0
        : 0.0;

    final whiskers = Path()
      // Left whiskers
      ..moveTo(80, 143)
      ..lineTo(54, 138 + whiskerWiggle)
      ..moveTo(81, 149)
      ..lineTo(53, 149)
      ..moveTo(80, 155)
      ..lineTo(55, 160 - whiskerWiggle)
      // Right whiskers
      ..moveTo(162, 143)
      ..lineTo(188, 138 - whiskerWiggle)
      ..moveTo(161, 149)
      ..lineTo(189, 149)
      ..moveTo(162, 155)
      ..lineTo(187, 160 + whiskerWiggle);

    canvas.drawPath(whiskers, thinInk);

    canvas.restore(); // Restore head tilt transform

    // ==========================================
    // 6. FRONT PAWS (Tucked cute paws)
    // ==========================================
    final paws = Path()
      ..moveTo(92, 204)
      ..quadraticBezierTo(96, 194, 107, 194)
      ..lineTo(112, 204)
      ..moveTo(132, 204)
      ..lineTo(137, 194)
      ..quadraticBezierTo(148, 194, 152, 204);
    canvas.drawPath(paws, ink..strokeWidth = 2.8);

    // ==========================================
    // 7. STATE ACCESSORIES / EFFECTS
    // ==========================================
    if (state == CatState.permissionRequired) {
      // Floating question bubble with soft bounce
      final double qBounce = math.sin(wiggle * math.pi * 2) * 3.0;
      final bubbleCenter = Offset(202, 54 + qBounce);

      final bubbleFill = Paint()
        ..color = const Color(0xFFFEF3C7)
        ..style = PaintingStyle.fill;
      final bubbleStroke = Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;

      canvas.drawCircle(bubbleCenter, 14, bubbleFill);
      canvas.drawCircle(bubbleCenter, 14, bubbleStroke);

      final mark = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(
            color: Color(0xFFB45309),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      mark.paint(
        canvas,
        Offset(
          bubbleCenter.dx - mark.width / 2,
          bubbleCenter.dy - mark.height / 2,
        ),
      );
    } else if (state == CatState.thinking) {
      // Thought bubbles floating upward
      final double phaseA = (wiggle) % 1.0;
      final double phaseB = (wiggle + 0.33) % 1.0;
      final double phaseC = (wiggle + 0.66) % 1.0;

      final dotPaint = Paint()
        ..color = const Color(0xFF777971).withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(188, 80 - phaseA * 16),
        2.5 + phaseA * 1.5,
        dotPaint,
      );
      canvas.drawCircle(
        Offset(198, 68 - phaseB * 16),
        3.0 + phaseB * 1.5,
        dotPaint,
      );
      canvas.drawCircle(
        Offset(210, 52 - phaseC * 16),
        3.5 + phaseC * 1.5,
        dotPaint,
      );
    } else if (state == CatState.listening) {
      // Subtle audio wave arcs expanding gently from cat
      final double pulse = wiggle % 1.0;
      final wavePaint = Paint()
        ..color = const Color(
          0xFF242521,
        ).withValues(alpha: (1.0 - pulse) * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(
          center: const Offset(120, 125),
          width: 180 + pulse * 36,
          height: 180 + pulse * 36,
        ),
        -math.pi * 0.75,
        math.pi * 0.4,
        false,
        wavePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: const Offset(120, 125),
          width: 180 + pulse * 36,
          height: 180 + pulse * 36,
        ),
        -math.pi * 0.15,
        math.pi * 0.4,
        false,
        wavePaint,
      );
    }

    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final sparkle = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(
      sparkle,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) =>
      old.state != state ||
      old.breath != breath ||
      old.blink != blink ||
      old.tail != tail ||
      old.wiggle != wiggle;
}
