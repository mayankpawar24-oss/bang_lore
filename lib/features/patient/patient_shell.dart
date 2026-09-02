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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131C2E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.border.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
            elevation: 0,
            indicatorColor: isDark
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                : AppColors.softBlue,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(LucideIcons.home, color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                selectedIcon: const Icon(LucideIcons.home, color: AppColors.primaryBlue),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.calendar, color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                selectedIcon: const Icon(LucideIcons.calendar, color: AppColors.primaryBlue),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.bot, color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                selectedIcon: const Icon(LucideIcons.bot, color: AppColors.primaryBlue),
                label: 'AI Assistant',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.users, color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                selectedIcon: const Icon(LucideIcons.users, color: AppColors.primaryBlue),
                label: 'Family',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.user, color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                selectedIcon: const Icon(LucideIcons.user, color: AppColors.primaryBlue),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
