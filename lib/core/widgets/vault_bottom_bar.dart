import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/theme/app_theme.dart';

class VaultBottomBar extends StatelessWidget {
  final int currentIndex;

  const VaultBottomBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final selectedColor = isDark ? const Color(0xFF2DD4BF) : AppColors.primaryContainer;
    final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: Icons.receipt_long,
                label: 'Vault',
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () {
                  if (currentIndex != 0) context.go('/');
                },
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: Icons.search,
                label: 'Search',
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () {
                  if (currentIndex != 1) context.go('/search');
                },
              ),
              _buildNavItem(
                context,
                index: 2,
                icon: Icons.assessment_outlined,
                label: 'Reports',
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () {
                  if (currentIndex != 2) context.go('/reports');
                },
              ),
              _buildNavItem(
                context,
                index: 3,
                icon: Icons.settings_outlined,
                label: 'Settings',
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () {
                  if (currentIndex != 3) context.go('/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required Color selectedColor,
    required Color unselectedColor,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                if (isSelected)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
