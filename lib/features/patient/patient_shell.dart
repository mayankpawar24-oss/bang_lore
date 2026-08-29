import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class PatientShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const PatientShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppColors.border.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            backgroundColor: Colors.white,
            elevation: 0,
            indicatorColor: AppColors.softBlue,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(LucideIcons.home, color: AppColors.secondaryText),
                selectedIcon: Icon(LucideIcons.home, color: AppColors.primaryBlue),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.calendar, color: AppColors.secondaryText),
                selectedIcon: Icon(LucideIcons.calendar, color: AppColors.primaryBlue),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.users, color: AppColors.secondaryText),
                selectedIcon: Icon(LucideIcons.users, color: AppColors.primaryBlue),
                label: 'Family',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.user, color: AppColors.secondaryText),
                selectedIcon: Icon(LucideIcons.user, color: AppColors.primaryBlue),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
