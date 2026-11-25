import 'package:material_ui/material_ui.dart';

/// The app's look: an old Bible on a reading desk. Parchment and iron-gall
/// ink by day; lamplight on dark leather by night. Burnt orange marks what can
/// be done; a rubric red, as in the old printed Bibles, marks chapter numbers
/// and the first letter of a chapter. Titles in Cinzel (Roman capitals),
/// reading in EB Garamond.
class Parchment extends ThemeExtension<Parchment> {
  const Parchment({
    required this.dark,
    required this.page,
    required this.leaf,
    required this.deep,
    required this.rule,
    required this.ink,
    required this.inkStrong,
    required this.faded,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.rubric,
    required this.gold,
    required this.grain,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final bool dark;
  final Color page; // the background
  final Color leaf; // a card, a sheet: a fresher leaf on the page
  final Color deep; // pressed into the page: fields, tracks
  final Color rule; // hairlines
  final Color ink; // reading text
  final Color inkStrong; // titles
  final Color faded; // secondary text
  final Color accent; // burnt orange: buttons, verse numbers, what's chosen
  final Color accentSoft; // a wash of it
  final Color onAccent;
  final Color rubric; // red letters: chapter numbers, drop capitals
  final Color gold;
  final Color grain; // the paper's fleck
  final Color success, warning, danger;

  static const light = Parchment(
    dark: false,
    page: Color(0xFFF3E9D7),
    leaf: Color(0xFFFAF4E8),
    deep: Color(0xFFEADCC3),
    rule: Color(0xFFD9C6A6),
    ink: Color(0xFF3B2E24),
    inkStrong: Color(0xFF2A1E15),
    faded: Color(0xFF7C6852),
    accent: Color(0xFFC0632B),
    accentSoft: Color(0xFFF2D9BF),
    onAccent: Color(0xFFFFF8EE),
    rubric: Color(0xFFA2391F),
    gold: Color(0xFFB0832C),
    grain: Color(0xFF6E4B2A),
    success: Color(0xFF5E8A4E),
    warning: Color(0xFFC98A2B),
    danger: Color(0xFFB3412E),
  );

  static const lamplight = Parchment(
    dark: true,
    page: Color(0xFF1C1611),
    leaf: Color(0xFF261E17),
    deep: Color(0xFF30261D),
    rule: Color(0xFF433628),
    ink: Color(0xFFE7DBC9),
    inkStrong: Color(0xFFF5ECDD),
    faded: Color(0xFFA6957F),
    accent: Color(0xFFE79B5D),
    accentSoft: Color(0xFF4A3220),
    onAccent: Color(0xFF1C1611),
    rubric: Color(0xFFE2805A),
    gold: Color(0xFFD8B06A),
    grain: Color(0xFFFFE9C8),
    success: Color(0xFF8DBA78),
    warning: Color(0xFFE3B25E),
    danger: Color(0xFFE07A63),
  );

  static const serif = 'EBGaramond';
  static const caps = 'Cinzel';

  /// Highlight colours, kept warm so they sit on paper.
  static const highlights = {
    'yellow': Color(0xFFF2D46B),
    'orange': Color(0xFFF0B27A),
    'pink': Color(0xFFE9AFA6),
    'green': Color(0xFFB7CF94),
    'blue': Color(0xFFA9C4D4),
  };

  static Color highlight(String name) =>
      highlights[name] ?? highlights['yellow']!;

  // Type
  TextStyle get body =>
      TextStyle(fontFamily: serif, fontSize: 17, height: 1.5, color: ink);
  TextStyle get small =>
      TextStyle(fontFamily: serif, fontSize: 14.5, height: 1.4, color: faded);
  TextStyle get strong => TextStyle(
    fontFamily: serif,
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: inkStrong,
  );
  TextStyle title([double size = 26]) => TextStyle(
    fontFamily: caps,
    fontSize: size,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: size * .02,
    color: inkStrong,
  );
  TextStyle get label => TextStyle(
    fontFamily: caps,
    fontSize: 11,
    height: 1.3,
    letterSpacing: 2.2,
    fontWeight: FontWeight.w600,
    color: faded,
  );

  ThemeData get material {
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: onAccent,
      secondary: gold,
      onSecondary: onAccent,
      error: danger,
      onError: onAccent,
      surface: page,
      onSurface: ink,
      surfaceContainerHighest: deep,
      outline: rule,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      canvasColor: page,
      fontFamily: serif,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: rule,
      extensions: [this],
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: .3),
        selectionHandleColor: accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        foregroundColor: inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: title(17),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkStrong,
        contentTextStyle: TextStyle(
          fontFamily: serif,
          fontSize: 16,
          color: page,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onAccent : faded,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : deep,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: deep,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: .15),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: deep,
        circularTrackColor: deep,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: leaf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: rule),
        ),
        titleTextStyle: title(18),
        contentTextStyle: body,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: leaf,
        modalBackgroundColor: leaf,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: leaf,
        hintStyle: TextStyle(fontFamily: serif, color: faded, fontSize: 17),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: leaf,
        dialHandColor: accent,
        hourMinuteColor: deep,
        dayPeriodColor: accentSoft,
      ),
    );
  }

  @override
  Parchment copyWith() => this;

  @override
  Parchment lerp(Parchment? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return Parchment(
      dark: t < .5 ? dark : other.dark,
      page: c(page, other.page),
      leaf: c(leaf, other.leaf),
      deep: c(deep, other.deep),
      rule: c(rule, other.rule),
      ink: c(ink, other.ink),
      inkStrong: c(inkStrong, other.inkStrong),
      faded: c(faded, other.faded),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccent: c(onAccent, other.onAccent),
      rubric: c(rubric, other.rubric),
      gold: c(gold, other.gold),
      grain: c(grain, other.grain),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
    );
  }
}

extension ParchmentContext on BuildContext {
  Parchment get parch =>
      Theme.of(this).extension<Parchment>() ?? Parchment.light;
}
