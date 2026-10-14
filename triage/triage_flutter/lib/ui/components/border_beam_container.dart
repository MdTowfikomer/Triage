import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A subtle, premium rotating light border beam.
/// Wraps any widget and adds a revolving perimeter glow highlight.
/// Gracefully degrades to a static subtle highlight when `MediaQuery.disableAnimations` is true.
class BorderBeamContainer extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final double borderRadius;
  final Color beamColor;
  final Color baseBorderColor;
  final Color backgroundColor;
  final Duration duration;
  final bool isActive;
  final EdgeInsetsGeometry padding;

  const BorderBeamContainer({
    super.key,
    required this.child,
    this.borderWidth = 1.5,
    this.borderRadius = 28.0,
    this.beamColor = const Color(0xFFA29BFE),
    this.baseBorderColor = const Color(0x22FFFFFF),
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.duration = const Duration(seconds: 4),
    this.isActive = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<BorderBeamContainer> createState() => _BorderBeamContainerState();
}

class _BorderBeamContainerState extends State<BorderBeamContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BorderBeamContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (!widget.isActive || disableAnimations) {
      return Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.isActive ? widget.beamColor.withValues(alpha: 0.5) : widget.baseBorderColor,
            width: widget.borderWidth,
          ),
        ),
        padding: widget.padding,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _BorderBeamPainter(
            progress: _controller.value,
            borderRadius: widget.borderRadius,
            borderWidth: widget.borderWidth,
            beamColor: widget.beamColor,
            baseBorderColor: widget.baseBorderColor,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            padding: widget.padding,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _BorderBeamPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double borderWidth;
  final Color beamColor;
  final Color baseBorderColor;

  _BorderBeamPainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    required this.beamColor,
    required this.baseBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Base subtle border
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = baseBorderColor;
    canvas.drawRRect(rrect, basePaint);

    // Revolving beam sweep gradient
    final angle = progress * 2 * math.pi;
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(angle),
      colors: [
        Colors.transparent,
        beamColor.withValues(alpha: 0.05),
        beamColor,
        beamColor.withValues(alpha: 0.2),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
    );

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 1.5
      ..shader = sweepGradient.createShader(rect);

    canvas.drawRRect(rrect, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _BorderBeamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.beamColor != beamColor ||
        oldDelegate.baseBorderColor != baseBorderColor;
  }
}
