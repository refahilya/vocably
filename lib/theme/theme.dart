import 'package:flutter/material.dart';

/// Vocably design-system tokens — single source of truth for colors,
/// spacing, corner radii, and typography treatment (`CLAUDE.md` §5: "Semua
/// warna, font, radius, spacing didefinisikan di `lib/theme/theme.dart` —
/// jangan hardcode nilai style di widget individual").
///
/// Source: `DESIGN_REFERENCE.md` §1 (palette) and §2 (typography), carried
/// over from the deprecated native-Android v1 app — only the color
/// identity and shape language are preserved, not its layout (see that
/// document's own framing note). The hex values there are explicitly
/// flagged as **visual estimates from screenshots**, not exact values from
/// the old app's code — treat the values below the same way; adjust with a
/// color picker later if a more precise reference turns up.
///
/// Stage 1 (tokens: [AppColors]/[AppSpacing]/[AppRadius]/[AppTextStyles])
/// and Stage 2 ([AppTheme], which turns those tokens into the actual
/// [ThemeData] wired into `MaterialApp` in `app.dart`) both live here —
/// `theme.dart` stays the single file for design-system code per
/// `CLAUDE.md` §5/§6, not split prematurely.

/// Color tokens. Where `DESIGN_REFERENCE.md` §1 pairs a role with a "muda"
/// (light) background variant, both are kept here — e.g. [success] +
/// [successBackground] — mirroring the palette table's own "Warna X + latar
/// Y" structure rather than inventing new pairings.
abstract final class AppColors {
  /// App bar, tombol utama, header stepper, item navigasi aktif, avatar
  /// user di chat. The doc gives a range (`#1B1F5C`–`#26307A`); the darker
  /// end is used as the canonical value.
  static const Color primary = Color(0xFF1B1F5C);

  /// Avatar AI di co-write, aksen ikon.
  static const Color accent = Color(0xFF4DD0E1);

  /// Jawaban benar di cloze test, banner "semua kata target sudah
  /// digunakan", badge mastery `mastered`.
  static const Color success = Color(0xFF2E7D32);
  static const Color successBackground = Color(0xFFE8F5E9);

  /// Jawaban salah di cloze test, inline error form.
  static const Color error = Color(0xFFC62828);
  static const Color errorBackground = Color(0xFFFCE4EC);

  /// Feedback grammar di co-write.
  static const Color warning = Color(0xFFFFA000);
  static const Color warningBackground = Color(0xFFFFF8E1);

  /// Dot penanda kata `difficult` (§5.3) — solid, unlike the
  /// solid+background pairs above.
  static const Color masteryDifficult = Color(0xFFF57C00);

  /// Highlight kata target di dalam cerita (Baca Cerita) — latar
  /// oranye/tan muda dengan teks oranye tua.
  static const Color storyHighlightBackground = Color(0xFFFFE0B2);
  static const Color storyHighlightText = Color(0xFFE65100);

  /// Background utama layar.
  static const Color background = Color(0xFFFFFFFF);

  /// Latar sekunder yang sedikit lebih gelap dari [background] — mis. buat
  /// banner instruksi abu muda (§3.5), tanpa jatuh ke putih polos.
  static const Color surfaceAlt = Color(0xFFF5F5F5);

  /// Netral/disabled — entry point "Segera" (pre/post test), tombol
  /// disabled, pill C2.
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color disabledBackground = Color(0xFFEEEEEE);
}

/// Spacing scale, in logical pixels. `DESIGN_REFERENCE.md` doesn't specify
/// exact spacing numbers (only qualitative treatment), so this is a
/// conventional 4pt-based scale — an implementation choice, not a literal
/// document value. Change freely if a stricter reference emerges.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner-radius tokens. The "rounded corner, pill chip" shape language is
/// preserved from v1 per `DESIGN_REFERENCE.md`'s intro note; the specific
/// values are an implementation choice, not literal document numbers.
abstract final class AppRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;

  /// For fully-rounded "pill" shapes (chips, pill buttons) — pass to
  /// `BorderRadius.circular(AppRadius.pill)`; large enough to fully round
  /// regardless of the shape's height.
  static const double pill = 999;
}

/// Typography treatments from `DESIGN_REFERENCE.md` §2. These are plain
/// [TextStyle] tokens, not a [TextTheme]/[ThemeData] — building and wiring
/// the actual theme is Stage 2.
///
/// Note on [wordTitle]: the doc's word-title example ("SOUVENIR",
/// "DESTINATION") is uppercase, but that's a text-case transform, not a
/// [TextStyle] property — callers apply `.toUpperCase()` to the string
/// themselves; this token only carries weight/size/color.
abstract final class AppTextStyles {
  /// App bar title — bold, putih, di atas background navy.
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  /// Judul kata di kartu detail — huruf besar semua (lihat catatan di atas
  /// soal uppercasing), bold, ukuran besar, navy/gelap.
  static const TextStyle wordTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  /// Body text — regular weight, warna gelap netral.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: Colors.black87,
  );

  /// Label kecil di badge (POS tag, dsb).
  static const TextStyle badgeLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  /// Small secondary text — smaller than [body], for auxiliary UI chrome
  /// that shouldn't compete visually with the main content (e.g. the
  /// vocab-browser pagination indicator, Milestone 4 finalization).
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Colors.black87,
  );
}

/// Builds the application [ThemeData] from the tokens above — the only
/// place raw Flutter theming APIs meet the Vocably tokens. Nothing outside
/// this file should reference [AppColors]/[AppTextStyles]/[AppRadius] to
/// build theme-level styling, and nothing outside this file should
/// hardcode a raw color/style meant to represent one of the roles above
/// (`CLAUDE.md` §5: "jangan hardcode nilai style di widget individual").
abstract final class AppTheme {
  static ThemeData get themeData {
    // Seeded from AppColors.primary so every M3-generated tonal role
    // (containers, tertiary, etc.) that DESIGN_REFERENCE.md doesn't
    // explicitly specify still stays harmonious with the brand color,
    // rather than falling back to Flutter's unrelated default purple.
    // The roles the doc *does* specify (§1) are then pinned explicitly via
    // copyWith so they match the documented tokens exactly, not whatever
    // the seed algorithm would have derived for them.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.background,
      onSurface: Colors.black87,
    );

    return ThemeData(
      colorScheme: colorScheme,
      // §1: "Background utama — Putih / abu sangat muda".
      scaffoldBackgroundColor: AppColors.background,
      // §2: "Header/app bar: bold, putih, di atas background navy".
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: AppTextStyles.appBarTitle,
      ),
      // Maps the tokens that have an obvious TextTheme slot; the rest of
      // the slots keep Flutter's Material defaults — DESIGN_REFERENCE.md
      // §2 only documents these three treatments plus the app bar above.
      textTheme: const TextTheme(
        headlineSmall: AppTextStyles.wordTitle,
        bodyMedium: AppTextStyles.body,
        labelSmall: AppTextStyles.badgeLabel,
      ),
      // Existing auth screens (login/sign-up/complete-registration) already
      // use FilledButton/OutlinedButton and TextFormField with no local
      // style overrides, so this directly restyles those already-built
      // screens to the documented rounded shape language (§1 intro:
      // "rounded corner, pill chip") without touching those files.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
      // §5.6: form fields "rounded, border tipis, focus state navy".
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
