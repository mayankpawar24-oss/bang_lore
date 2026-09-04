import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../video_call/widgets/incoming_call_overlay.dart';

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
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: IncomingCallListener(child: navigationShell),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 84,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Floating Glassmorphic Dock Container
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      height: 66,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF131C2E).withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppColors.border.withValues(alpha: 0.85),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.45 : 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Left 2 Navigation Items: Home (0) & Family (1)
                          Expanded(
                            child: _buildNavItem(
                              context,
                              index: 0,
                              currentIndex: currentIndex,
                              icon: LucideIcons.home,
                              label: 'Home',
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _buildNavItem(
                              context,
                              index: 1,
                              currentIndex: currentIndex,
                              icon: LucideIcons.users,
                              label: 'Family',
                              isDark: isDark,
                            ),
                          ),

                          // Center Space Reserved for Emerged Button
                          const SizedBox(width: 58),

                          // Right 2 Navigation Items: Timeline (3) & Profile (4)
                          Expanded(
                            child: _buildNavItem(
                              context,
                              index: 3,
                              currentIndex: currentIndex,
                              icon: LucideIcons.clock,
                              label: 'Timeline',
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _buildNavItem(
                              context,
                              index: 4,
                              currentIndex: currentIndex,
                              icon: LucideIcons.user,
                              label: 'Profile',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Emerged Central Blue Action Button (Branch 2: AI Care / Robinson Co-Pilot)
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: () => _goBranch(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.heroGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? const Color(0xFF0A0F1D) : Colors.white,
                            width: 3.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.sparkles,
                            color: Colors.white,
                            size: currentIndex == 2 ? 26 : 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AI Care',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: currentIndex == 2 ? FontWeight.w800 : FontWeight.w600,
                          color: currentIndex == 2
                              ? AppColors.primaryBlue
                              : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ),
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
    required int currentIndex,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = index == currentIndex;
    final color = isSelected
        ? AppColors.primaryBlue
        : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText);

    return InkWell(
      onTap: () => _goBranch(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
