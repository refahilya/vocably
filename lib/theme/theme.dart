import 'package:flutter/material.dart';

/// Vocably design system: the single source of truth for colors, type,
/// spacing, radii and component theming (`CLAUDE.md` §5, `DESIGN_REFERENCE.md`
/// §1–§2).
///
/// The direction is a student's exercise book: a navy cover, cool paper
/// pages, and one highlighter ("stabilo") that marks what matters. The
/// highlighter is the only loud element, so it stays reserved for the current
/// focus (target words, the active step, the active destination).
///
/// `theme.dart` stays the single file for design-system code. Layout tokens
/// that widgets need at build time live in `widgets/app_layout.dart`.
abstract final class AppFonts {
  /// Interface text: labels, buttons, forms. Plus Jakarta Sans, designed by
  /// Indonesian foundry Tokotype.
  static const String ui = 'PlusJakartaSans';

  /// Reading text: stories, headwords, page titles. Literata was drawn for
  /// long-form reading on screens.
  static const String reading = 'Literata';
}

abstract final class AppColors {
  /// The navy cover: app bar, primary buttons, stepper band, selected state.
  static const Color primary = Color(0xFF1B1F5C);

  /// Darker navy for the wide-layout navigation spine.
  static const Color primaryDeep = Color(0xFF14173F);

  /// Lightest navy tint: answered states, student chat bubbles.
  static const Color primaryTint = Color(0xFFE8EAF6);

  /// Second navy tint, for filled-but-quiet surfaces such as reached levels.
  static const Color primaryTintStrong = Color(0xFFCFD3EC);

  /// The highlighter. Ink text only on top of it, never white.
  static const Color marker = Color(0xFFFFCF56);

  /// Pale highlighter wash for quiet emphasis.
  static const Color markerSoft = Color(0xFFFFF1C9);

  /// AI avatar on navy-free surfaces.
  static const Color accent = Color(0xFF4DD0E1);

  /// Teal dark enough for white icons and small text.
  static const Color accentStrong = Color(0xFF0B7285);

  static const Color success = Color(0xFF1F7A3A);
  static const Color successBackground = Color(0xFFE5F4E9);

  static const Color error = Color(0xFFB3261E);
  static const Color errorBackground = Color(0xFFFBE9E7);

  /// Warning fill and icon color on [warningBackground].
  static const Color warning = Color(0xFF8F5500);
  static const Color warningBackground = Color(0xFFFFF4DC);

  static const Color info = Color(0xFF1558A8);
  static const Color infoBackground = Color(0xFFE4EFFB);

  /// Mastery dot for `difficult` (`DESIGN_REFERENCE.md` §5.3).
  static const Color masteryDifficult = Color(0xFFE07A00);

  /// Target-word highlight in a story.
  static const Color storyHighlightBackground = marker;
  static const Color storyHighlightText = primaryDeep;

  /// Cool paper: the page behind every sheet. Deliberately not cream.
  static const Color paper = Color(0xFFF2F4FA);

  /// A sheet of paper on top of [paper]; also fields and bars.
  static const Color surface = Color(0xFFFFFFFF);

  /// Quiet panel inside a sheet.
  static const Color surfaceAlt = Color(0xFFF2F4FA);

  /// Hairline rule between and around surfaces.
  static const Color line = Color(0xFFDADEEC);

  /// Field outlines: must stay visible against white (3:1).
  static const Color lineStrong = Color(0xFF8E93B2);

  /// Body text.
  static const Color ink = Color(0xFF1A1D3A);

  /// Secondary text, at least 4.5:1 on [surface] and [paper].
  static const Color inkMuted = Color(0xFF555A78);

  /// Tertiary text and disabled labels, at least 4.5:1 on [surface].
  static const Color inkFaint = Color(0xFF5F6484);

  /// Disabled control fill and the muted C2 level.
  static const Color disabledBackground = Color(0xFFE6E8F1);

  static const Color onNavyMuted = Color(0xFFC6CAE6);
}

/// 4pt spacing scale.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii scale with the size of the thing: small controls stay crisp
/// and only true pills are fully round.
abstract final class AppRadius {
  static const double small = 6;
  static const double medium = 10;
  static const double large = 14;
  static const double pill = 999;
}

/// Type scale. Literata carries reading and titles, Plus Jakarta Sans carries
/// the interface. Every token names its family because `RichText` does not
/// inherit the theme's default.
abstract final class AppTextStyles {
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  /// Page titles.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 26,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// Section headings inside a page.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// Message titles on status screens.
  static const TextStyle statusTitle = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// Dictionary headword and tested word.
  static const TextStyle wordTitle = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// A word in a list.
  static const TextStyle wordRow = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// Test sentence: same size and color as [wordTitle], but regular so the
  /// target word ([assessmentTarget]) stands out.
  static const TextStyle assessmentSentence = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 24,
    height: 1.45,
    fontWeight: FontWeight.normal,
    color: AppColors.primary,
  );

  /// Target word inside [assessmentSentence]. Only overrides what differs.
  static const TextStyle assessmentTarget = TextStyle(
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.underline,
  );

  /// Story title on the reading page.
  static const TextStyle storyTitle = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// Story body.
  static const TextStyle story = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 18,
    height: 1.75,
    color: AppColors.ink,
  );

  /// Story body with room for inline cloze dropdowns.
  static const TextStyle clozeStory = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 18,
    height: 2.2,
    color: AppColors.ink,
  );

  /// Target word in a story. The highlighter stroke sits behind the glyphs.
  static TextStyle get storyHighlight => TextStyle(
    color: AppColors.storyHighlightText,
    fontWeight: FontWeight.w700,
    background: Paint()..color = AppColors.storyHighlightBackground,
  );

  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 15,
    height: 1.5,
    color: AppColors.ink,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 15,
    height: 1.5,
    color: AppColors.inkMuted,
  );

  /// Dictionary example sentence.
  static const TextStyle example = TextStyle(
    fontFamily: AppFonts.reading,
    fontSize: 15,
    height: 1.55,
    fontStyle: FontStyle.italic,
    color: AppColors.inkMuted,
  );

  static const TextStyle badgeLabel = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 13,
    height: 1.45,
    color: AppColors.inkMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}

/// Turns the tokens into the [ThemeData] used by `MaterialApp`, so screens
/// get the system by default and only reach for tokens when composing.
abstract final class AppTheme {
  static const _controlHeight = 48.0;

  static ThemeData get themeData {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryTint,
          onPrimaryContainer: AppColors.primary,
          secondary: AppColors.accentStrong,
          onSecondary: Colors.white,
          error: AppColors.error,
          onError: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.inkMuted,
          surfaceContainerHighest: AppColors.surfaceAlt,
          outline: AppColors.lineStrong,
          outlineVariant: AppColors.line,
        );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
    );

    return ThemeData(
      useMaterial3: true,
      // Flutter otherwise compacts controls on desktop browsers, which would
      // drop buttons below the 48px touch target on touch laptops and make
      // the same screen differ between devices.
      visualDensity: VisualDensity.standard,
      colorScheme: colorScheme,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: AppColors.paper,
      disabledColor: AppColors.inkFaint,
      focusColor: AppColors.primary.withAlpha(36),
      hoverColor: AppColors.primary.withAlpha(14),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.md,
        titleTextStyle: AppTextStyles.appBarTitle,
      ),
      textTheme: const TextTheme(
        headlineSmall: AppTextStyles.wordTitle,
        titleLarge: AppTextStyles.statusTitle,
        titleMedium: AppTextStyles.bodyStrong,
        titleSmall: AppTextStyles.bodyStrong,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.badgeLabel,
        labelSmall: AppTextStyles.badgeLabel,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, _controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.smd,
          ),
          disabledBackgroundColor: AppColors.disabledBackground,
          disabledForegroundColor: AppColors.inkFaint,
          textStyle: AppTextStyles.button,
          shape: controlShape,
        ).copyWith(side: _focusRing(AppColors.marker)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.inkFaint,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(64, _controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          textStyle: AppTextStyles.button,
          shape: controlShape,
        ).copyWith(side: _focusRing(AppColors.primary, idle: AppColors.lineStrong)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size(48, 44),
          textStyle: AppTextStyles.button,
          shape: controlShape,
        ).copyWith(side: _focusRing(AppColors.primary)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: controlShape,
        ).copyWith(side: _focusRing(AppColors.primary)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        labelStyle: AppTextStyles.bodyMuted,
        hintStyle: AppTextStyles.bodyMuted,
        border: _inputBorder(AppColors.lineStrong),
        enabledBorder: _inputBorder(AppColors.lineStrong),
        disabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.primary, width: 2),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 2),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surface,
        ),
        side: const BorderSide(color: AppColors.line),
        checkmarkColor: AppColors.marker,
        labelStyle: AppTextStyles.badgeLabel.copyWith(
          fontSize: 13,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.ink,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        showCheckmark: true,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        selectedIcon: const SizedBox.shrink(),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          visualDensity: VisualDensity.standard,
          textStyle: const WidgetStatePropertyAll(AppTextStyles.badgeLabel),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.primary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surface,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.lineStrong),
          ),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkMuted,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.line,
        labelStyle: AppTextStyles.bodyStrong,
        unselectedLabelStyle: AppTextStyles.body,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primaryDeep,
        indicatorColor: AppColors.marker,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        selectedIconTheme: const IconThemeData(color: AppColors.primaryDeep),
        unselectedIconTheme: const IconThemeData(color: AppColors.onNavyMuted),
        selectedLabelTextStyle: AppTextStyles.badgeLabel.copyWith(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: AppTextStyles.badgeLabel.copyWith(
          color: AppColors.onNavyMuted,
          fontSize: 13,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: AppTextStyles.bodyStrong,
        subtitleTextStyle: AppTextStyles.caption,
        iconColor: AppColors.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.lineStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small - 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.statusTitle,
        contentTextStyle: AppTextStyles.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        constraints: BoxConstraints(maxWidth: 640),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.large),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDeep,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryTint,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: AppTextStyles.badgeLabel.copyWith(color: Colors.white),
        decoration: BoxDecoration(
          color: AppColors.primaryDeep,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
    );
  }

  /// A 2px ring on keyboard focus. Flutter's default focus overlay alone is
  /// too faint on filled buttons for keyboard users.
  static WidgetStateProperty<BorderSide?> _focusRing(
    Color color, {
    Color? idle,
  }) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return BorderSide(color: color, width: 2);
    }
    if (idle == null) return null;
    return BorderSide(
      color: states.contains(WidgetState.disabled) ? AppColors.line : idle,
    );
  });

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: color, width: width),
      );
}
