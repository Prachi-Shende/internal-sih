import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isEmergencyActive;

  const FloatingBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.isEmergencyActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEmergencyActive ? AppColors.emergency : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: isEmergencyActive ? AppColors.emergency.withOpacity(0.4) : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
            _NavItem(
              icon: Icons.home,
              label: 'Home',
              isSelected: currentIndex == 0,
              isEmergencyActive: isEmergencyActive,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.map,
              label: 'Map',
              isSelected: currentIndex == 1,
              isEmergencyActive: isEmergencyActive,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.security,
              label: 'Safety',
              isSelected: currentIndex == 2,
              isEmergencyActive: isEmergencyActive,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.work,
              label: 'Trip',
              isSelected: currentIndex == 3,
              isEmergencyActive: isEmergencyActive,
              onTap: () => onTap(3),
            ),
            _NavItem(
              icon: Icons.person,
              label: 'Profile',
              isSelected: currentIndex == 4,
              isEmergencyActive: isEmergencyActive,
              onTap: () => onTap(4),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isEmergencyActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isEmergencyActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isEmergencyActive ? Colors.white24 : AppColors.primary.withOpacity(0.1)) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? (isEmergencyActive ? Colors.white : AppColors.primary) 
                  : (isEmergencyActive ? Colors.white70 : AppColors.textSecondary),
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isEmergencyActive ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
