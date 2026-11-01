import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Window widths where the layout changes shape. Chosen from the content, not
/// from device classes: below [compact] there is room for one column of text
/// and a top tab row; from [medium] a page can hold two panes side by side;
/// from [expanded] the navigation has room for its labels.
abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;

  /// Below this window height (a phone held sideways, or an open on-screen
  /// keyboard) stacked headers would leave no room for the content.
  static const double shortHeight = 520;
}

/// Whether the window, minus any on-screen keyboard, is short.
bool isShortWindow(BuildContext context) =>
    MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom <
    AppBreakpoints.shortHeight;

/// Maximum content widths. Screens differ on purpose: reading and tests need a
/// comfortable line length, while dashboards and word lists use the room.
abstract final class AppContentWidth {
  static const double form = 440;
  static const double message = 480;
  static const double assessment = 640;
  static const double reading = 680;
  static const double chat = 760;
  static const double list = 960;
  static const double page = 1160;
}

/// Horizontal page margin for the current window.
double appGutter(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.compact) return AppSpacing.md;
  if (width < AppBreakpoints.medium) return AppSpacing.lg;
  return AppSpacing.xl;
}

/// Centers [child] at no more than [maxWidth], with the page gutter.
class AppContent extends StatelessWidget {
  const AppContent({
    super.key,
    required this.child,
    this.maxWidth = AppContentWidth.page,
    this.vertical = 0,
  });

  final Widget child;
  final double maxWidth;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: appGutter(context),
              vertical: vertical,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A scrolling page. The scroll view spans the whole window and the content is
/// centered inside it, so the wheel works over the margins on desktop and the
/// scrollbar sits at the window edge rather than beside the text.
class AppScrollPage extends StatelessWidget {
  const AppScrollPage({
    super.key,
    required this.child,
    this.maxWidth = AppContentWidth.page,
    this.controller,
  });

  final Widget child;
  final double maxWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      child: AppContent(
        maxWidth: maxWidth,
        vertical: appGutter(context),
        child: child,
      ),
    );
  }
}

/// A sheet of paper: the white surface that holds a page's main content.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // A Material rather than a decorated box, so ink from tiles inside stays
    // visible.
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// The action bar pinned to the bottom of a task screen, so the next step
/// stays reachable however long the page gets. [wide] buttons shrink to their
/// own width from [AppBreakpoints.compact] up instead of stretching.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.child,
    this.maxWidth = AppContentWidth.page,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: AppContent(
          maxWidth: maxWidth,
          vertical: AppSpacing.smd,
          child: child,
        ),
      ),
    );
  }
}

/// A primary pane with a side pane beside it when there is room, stacked
/// (side first when [sideFirst]) otherwise.
class AppTwoPane extends StatelessWidget {
  const AppTwoPane({
    super.key,
    required this.primary,
    required this.side,
    this.breakpoint = AppBreakpoints.medium,
    this.sideWidth = 320,
    this.sideFirst = false,
    this.sideLeading = false,
  });

  final Widget primary;
  final Widget side;
  final double breakpoint;
  final double sideWidth;

  /// Stacked order: put [side] above [primary] on narrow windows.
  final bool sideFirst;

  /// Wide order: put [side] on the left.
  final bool sideLeading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sideFirst) ...[side, const SizedBox(height: AppSpacing.md)],
              primary,
              if (!sideFirst) ...[const SizedBox(height: AppSpacing.md), side],
            ],
          );
        }
        final sidePane = SizedBox(width: sideWidth, child: side);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sideLeading) ...[sidePane, const SizedBox(width: AppSpacing.lg)],
            Expanded(child: primary),
            if (!sideLeading) ...[const SizedBox(width: AppSpacing.lg), sidePane],
          ],
        );
      },
    );
  }
}

/// A lazy list that gains columns as the window grows: one column on phones,
/// more once each item can keep [minItemWidth]. Items in a row share a height.
class AppResponsiveList extends StatelessWidget {
  const AppResponsiveList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 380,
    this.maxColumns = 3,
    this.gap = AppSpacing.smd,
    this.padding = EdgeInsets.zero,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minItemWidth;
  final int maxColumns;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.maxWidth - padding.horizontal;
        final columns = ((usable + gap) / (minItemWidth + gap)).floor().clamp(
          1,
          maxColumns,
        );
        final rows = (itemCount / columns).ceil();
        return ListView.separated(
          padding: padding,
          itemCount: rows,
          separatorBuilder: (_, _) => SizedBox(height: gap),
          itemBuilder: (context, row) {
            if (columns == 1) return itemBuilder(context, row);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    Expanded(
                      child: row * columns + c < itemCount
                          ? itemBuilder(context, row * columns + c)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
