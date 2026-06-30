import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../i18n/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Scaffold that hosts the persistent floating bottom navigation bar.
/// Tabs: Home · History · Rx · Reports · Profile.
class ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ScaffoldWithNav({super.key, required this.shell});

  static const _items = [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'nav.home'),
    _NavItem(Icons.access_time_filled_rounded, Icons.access_time_rounded,
        'nav.history'),
    _NavItem(Icons.medication_rounded, Icons.medication_outlined, 'nav.rx'),
    _NavItem(Icons.description_rounded, Icons.description_outlined, 'nav.reports'),
    _NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'nav.profile'),
  ];

  void _go(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: shell,
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _items[i],
                      selected: shell.currentIndex == i,
                      onTap: () => _go(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData active;
  final IconData inactive;
  final String label;
  const _NavItem(this.active, this.inactive, this.label);
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final label = context.tr(item.label);

    Widget icon = Icon(selected ? item.active : item.inactive,
        size: 25, color: selected ? c.primary : c.text3);
    if (selected) {
      icon = ShaderMask(
        shaderCallback: (r) => brandGradient(context).createShader(r),
        child: Icon(item.active, size: 25, color: Colors.white),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.small.copyWith(
                color: selected ? c.primary : c.text3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
