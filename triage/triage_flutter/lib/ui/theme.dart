import 'package:flutter/material.dart';

abstract final class TriageColors {
  static const obsidian = Color(0xFF0B0F17),
      slate = Color(0xFF121824),
      line = Color(0xFF1E2638);
  static const white = Color(0xFFF1F5F9),
      muted = Color(0xFF94A3B8),
      dim = Color(0xFF64748B);
  static const blue = Color(0xFF3B82F6),
      green = Color(0xFF10B981),
      amber = Color(0xFFF59E0B),
      violet = Color(0xFF8B5CF6),
      gold = Color(0xFFEAB308),
      red = Color(0xFFEF4444);
  static const canvas = obsidian,
      surface = slate,
      border = line,
      text = white,
      secondary = muted;
  static Color category(String type) => switch (type) {
    'note' => green,
    'reminder' => amber,
    'shopping' => violet,
    'idea' => gold,
    _ => blue,
  };
  static Color tint(String type) => switch (type) {
    'note' => const Color(0xFF132E27),
    'reminder' => const Color(0xFF2A1B0E),
    'shopping' => const Color(0xFF1E1638),
    'idea' => const Color(0xFF2B1F08),
    _ => const Color(0xFF1E293B),
  };
}

abstract final class UiTokens {
  static const inputRadius = 6.0,
      cardRadius = 10.0,
      modalRadius = 14.0,
      pillRadius = 999.0;
  static const fast = Duration(milliseconds: 120),
      normal = Duration(milliseconds: 200),
      entry = Duration(milliseconds: 280);
  static const ease = Curves.easeOutCubic;
  static const numbers = [FontFeature.tabularFigures()];
  static const floatingShadow = [
    BoxShadow(color: Color(0x55000000), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static Duration motion(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

ThemeData triageTheme() => ThemeData(
  useMaterial3: false,
  brightness: Brightness.dark,
  fontFamily: 'Inter',
  fontFamilyFallback: const ['TriageEmoji'],
  scaffoldBackgroundColor: TriageColors.canvas,
  canvasColor: TriageColors.surface,
  colorScheme: const ColorScheme.dark(
    primary: TriageColors.white,
    secondary: TriageColors.blue,
    surface: TriageColors.surface,
    error: TriageColors.red,
  ),
  splashFactory: NoSplash.splashFactory,
  dividerColor: TriageColors.border,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: TriageColors.white, fontSize: 14, height: 1.5),
    bodySmall: TextStyle(color: TriageColors.muted, fontSize: 12, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: TriageColors.canvas,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    hintStyle: const TextStyle(color: TriageColors.dim, fontSize: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UiTokens.inputRadius),
      borderSide: const BorderSide(color: TriageColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UiTokens.inputRadius),
      borderSide: const BorderSide(color: TriageColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UiTokens.inputRadius),
      borderSide: const BorderSide(color: TriageColors.muted),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UiTokens.inputRadius),
      borderSide: const BorderSide(color: TriageColors.red),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: TriageColors.white,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: TriageColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: TriageColors.border),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? TriageColors.white
          : Colors.transparent,
    ),
    checkColor: const WidgetStatePropertyAll(TriageColors.canvas),
    side: const BorderSide(color: TriageColors.dim),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
);

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label, {
    super.key,
    this.onPressed,
    this.primary = false,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary, busy;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy ? null : onPressed,
    style: TextButton.styleFrom(
      backgroundColor: primary ? TriageColors.white : Colors.transparent,
      foregroundColor: primary ? TriageColors.canvas : TriageColors.white,
      disabledForegroundColor: TriageColors.muted,
      side: BorderSide(
        color: primary ? TriageColors.white : TriageColors.border,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: TriageColors.muted,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 16),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class CategoryPill extends StatelessWidget {
  const CategoryPill(this.type, {super.key});
  final String type;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: TriageColors.tint(type),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      switch (type) {
        'task' => 'Task',
        'note' => 'Note',
        'reminder' => 'Reminder',
        'shopping' => 'Shopping',
        'idea' => 'Idea',
        _ => 'Choose category',
      },
      style: TextStyle(
        color: TriageColors.category(type),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.graphic_eq, size: 22, color: TriageColors.white),
      SizedBox(width: 10),
      Text(
        'Triage',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -.5,
        ),
      ),
    ],
  );
}
