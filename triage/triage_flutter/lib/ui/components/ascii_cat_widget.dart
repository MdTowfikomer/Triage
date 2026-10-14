import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CatState {
  idle,
  listening,
  thinking,
  success,
  permissionRequired,
  error,
  sleeping,
}

/// An expressive Braille / ASCII Cat character widget.
/// Inspired by pure dot-matrix ASCII art (`cat-1.jpg`, `cat-3.jpg`, `cat-5.jpg`).
/// Renders authentic braille dot frames with fluid micro-animations (ear twitch, blink, audio speech reactivity).
class AsciiCatWidget extends StatefulWidget {
  final CatState state;
  final double rmsDb;
  final double size;

  const AsciiCatWidget({
    super.key,
    required this.state,
    this.rmsDb = -2.0,
    this.size = 180.0,
  });

  @override
  State<AsciiCatWidget> createState() => _AsciiCatWidgetState();
}

class _AsciiCatWidgetState extends State<AsciiCatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  int _blinkCounter = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _animCtrl.addListener(() {
      if (_animCtrl.value < 0.05) {
        _blinkCounter++;
      }
    });
  }

  @override
  void didUpdateWidget(covariant AsciiCatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      switch (widget.state) {
        case CatState.thinking:
          _animCtrl.duration = const Duration(milliseconds: 1000);
          _animCtrl.repeat();
          break;
        case CatState.listening:
          _animCtrl.duration = const Duration(milliseconds: 1400);
          _animCtrl.repeat();
          break;
        case CatState.sleeping:
          _animCtrl.duration = const Duration(milliseconds: 3600);
          _animCtrl.repeat();
          break;
        default:
          _animCtrl.duration = const Duration(milliseconds: 2400);
          _animCtrl.repeat();
          break;
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color _resolveThemeColor() {
    switch (widget.state) {
      case CatState.idle:
        return const Color(0xFFF4F4F5); // Crisp terminal light
      case CatState.listening:
        return const Color(0xFFBDDCA6); // Listening signal
      case CatState.thinking:
        return const Color(0xFFF3F0E8);
      case CatState.success:
        return const Color(0xFF4ADE80); // Terminal phosphor green / success
      case CatState.permissionRequired:
        return const Color(0xFFFBBF24); // Amber alert
      case CatState.error:
        return const Color(0xFFF87171); // Soft phosphor red
      case CatState.sleeping:
        return const Color(0xFF71717A); // Dim sleeping zinc
    }
  }

  String _getFrame(double progress, bool isBlinking) {
    // Braille / ASCII Art Frames
    // 1. SLEEPING CAT with z z Z animation
    if (widget.state == CatState.sleeping) {
      final zCycle = (progress * 3).floor() % 3;
      final zString = zCycle == 0 ? ' z      ' : (zCycle == 1 ? '  z Z   ' : '   Z z !');
      return '''
           $zString
      ⢀⠔⡄     ⢠⠢⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  -.-   -.-  ⢸
     ⠑⠤⣀       ⣀⠤⠊
      /  (,,) (,,)  \\
     (____.---.____)
''';
    }

    // 2. LISTENING CAT: Attentive wide eyes, twitching ears, audio-reactive mouth (o / O / ^)
    if (widget.state == CatState.listening) {
      final normalizedRms = ((widget.rmsDb + 2.0) / 10.0).clamp(0.0, 1.0);
      final mouth = normalizedRms > 0.4 ? ' ⠶ ' : (normalizedRms > 0.15 ? ' o ' : ' . ');
      final earL = progress > 0.5 ? '⡄' : '⠔';
      final earR = progress > 0.5 ? '⠢' : '⡠';
      return '''
      ⢀$earL⡄     ⢠$earR⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  (•  .  •)   ⢸
     ⡇   $mouth    ⢸
     ⠑⠤⣀  ⠓⠚⠚   ⣀⠤⠊
       /   |   |   \\
      (____|___|____)
''';
    }

    // 3. THINKING CAT: Pulsing ears, looking sideways / tilted
    if (widget.state == CatState.thinking) {
      final lookLeft = progress < 0.5;
      final eyes = lookLeft ? ' (•  .  • )' : ' ( •  .  •)';
      return '''
      ⢀⠔⡄     ⢠⠢⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  $eyes  ⢸
     ⡇    ~o~     ⢸
     ⠑⠤⣀  ⠓⠚⠚   ⣀⠤⠊
      /    | |    \\
     (____.---.____)
''';
    }

    // 4. SUCCESS CAT: Cheerful joyful eyes (^ ﻌ ^) with meow sparkles ✨
    if (widget.state == CatState.success) {
      final sparkle = progress > 0.5 ? ' ˖ ࣪⊹' : '⊹ ࣪˖ ';
      return '''
     $sparkle   MEOW!  $sparkle
      ⢀⠔⡄     ⢠⠢⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  (^  ﻌ  ^)   ⢸
     ⠑⠤⣀   ω    ⣀⠤⠊
      /   \\   /   \\
     (____.---.____)
''';
    }

    // 5. PERMISSION REQUIRED CAT: Questioning ear tilt (O . o ?)
    if (widget.state == CatState.permissionRequired) {
      return '''
            [?]
      ⢀⠔⡄     ⢠⠢⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  (O  .  o)   ⢸
     ⡇    ~?~     ⢸
     ⠑⠤⣀  ⠓⠚⠚   ⣀⠤⠊
      /    | |    \\
     (____.---.____)
''';
    }

    // 6. ERROR CAT: Sad / disappointed ears down (x . x)
    if (widget.state == CatState.error) {
      return '''
           {!}
      ⢀⠤⡀     ⢀⠤⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  (x  .  x)   ⢸
     ⡇    ~_~     ⢸
     ⠑⠤⣀       ⣀⠤⠊
      /    | |    \\
     (____.---.____)
''';
    }

    // 7. IDLE CAT: Calm breathing, occasional cute blink
    if (isBlinking) {
      return '''
      ⢀⠔⡄     ⢠⠢⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  (-  .  -)   ⢸
     ⠑⠤⣀   ω    ⣀⠤⠊
      /    | |    \\
     (____.---.____)
''';
    }

    // Standard idle observant
    final tailWag = progress > 0.5 ? ' /' : ' |';
    return '''
      ⢀⠔⡄     ⢠⠢⡀
     ⠠⠁  ⠈⠒⠒⠒⠊   ⠈⠄
     ⡇  (•  .  •)   ⢸
     ⠑⠤⣀   ω    ⣀⠤⠊
      /    | |   $tailWag
     (____.---.____)
''';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _resolveThemeColor();
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (disableAnimations) {
      final asciiArt = _getFrame(0.0, false);
      return _buildContainer(asciiArt, themeColor, 0.0);
    }

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        // Natural blink occurs every few animation cycles
        final isBlinking = (_blinkCounter % 4 == 0) && (_animCtrl.value > 0.88);
        final asciiArt = _getFrame(_animCtrl.value, isBlinking);

        // Breathing floating offset
        final bobY = math.sin(_animCtrl.value * math.pi * 2) * 3.0;

        return Transform.translate(
          offset: Offset(0, bobY),
          child: _buildContainer(asciiArt, themeColor, _animCtrl.value),
        );
      },
    );
  }

  Widget _buildContainer(String asciiArt, Color color, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111110),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: color.withValues(alpha: widget.state == CatState.idle ? 0.2 : 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ASCII Terminal Cat display
          Text(
            asciiArt,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          // Cute terminal status tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFF111110),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStateBadgeText(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStateBadgeText() {
    switch (widget.state) {
      case CatState.idle:
        return 'CAT_IDLE // PURRING';
      case CatState.listening:
        return 'CAT_LISTENING // EARS_UP';
      case CatState.thinking:
        return 'CAT_THINKING // COMPUTING';
      case CatState.success:
        return 'CAT_JOY // MISSION_DONE';
      case CatState.permissionRequired:
        return 'CAT_CURIOUS // PERMISSION_REQ';
      case CatState.error:
        return 'CAT_POUT // ACTION_BLOCKED';
      case CatState.sleeping:
        return 'CAT_ZZZ // ASLEEP';
    }
  }
}
