import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A low-cost ASCII atmosphere. Glyph pictures and particle positions are
/// cached; each frame only translates and draws a bounded number of pictures.
class AsciiField extends StatefulWidget {
  const AsciiField({
    super.key,
    this.seed = 17,
    this.density = .58,
    this.motion = 1,
    this.maxParticles = 300,
    this.focus = const Alignment(.35, -.45),
  });

  final int seed;
  final double density;
  final double motion;
  final int maxParticles;
  final Alignment focus;

  @override
  State<AsciiField> createState() => _AsciiFieldState();
}

class _AsciiFieldState extends State<AsciiField>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!_active ||
        MediaQuery.maybeDisableAnimationsOf(context) == true ||
        widget.motion == 0) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMotion();
    });
  }

  @override
  void didUpdateWidget(covariant AsciiField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AsciiFieldPainter(
            repaint: _clock,
            seed: widget.seed,
            density: widget.density.clamp(0, 1),
            motion: MediaQuery.disableAnimationsOf(context) ? 0 : widget.motion,
            maxParticles: widget.maxParticles.clamp(0, 600),
            focus: widget.focus,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _Particle {
  const _Particle(this.x, this.y, this.depth, this.phase, this.glyph);
  final double x, y, depth, phase;
  final int glyph;
}

class _AsciiFieldPainter extends CustomPainter {
  _AsciiFieldPainter({
    required Listenable repaint,
    required this.seed,
    required this.density,
    required this.motion,
    required this.maxParticles,
    required this.focus,
  }) : _clock = repaint as AnimationController,
       super(repaint: repaint);

  final AnimationController _clock;
  final int seed, maxParticles;
  final double density, motion;
  final Alignment focus;
  Size? _lastSize;
  List<_Particle> _particles = const [];
  static final List<ui.Picture> _glyphs = _makeGlyphs();

  static List<ui.Picture> _makeGlyphs() {
    const characters = ['·', '.', ':', '+', '*', 'o', '░', '⠂', '⡀'];
    final pictures = <ui.Picture>[];
    for (var depth = 0; depth < 3; depth++) {
      for (final char in characters) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5 + depth,
              color: Color.fromARGB([46, 78, 118][depth], 243, 240, 232),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset.zero);
        pictures.add(recorder.endRecording());
      }
    }
    return pictures;
  }

  void _populate(Size size) {
    _lastSize = size;
    if (size.isEmpty) {
      _particles = const [];
      return;
    }
    final random = math.Random(seed);
    final count = math.min(
      maxParticles,
      (size.width * size.height / 900 * density).round(),
    );
    final centerX = (focus.x + 1) * size.width / 2;
    final centerY = (focus.y + 1) * size.height / 2;
    final particles = <_Particle>[];
    var attempts = 0;
    while (particles.length < count && attempts < count * 12) {
      attempts++;
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final dx = (x - centerX) / (size.width * .7);
      final dy = (y - centerY) / (size.height * .6);
      final organic =
          math.exp(-2.8 * (dx * dx + dy * dy)) *
          (.72 + .28 * math.sin(x * .018 + math.sin(y * .014) * 2));
      if (random.nextDouble() > .12 + organic * .76) continue;
      particles.add(
        _Particle(
          x,
          y,
          random.nextDouble(),
          random.nextDouble() * math.pi * 2,
          random.nextInt(9),
        ),
      );
    }
    _particles = particles;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_lastSize != size) _populate(size);
    final t = _clock.value * math.pi * 2;
    canvas.clipRect(Offset.zero & size);
    for (final particle in _particles) {
      final phase = t + particle.phase;
      final x =
          particle.x +
          math.sin(phase * .8 + particle.y * .012) *
              7 *
              motion *
              (particle.depth + .3);
      final y =
          particle.y +
          math.cos(phase + particle.x * .009) *
              10 *
              motion *
              (particle.depth + .3);
      final flicker = motion == 0 ? 0 : (math.sin(phase * 2.1) > .86 ? 1 : 0);
      final depth = particle.depth < .35
          ? 0
          : particle.depth < .76
          ? 1
          : 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.drawPicture(_glyphs[depth * 9 + ((particle.glyph + flicker) % 9)]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AsciiFieldPainter old) =>
      seed != old.seed ||
      density != old.density ||
      motion != old.motion ||
      maxParticles != old.maxParticles ||
      focus != old.focus;
}
