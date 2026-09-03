import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _abhaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  UserRole _selectedRole = UserRole.patient;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _abhaController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final email = _emailController.text.trim();
    final abha = _abhaController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your full name.');
      return;
    }
    if (phone.isEmpty) {
      _showError('Phone number is compulsory.');
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      _showError('Please enter a valid 10-digit phone number.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter a password.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    await ref.read(authProvider.notifier).registerUser(
      name: name,
      password: password,
      phoneNumber: cleanPhone,
      role: _selectedRole,
      email: email.isNotEmpty ? email : null,
      abhaId: abha.isNotEmpty ? abha : null,
    );

    if (!mounted) return;

    final error = ref.read(authProvider).error;
    if (error != null) {
      _showError(error);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryBlue),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Account',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join Ardius Care',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1),
              const SizedBox(height: 6),
              Text(
                'Create your account to get started.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 24),

              AppCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role selection
                    Text(
                      'I am a...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _RoleChip(
                          label: 'Patient',
                          icon: LucideIcons.user,
                          selected: _selectedRole == UserRole.patient,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedRole = UserRole.patient),
                        ),
                        const SizedBox(width: 12),
                        _RoleChip(
                          label: 'Doctor',
                          icon: LucideIcons.stethoscope,
                          selected: _selectedRole == UserRole.doctor,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedRole = UserRole.doctor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildField(
                      controller: _nameController,
                      label: 'Full Name *',
                      icon: LucideIcons.user,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _phoneController,
                      label: 'Phone Number (Compulsory) *',
                      icon: LucideIcons.phone,
                      isDark: isDark,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _passwordController,
                      label: 'Password *',
                      icon: LucideIcons.lock,
                      isDark: isDark,
                      obscureText: _obscurePassword,
                      onToggleVisibility: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _confirmController,
                      label: 'Confirm Password *',
                      icon: LucideIcons.lock,
                      isDark: isDark,
                      obscureText: _obscureConfirm,
                      onToggleVisibility: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _emailController,
                      label: 'Email Address (Optional)',
                      icon: LucideIcons.mail,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _abhaController,
                      label: 'ABHA ID (Optional)',
                      icon: LucideIcons.creditCard,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                        : PrimaryButton(
                            label: 'Create Account',
                            icon: LucideIcons.userPlus,
                            onPressed: _register,
                          ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Already have an account? Sign In',
                    style: TextStyle(color: AppColors.primaryBlue, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onToggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
        prefixIcon: Icon(icon, size: 18, color: AppColors.primaryBlue),
        suffixIcon: onToggleVisibility != null
            ? IconButton(
                icon: Icon(
                  obscureText ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryBlue
                : (isDark ? const Color(0xFF1E293B) : AppColors.background),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white : AppColors.navy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
