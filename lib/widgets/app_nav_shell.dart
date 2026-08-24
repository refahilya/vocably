import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// One destination hosted by [AppNavShell] — a label, an icon, and the
/// content shown while it's selected.
///
/// Deliberately generic: nothing here knows this will eventually represent
/// "Belajar"/"Riwayat" or "Target Kata"/"Kosakata" — that mapping is the
/// caller's job (see `DATA_MODEL.md`/`SPEC.md` §3.2, §4.1), not the
/// shell's.
class AppNavDestination {
  const AppNavDestination({
    required this.label,
    required this.icon,
    required this.body,
  });

  final String label;
  final IconData icon;
  final Widget body;
}

/// Generic, role-agnostic responsive navigation shell.
///
/// `DESIGN_REFERENCE.md` §6.1: "satu sistem navigasi... berubah bentuk
/// mengikuti lebar layar" — `NavigationRail` on wide screens, a horizontal
/// top-tab row on narrow ones — as **one** reusable widget shared by both
/// siswa and guru, not two separate implementations. This class contains
/// no Firebase/Riverpod/auth/role knowledge at all; a caller supplies
/// whatever [destinations] apply to the signed-in user.
class AppNavShell extends StatefulWidget {
  const AppNavShell({super.key, required this.destinations, this.initialIndex = 0})
    : assert(
        destinations.length > 0,
        'AppNavShell requires at least one destination',
      ),
      assert(
        initialIndex >= 0 && initialIndex < destinations.length,
        'initialIndex must be a valid index into destinations',
      );

  final List<AppNavDestination> destinations;
  final int initialIndex;

  /// Width at which the shell switches from the narrow top-tab layout to
  /// the wide `NavigationRail` layout. An implementation choice (no exact
  /// pixel value is specified anywhere in the source documents) — kept
  /// local to the shell rather than in `theme.dart`, since nothing else
  /// currently needs this specific number.
  static const double wideBreakpoint = 600;

  @override
  State<AppNavShell> createState() => _AppNavShellState();
}

class _AppNavShellState extends State<AppNavShell> {
  late int _selectedIndex = widget.initialIndex;

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= AppNavShell.wideBreakpoint;
    // Defensive clamp, not just belt-and-suspenders with the constructor
    // asserts above: asserts are stripped from release builds entirely, and
    // _selectedIndex lives in State, so it can in principle outlive a
    // rebuild that hands this widget a shorter `destinations` list than the
    // one _selectedIndex was chosen against. Indexing with the raw field
    // would then throw RangeError with no assert left to have caught it.
    final selectedIndex = _selectedIndex.clamp(0, widget.destinations.length - 1);
    // Only the selected destination is ever built — switching destinations
    // simply swaps which widget occupies this spot. No IndexedStack: none
    // of the current (placeholder) destinations have state worth keeping
    // alive while hidden, and DESIGN_REFERENCE.md doesn't ask for it here.
    final selectedBody = widget.destinations[selectedIndex].body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocably'),
        bottom: isWide
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _NavTabRow(
                  destinations: widget.destinations,
                  selectedIndex: selectedIndex,
                  onSelected: _select,
                ),
              ),
      ),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in widget.destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _CenteredContent(child: selectedBody)),
              ],
            )
          : _CenteredContent(child: selectedBody),
    );
  }
}

/// Keeps main content from stretching edge-to-edge on wide screens
/// (`DESIGN_REFERENCE.md` §6.2: "Di layar lebar, jangan diregangkan...
/// max-width terpusat"). At the ~390px canonical width this is a no-op —
/// content is already narrower than the cap — so no separate narrow-width
/// special case is needed.
class _CenteredContent extends StatelessWidget {
  const _CenteredContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }
}

/// Narrow-layout top navigation — a small custom row rather than
/// [TabBar]. [TabBar] would require an owned [TabController]/`vsync` kept
/// in sync with the exact same selection [NavigationRail] already drives
/// with a plain `int`; this reads/writes that same `int` directly instead,
/// with no separate controller to keep in sync.
class _NavTabRow extends StatelessWidget {
  const _NavTabRow({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Row(
        children: [
          for (var i = 0; i < destinations.length; i++)
            Expanded(
              child: _NavTabItem(
                destination: destinations[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// One item in [_NavTabRow]. Since this replaces [TabBar] (which ships
/// with its own tab semantics and ~46-48dp default height for free), both
/// are provided explicitly here: [Semantics] communicates the label,
/// selected state, and that it's tappable; the item is padded to a
/// minimum ~48dp touch height.
class _NavTabItem extends StatelessWidget {
  const _NavTabItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Colors.black54;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.icon, color: color, size: 22),
              // Deliberately tighter than AppSpacing.xs (4) — this is a
              // component-specific gap sized for this compact tab item, not
              // an instance of the general spacing scale; doubling it would
              // visibly loosen the icon/label pairing.
              const SizedBox(height: 2),
              Text(
                destination.label,
                style: AppTextStyles.badgeLabel.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
