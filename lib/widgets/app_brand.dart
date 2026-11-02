import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../theme/theme.dart';
import 'app_layout.dart';

/// The Vocably wordmark: the name with one highlighter stroke underneath.
class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    this.color = Colors.white,
    this.fontSize = 22,
  });

  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _MarkerStrokePainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          'Vocably',
          style: TextStyle(
            fontFamily: AppFonts.reading,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.25,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// A slightly slanted stroke across the bottom of its child, the way a
/// highlighter leaves the page.
class _MarkerStrokePainter extends CustomPainter {
  const _MarkerStrokePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokeHeight = size.height * 0.2;
    final bottom = size.height + strokeHeight * 0.15;
    final path = Path()
      ..moveTo(0, bottom - strokeHeight)
      ..lineTo(size.width, bottom - strokeHeight - 1.5)
      ..lineTo(size.width, bottom - 1.5)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.marker);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sign-in family of screens: a navy cover beside the form on wide windows, a
/// short cover above it on phones.
class AppAuthScaffold extends ConsumerWidget {
  const AppAuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  static const _tagline = 'Belajar kosakata bahasa Inggris lewat cerita.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sign-up, and a login opened from it, are pushed above the root router.
    // Signing in changes what the router shows beneath them, so they have to
    // get out of the way themselves. The router's own screen has nothing to
    // close, and it swaps that screen anyway.
    if (Navigator.of(context).canPop()) {
      ref.listen(appAuthStatusProvider, (_, status) {
        if (status is AppAuthSignedIn) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.medium;
        // Same rule AppBar applies by itself: a pushed route can go back.
        final canPop = Navigator.of(context).canPop();
        final form = _AuthForm(title: title, subtitle: subtitle, child: child);
        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(flex: 5, child: _AuthCover()),
                Expanded(
                  flex: 6,
                  child: Stack(
                    children: [
                      SafeArea(child: Center(child: form)),
                      if (canPop)
                        const Positioned(
                          top: AppSpacing.sm,
                          left: AppSpacing.sm,
                          child: BackButton(color: AppColors.primary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const AppWordmark()),
          body: SafeArea(top: false, child: form),
        );
      },
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AppContent(
        maxWidth: AppContentWidth.form + AppSpacing.xxl,
        vertical: AppSpacing.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTextStyles.pageTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle ?? AppAuthScaffold._tagline,
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

/// Shows how Vocably teaches rather than describing it: a sentence with its
/// target word marked, exactly as a story page marks it.
class _AuthCover extends StatelessWidget {
  const _AuthCover();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppWordmark(fontSize: 28),
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.storyTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                      fontSize: 30,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'Every new word has a story. Read it, '),
                      TextSpan(
                        text: 'use it',
                        style: TextStyle(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w700,
                          background: Paint()..color = AppColors.marker,
                        ),
                      ),
                      const TextSpan(text: ', and it stays with you.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppAuthScaffold._tagline,
                style: AppTextStyles.body.copyWith(color: AppColors.onNavyMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
