import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

/// Bottom navigation bar — V2 design (ARCHITECTURE_V2.md §6,
/// design_tokens.md): lime pill with exactly four items — Groups / Map /
/// Archive / Profile. The middle FAB slot is per-tab FAB behaviour handled
/// by the pages themselves (Groups → «Add Group», Map → map action menu).
class BottomNavBarV2 extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBarV2({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        ),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: DesignTokens.limeAccent,
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.group_outlined,
                label: l.tabGroups,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.map_outlined,
                label: l.tabMap,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.archive_outlined,
                label: l.tabArchive,
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: l.tabProfile,
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? DesignTokens.primary : DesignTokens.textPrimary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: DesignTokens.pin(
              color:
                  isSelected ? DesignTokens.primary : DesignTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
