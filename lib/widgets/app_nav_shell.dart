import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_brand.dart';
import 'app_layout.dart';

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
/// `DESIGN_REFERENCE.md` §6.1: one navigation system that changes shape with
/// the window, shared by siswa and guru:
///
/// - below [wideBreakpoint]: a navy app bar with top tabs;
/// - from [wideBreakpoint]: a navy spine ([NavigationRail]) with icon + label
///   stacked, and no app bar, so tablets keep their vertical space;
/// - from [AppBreakpoints.expanded]: the same spine, extended with labels
///   beside the icons.
///
/// Each destination decides its own content width, because a dashboard and a
/// form want different widths. This class contains no
/// Firebase/Riverpod/auth/role knowledge at all; a caller supplies whatever
/// [destinations] apply to the signed-in user.
class AppNavShell extends StatefulWidget {
  const AppNavShell({
    super.key,
    required this.destinations,
    this.initialIndex = 0,
    this.onLogout,
  }) : assert(
         destinations.length > 0,
         'AppNavShell requires at least one destination',
       ),
       assert(
         initialIndex >= 0 && initialIndex < destinations.length,
         'initialIndex must be a valid index into destinations',
       );

  final List<AppNavDestination> destinations;
  final int initialIndex;
  final VoidCallback? onLogout;

  /// Width at which the shell switches from top tabs to the side spine.
  static const double wideBreakpoint = AppBreakpoints.compact;

  @override
  State<AppNavShell> createState() => _AppNavShellState();
}

class _AppNavShellState extends State<AppNavShell> {
  late int _selectedIndex = widget.initialIndex;

  /// One key per destination, so the selected body keeps its state (a half
  /// filled form, the open tab) when the window crosses [wideBreakpoint] and
  /// the shell around it changes shape, for example when a tablet rotates.
  final _bodyKeys = <int, GlobalKey>{};

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppNavShell.wideBreakpoint;
    // Defensive clamp, not just belt-and-suspenders with the constructor
    // asserts above: asserts are stripped from release builds entirely, and
    // _selectedIndex lives in State, so it can in principle outlive a
    // rebuild that hands this widget a shorter `destinations` list than the
    // one _selectedIndex was chosen against. Indexing with the raw field
    // would then throw RangeError with no assert left to have caught it.
    final selectedIndex = _selectedIndex.clamp(
      0,
      widget.destinations.length - 1,
    );
    // Only the selected destination is ever built — switching destinations
    // simply swaps which widget occupies this spot.
    final selectedBody = KeyedSubtree(
      key: _bodyKeys.putIfAbsent(selectedIndex, GlobalKey.new),
      child: widget.destinations[selectedIndex].body,
    );

    if (isWide) {
      final extended = width >= AppBreakpoints.expanded;
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _select,
              extended: extended,
              minExtendedWidth: 232,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: EdgeInsets.fromLTRB(
                  extended ? AppSpacing.md : AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: AppWordmark(fontSize: extended ? 24 : 16),
              ),
              trailing: widget.onLogout == null
                  ? null
                  : Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: IconButton(
                            icon: const Icon(Icons.logout),
                            color: AppColors.onNavyMuted,
                            tooltip: 'Keluar',
                            onPressed: widget.onLogout,
                          ),
                        ),
                      ),
                    ),
              destinations: [
                for (final destination in widget.destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            Expanded(child: selectedBody),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const AppWordmark(),
        actions: [
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Keluar',
              onPressed: widget.onLogout,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _NavTabRow(
            destinations: widget.destinations,
            selectedIndex: selectedIndex,
            onSelected: _select,
          ),
        ),
      ),
      body: selectedBody,
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
    return Row(
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
    final color = selected ? Colors.white : AppColors.onNavyMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.marker : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: ExcludeSemantics(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(color: color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
