import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number or email, and password.')),
      );
      return;
    }
    await ref.read(authProvider.notifier).login(email, password);
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loginDemoPatient() async {
    await ref.read(authProvider.notifier).loginAsPatient();
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loginDemoDoctor() async {
    await ref.read(authProvider.notifier).loginAsDoctor();
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

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

                AppCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 24,
                  elevation: 1,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.text,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
                        decoration: InputDecoration(
                          labelText: 'Phone Number or Email',
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          ),
                          prefixIcon: const Icon(LucideIcons.user, size: 18, color: AppColors.primaryBlue),
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
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          ),
                          prefixIcon: const Icon(LucideIcons.lock, size: 18, color: AppColors.primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 18,
                              color: AppColors.primaryBlue,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? const CircularProgressIndicator(color: AppColors.primaryBlue)
                          : PrimaryButton(
                              label: 'Sign In',
                              icon: LucideIcons.logIn,
                              onPressed: _login,
                            ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: Text(
                          "Don't have an account? Register",
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05),

                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : AppColors.border)),
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
                    Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : AppColors.border)),
                  ],
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: LucideIcons.user,
                        title: 'Patient Demo',
                        subtitle: 'Margaret Chen',
                        isDark: isDark,
                        onTap: isLoading ? null : _loginDemoPatient,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RoleCard(
                        icon: LucideIcons.stethoscope,
                        title: 'Doctor Demo',
                        subtitle: 'Dr. Aisha Patel',
                        isDark: isDark,
                        onTap: isLoading ? null : _loginDemoDoctor,
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
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.onTap,
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
