import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/theme/theme.dart';
import 'package:vocably/widgets/app_feedback.dart';

/// WCAG 2.1 contrast ratio.
double contrast(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  final (hi, lo) = luminance(a) > luminance(b)
      ? (luminance(a), luminance(b))
      : (luminance(b), luminance(a));
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('text colors reach WCAG AA (4.5:1) on the surfaces they sit on', () {
    final pairs = <String, (Color, Color)>{
      'ink on paper': (AppColors.ink, AppColors.paper),
      'ink on surface': (AppColors.ink, AppColors.surface),
      'muted on paper': (AppColors.inkMuted, AppColors.paper),
      'muted on surface': (AppColors.inkMuted, AppColors.surface),
      'faint on surface': (AppColors.inkFaint, AppColors.surface),
      'faint on disabled fill': (AppColors.inkFaint, AppColors.disabledBackground),
      'white on navy': (Colors.white, AppColors.primary),
      'muted on navy': (AppColors.onNavyMuted, AppColors.primary),
      'muted on spine': (AppColors.onNavyMuted, AppColors.primaryDeep),
      'navy on tint': (AppColors.primary, AppColors.primaryTint),
      'navy on strong tint': (AppColors.primary, AppColors.primaryTintStrong),
      'highlighted story word': (
        AppColors.storyHighlightText,
        AppColors.storyHighlightBackground,
      ),
      'navy on spine marker': (AppColors.primaryDeep, AppColors.marker),
      'white on success button': (Colors.white, AppColors.success),
      'white on AI avatar': (Colors.white, AppColors.accentStrong),
    };
    for (final tone in AppTone.values) {
      pairs['badge text, $tone'] = (
        tone == AppTone.neutral ? AppColors.ink : tone.foreground,
        tone.background,
      );
    }

    pairs.forEach((name, pair) {
      test(name, () {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      });
    });
  });

  test('field outlines stay visible against white (WCAG 1.4.11, 3:1)', () {
    expect(contrast(AppColors.lineStrong, AppColors.surface), greaterThanOrEqualTo(3));
  });

  test('assessment target style only adds emphasis, never a color of its own', () {
    expect(AppTextStyles.assessmentTarget.color, isNull);
    expect(AppTextStyles.assessmentTarget.fontSize, isNull);
    expect(AppTextStyles.assessmentTarget.backgroundColor, isNull);
    expect(AppTextStyles.assessmentTarget.background, isNull);
  });

  test('controls keep the 48px touch height on every platform', () {
    final theme = AppTheme.themeData;
    expect(theme.visualDensity, VisualDensity.standard);
    final height = theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height;
    expect(height, 48);
  });

  test('every font asset the theme relies on is bundled, licensed and declared', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final family in [AppFonts.ui, AppFonts.reading]) {
      expect(pubspec, contains('family: $family'));
    }
    final declared = RegExp(r'asset: (assets/fonts/\S+)').allMatches(pubspec);
    expect(declared, isNotEmpty);
    for (final match in declared) {
      expect(File(match.group(1)!).existsSync(), isTrue, reason: match.group(1));
    }
    expect(File('assets/fonts/OFL-PlusJakartaSans.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-Literata.txt').existsSync(), isTrue);
  });
}
