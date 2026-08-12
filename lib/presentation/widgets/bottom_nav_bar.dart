import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';

/// Bottom navigation bar — matches screenshots exactly.
/// Lime pill + circular search button.
class BottomNavBarV2 extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSearchTap;

  const BottomNavBarV2({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        ),
        child: Row(
          children: [
            Expanded(
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
                      icon: Icons.calendar_today_outlined,
                      label: 'Активности',
                      isSelected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.location_on_outlined,
                      label: 'Карта',
                      isSelected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.archive_outlined,
                      label: 'Архив',
                      isSelected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onSearchTap,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: DesignTokens.limeAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search,
                  color: DesignTokens.textPrimary,
                  size: 28,
                ),
              ),
            ),
          ],
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
            color: isSelected
                ? DesignTokens.primary
                : DesignTokens.textPrimary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: DesignTokens.pin(
              color: isSelected
                  ? DesignTokens.primary
                  : DesignTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
