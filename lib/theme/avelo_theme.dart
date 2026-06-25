import 'dart:ui';

import 'package:flutter/material.dart';

class AveloTheme extends ThemeExtension<AveloTheme> {
  final bool glass;
  final double panelOpacity;
  final double borderOpacity;
  final double blurSigma;

  const AveloTheme({
    required this.glass,
    required this.panelOpacity,
    required this.borderOpacity,
    required this.blurSigma,
  });

  static AveloTheme of(BuildContext context) {
    return Theme.of(context).extension<AveloTheme>() ??
        const AveloTheme(
          glass: false,
          panelOpacity: 0.06,
          borderOpacity: 0.0,
          blurSigma: 24,
        );
  }

  @override
  AveloTheme copyWith({
    bool? glass,
    double? panelOpacity,
    double? borderOpacity,
    double? blurSigma,
  }) {
    return AveloTheme(
      glass: glass ?? this.glass,
      panelOpacity: panelOpacity ?? this.panelOpacity,
      borderOpacity: borderOpacity ?? this.borderOpacity,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  AveloTheme lerp(ThemeExtension<AveloTheme>? other, double t) {
    if (other is! AveloTheme) return this;
    return AveloTheme(
      glass: t < 0.5 ? glass : other.glass,
      panelOpacity: lerpDouble(panelOpacity, other.panelOpacity, t) ??
          panelOpacity,
      borderOpacity: lerpDouble(borderOpacity, other.borderOpacity, t) ??
          borderOpacity,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
    );
  }
}

class AveloPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  const AveloPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AveloTheme.of(context);

    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: ext.panelOpacity),
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: ext.borderOpacity),
        ),
      ),
      child: child,
    );

    if (!ext.glass) return panel;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ext.blurSigma,
          sigmaY: ext.blurSigma,
        ),
        child: panel,
      ),
    );
  }
}

enum AveloThemeId {
  defaultTheme('default', 'Default'),
  amoled('amoled', 'Amoled (Glass)'),
  gruvbox('gruvbox', 'Gruvbox'),
  everforest('everforest', 'Everforest'),
  nord('nord', 'Nord'),
  tokyoNight('tokyo_night', 'Tokyo Night'),
  catppuccin('catppuccin', 'Catppuccin'),
  glassmorphic('glassmorphic', 'Glassmorphic'),
  liquidGlass('liquid_glass', 'Liquid Glass'),
  normal('normal', 'Normal'),
  ;

  final String id;
  final String label;
  const AveloThemeId(this.id, this.label);

  static AveloThemeId fromId(String id) {
    return AveloThemeId.values.firstWhere(
      (v) => v.id == id,
      orElse: () => AveloThemeId.defaultTheme,
    );
  }
}

class AveloThemes {
  static ThemeData build({
    required AveloThemeId themeId,
    required Color defaultAccent,
  }) {
    switch (themeId) {
      case AveloThemeId.defaultTheme:
        return _default(defaultAccent);
      case AveloThemeId.amoled:
        return _amoled(defaultAccent);
      case AveloThemeId.glassmorphic:
        return _glassmorphic(defaultAccent);
      case AveloThemeId.liquidGlass:
        return _liquidGlass(defaultAccent);
      case AveloThemeId.normal:
        return _normal(defaultAccent);
      case AveloThemeId.gruvbox:
        return _fixed(
          seed: const Color(0xFFD79921),
          secondary: const Color(0xFFB8BB26),
          background: const Color(0xFF282828),
          surface: const Color(0xFF32302F),
          error: const Color(0xFFFB4934),
        );
      case AveloThemeId.everforest:
        return _fixed(
          seed: const Color(0xFFA7C080),
          secondary: const Color(0xFFDBBC7F),
          background: const Color(0xFF2D353B),
          surface: const Color(0xFF3A454A),
          error: const Color(0xFFE67E80),
        );
      case AveloThemeId.nord:
        return _fixed(
          seed: const Color(0xFF88C0D0),
          secondary: const Color(0xFF81A1C1),
          background: const Color(0xFF2E3440),
          surface: const Color(0xFF3B4252),
          error: const Color(0xFFBF616A),
        );
      case AveloThemeId.tokyoNight:
        return _fixed(
          seed: const Color(0xFF7AA2F7),
          secondary: const Color(0xFFBB9AF7),
          background: const Color(0xFF1A1B26),
          surface: const Color(0xFF24283B),
          error: const Color(0xFFF7768E),
        );
      case AveloThemeId.catppuccin:
        return _fixed(
          seed: const Color(0xFF89B4FA),
          secondary: const Color(0xFFF5C2E7),
          background: const Color(0xFF1E1E2E),
          surface: const Color(0xFF313244),
          error: const Color(0xFFF38BA8),
        );
    }
  }

  static ThemeData _fixed({
    required Color seed,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color error,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: secondary,
      surface: surface,
      error: error,
      outline: Colors.white.withValues(alpha: 0.12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: const [
        AveloTheme(
          glass: false,
          panelOpacity: 0.06,
          borderOpacity: 0.0,
          blurSigma: 24,
        ),
      ],
    );
  }

  static ThemeData _default(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      extensions: const [
        AveloTheme(
          glass: false,
          panelOpacity: 0.06,
          borderOpacity: 0.0,
          blurSigma: 24,
        ),
      ],
    );
  }

  static ThemeData _amoled(Color accent) {
    const background = Colors.black;
    const surface = Color(0xFF0B0B0D);
    const error = Color(0xFFFB4934);

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: accent,
      surface: surface,
      error: error,
      outline: Colors.white.withValues(alpha: 0.12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dialogTheme: const DialogThemeData(backgroundColor: background),
      canvasColor: Colors.black,
      extensions: const [
        AveloTheme(
          glass: true,
          panelOpacity: 0.06,
          borderOpacity: 0.14,
          blurSigma: 26,
        ),
      ],
    );
  }

  static ThemeData _glassmorphic(Color accent) {
    const background = Color(0xFF1E1E1E);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(secondary: accent);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: const [
        AveloTheme(
          glass: true,
          panelOpacity: 0.12,
          borderOpacity: 0.25,
          blurSigma: 18,
        ),
      ],
    );
  }

  static ThemeData _liquidGlass(Color accent) {
    const background = Color(0xFF0F172A);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(secondary: accent);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: const [
        AveloTheme(
          glass: true,
          panelOpacity: 0.04,
          borderOpacity: 0.45,
          blurSigma: 38,
        ),
      ],
    );
  }

  static ThemeData _normal(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      extensions: const [
        AveloTheme(
          glass: false,
          panelOpacity: 0.08,
          borderOpacity: 0.05,
          blurSigma: 0,
        ),
      ],
    );
  }
}
