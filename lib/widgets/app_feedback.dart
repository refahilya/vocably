import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_layout.dart';

/// Meaning of a notice or badge. Every tone pairs a color with an icon or
/// text, so meaning never depends on color alone.
enum AppTone { neutral, info, success, warning, error }

extension AppToneColors on AppTone {
  Color get foreground => switch (this) {
    AppTone.neutral => AppColors.inkMuted,
    AppTone.info => AppColors.info,
    AppTone.success => AppColors.success,
    AppTone.warning => AppColors.warning,
    AppTone.error => AppColors.error,
  };

  Color get background => switch (this) {
    AppTone.neutral => AppColors.disabledBackground,
    AppTone.info => AppColors.infoBackground,
    AppTone.success => AppColors.successBackground,
    AppTone.warning => AppColors.warningBackground,
    AppTone.error => AppColors.errorBackground,
  };

  IconData get icon => switch (this) {
    AppTone.neutral => Icons.lock_outline,
    AppTone.info => Icons.info_outline,
    AppTone.success => Icons.check_circle_outline,
    AppTone.warning => Icons.lightbulb_outline,
    AppTone.error => Icons.error_outline,
  };
}

/// An inline message: errors, reminders, locked states.
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.text,
    this.tone = AppTone.info,
    this.icon,
    this.action,
    this.textAlign,
    this.textStyle,
  });

  final String text;
  final AppTone tone;

  /// Replaces the tone's default icon.
  final IconData? icon;

  /// Optional button after the text, e.g. "Coba lagi".
  final Widget? action;
  final TextAlign? textAlign;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon ?? tone.icon, size: 18, color: tone.foreground),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: textStyle ?? AppTextStyles.body,
              textAlign: textAlign,
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.xs),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A small label. [AppBadge.solid] is reserved for the one thing a row should
/// be read by, such as its CEFR level.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.text,
    this.tone = AppTone.neutral,
  }) : solid = false;

  const AppBadge.solid({super.key, required this.text})
    : tone = AppTone.neutral,
      solid = true;

  final String text;
  final AppTone tone;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final background = solid ? AppColors.primary : tone.background;
    final foreground = solid
        ? Colors.white
        : (tone == AppTone.neutral ? AppColors.ink : tone.foreground);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.badgeLabel.copyWith(color: foreground),
      ),
    );
  }
}

/// Centered progress for a whole region.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(label!, style: AppTextStyles.bodyMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// A progress indicator sized for the inside of a button.
class AppButtonSpinner extends StatelessWidget {
  const AppButtonSpinner({super.key, this.color, this.size = 20});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

/// A status message that fills its region: nothing to show yet, something went
/// wrong, or a test that isn't available. Scrolls when the window is short.
class AppStateMessage extends StatelessWidget {
  const AppStateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.footer,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  /// Extra content between [body] and [action].
  final Widget? footer;

  /// Colors the icon. Defaults to navy.
  final AppTone? tone;

  @override
  Widget build(BuildContext context) {
    final iconColor = tone?.foreground ?? AppColors.primary;
    final iconBackground = tone?.background ?? AppColors.primaryTint;

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidth.message),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 30, color: iconColor),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.statusTitle,
                ),
                if (body != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  footer!,
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  action!,
                ],
              ],
            ),
          ),
        );
        // Unbounded parents (a Column inside a scroll view) just get the
        // content; bounded ones center it and scroll when it doesn't fit.
        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

/// "Couldn't load this" with a retry.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppStateMessage(
      icon: Icons.cloud_off_outlined,
      title: message,
      tone: AppTone.error,
      action: OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
    );
  }
}

/// Keeps a section heading and its optional trailing widget on one line when
/// they fit, and stacks them when they don't.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleStyle = AppTextStyles.sectionTitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: titleStyle),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: AppTextStyles.caption),
        ],
      ],
    );
    if (trailing == null) return heading;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.smd,
      children: [heading, trailing!],
    );
  }
}
