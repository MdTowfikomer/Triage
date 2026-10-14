import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Libraries.dev Voice effect inspired listening sheet.
/// When listening begins, shows live transcript and centered glow blooming from bottom edge.
/// During parsing/execution, collapses into a traveling beam.
class VoiceGlowSheet extends StatefulWidget {
  final Stream<double> rmsStream;
  final String transcript;
  final bool isExecuting;
  final VoidCallback onCancel;

  const VoiceGlowSheet({
    super.key,
    required this.rmsStream,
    required this.transcript,
    required this.isExecuting,
    required this.onCancel,
  });

  @override
  State<VoiceGlowSheet> createState() => _VoiceGlowSheetState();
}

class _VoiceGlowSheetState extends State<VoiceGlowSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  double _currentRms = 0.0;
  double _smoothedLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    widget.rmsStream.listen((rms) {
      if (!mounted) return;
      // Map Android rmsDb (-2 to 10) to calibrated 0.0 to 1.0 with noise gate
      final raw = ((rms + 2.0) / 12.0).clamp(0.0, 1.0);
      final gated = raw < 0.08 ? 0.0 : raw;
      setState(() {
        _currentRms = gated;
        // Attack/release smoothing: fast attack, slower decay
        if (_currentRms > _smoothedLevel) {
          _smoothedLevel = _smoothedLevel * 0.4 + _currentRms * 0.6;
        } else {
          _smoothedLevel = _smoothedLevel * 0.85 + _currentRms * 0.15;
        }
      });
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B), // zinc-900 surface
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top grab handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Transcript & Mode Header with ASCII cat
            Row(
              children: [
                const Text(
                  '(=^･ω･^=)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFA78BFA),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isExecuting ? 'CAT_COMPUTING // PROCESSING' : 'CAT_LISTENING // AUDIO_ACTIVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: widget.isExecuting ? const Color(0xFF22D3EE) : const Color(0xFFA78BFA),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: widget.onCancel,
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live recognized transcript text with ASCII terminal prompt
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '> ',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFA78BFA),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.transcript.isEmpty ? 'Say a command... "Call Ammi" or "Turn on DND"' : widget.transcript,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: widget.transcript.isEmpty ? Colors.white38 : Colors.white,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: widget.transcript.isEmpty ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Libraries.dev Voice Glow effect blooming from bottom
            SizedBox(
              height: 56,
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _VoiceGlowPainter(
                      progress: _animCtrl.value,
                      level: _smoothedLevel,
                      isExecuting: widget.isExecuting,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceGlowPainter extends CustomPainter {
  final double progress;
  final double level;
  final bool isExecuting;

  _VoiceGlowPainter({
    required this.progress,
    required this.level,
    required this.isExecuting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isExecuting) {
      // Traveling collapsed beam during processing
      final beamX = (progress * (w + 100)) - 50;
      final beamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF06B6D4).withValues(alpha: 0.8),
            const Color(0xFF22D3EE),
            const Color(0xFF06B6D4).withValues(alpha: 0.8),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(beamX - 60, h - 8, 120, 8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(beamX - 60, h - 6, 120, 4), const Radius.circular(2)),
        beamPaint,
      );
      return;
    }

    // Blooming Voice Glow from bottom center
    final centerX = w / 2;
    final bloomRadius = 80.0 + (level * 180.0);
    final glowAlpha = (0.3 + (level * 0.65)).clamp(0.0, 1.0);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 1.0),
        radius: 1.0,
        colors: [
          const Color(0xFFA78BFA).withValues(alpha: glowAlpha),
          const Color(0xFF7C3AED).withValues(alpha: glowAlpha * 0.6),
          const Color(0xFF4C1D95).withValues(alpha: glowAlpha * 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(centerX, h), radius: bloomRadius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(Offset(centerX, h), bloomRadius, glowPaint);

    // Multi-point audio wave line at bottom rim
    final wavePaint = Paint()
      ..color = const Color(0xFFDDD6FE).withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, h);
    const steps = 30;
    for (int i = 0; i <= steps; i++) {
      final x = (w / steps) * i;
      final distFromCenter = 1.0 - ((x - centerX).abs() / (w / 2)).clamp(0.0, 1.0);
      final waveOffset = math.sin((progress * math.pi * 4) + (i * 0.4)) * (level * 14.0 * distFromCenter);
      path.lineTo(x, h - 2 - waveOffset);
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _VoiceGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.level != level ||
        oldDelegate.isExecuting != isExecuting;
  }
}
