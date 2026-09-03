import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClear;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search doctors, symptoms, medications...',
    this.onChanged,
    this.onFilterTap,
    this.onClear,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.leading,
    this.trailing,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131C2E) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.border.withValues(alpha: 0.8);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                leading ??
                    const Icon(
                      LucideIcons.search,
                      color: AppColors.secondaryText,
                      size: 20,
                    ),
                const SizedBox(width: 12),
                Expanded(
                  child: readOnly
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            hintText,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        )
                      : TextField(
                          controller: controller,
                          onChanged: onChanged,
                          autofocus: autofocus,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                ),
                if (trailing != null)
                  trailing!
                else if (onFilterTap != null)
                  IconButton(
                    icon: const Icon(LucideIcons.slidersHorizontal, size: 18, color: AppColors.primaryBlue),
                    onPressed: onFilterTap,
                    tooltip: 'Filter',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
