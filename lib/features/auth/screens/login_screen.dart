import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/providers/providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        LucideIcons.activity,
                        size: 36,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
                const SizedBox(height: 16),
                Text(
                  'Ardius Care',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navy,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: -0.1),
                const SizedBox(height: 6),
                Text(
                  'Connecting patients, families, and doctors through intelligent continuous care.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    height: 1.4,
                  ),
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 36),

                // Form Inputs Container
                AppCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 24,
                  elevation: 1,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: 'demo@ardius.care',
                        style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                          prefixIcon: const Icon(LucideIcons.mail, size: 18, color: AppColors.primaryBlue),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: 'password123',
                        obscureText: true,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                          prefixIcon: const Icon(LucideIcons.lock, size: 18, color: AppColors.primaryBlue),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Sign In',
                        icon: LucideIcons.logIn,
                        onPressed: () {
                          context.go('/role-select');
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05),

                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark ? const Color(0xFF334155) : AppColors.border,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR QUICK LOGIN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF64748B) : AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark ? const Color(0xFF334155) : AppColors.border,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 24),

                // Quick Demo Roles
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: LucideIcons.user,
                        title: 'Patient Demo',
                        subtitle: 'Margaret Chen',
                        isDark: isDark,
                        onTap: () {
                          ref.read(authProvider.notifier).loginAsPatient();
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RoleCard(
                        icon: LucideIcons.stethoscope,
                        title: 'Doctor Demo',
                        subtitle: 'Dr. Aisha Patel',
                        isDark: isDark,
                        onTap: () {
                          ref.read(authProvider.notifier).loginAsDoctor();
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      borderRadius: 18,
      elevation: 0.5,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                  : AppColors.softBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
