import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum StatusType { stable, attention, critical, inactive }

class StatusChip extends StatelessWidget {
  final String _text;
  final StatusType _type;

  StatusChip({
    super.key,
    String? text,
    String? label,
    dynamic type,
    dynamic status,
  })  : _text = text ?? label ?? '',
        _type = _resolveType(type ?? status);

  static StatusType _resolveType(dynamic value) {
    if (value == null) return StatusType.stable;
    if (value is StatusType) return value;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'stable':
        case 'success':
        case 'completed':
          return StatusType.stable;
        case 'attention':
        case 'warning':
        case 'pending':
        case 'primary':
          return StatusType.attention;
        case 'critical':
        case 'danger':
        case 'cancelled':
          return StatusType.critical;
        case 'inactive':
        case 'gray':
          return StatusType.inactive;
        default:
          return StatusType.stable;
      }
    }
    return StatusType.stable;
  }

  Color get _color {
    switch (_type) {
      case StatusType.stable:
        return AppColors.success;
      case StatusType.attention:
        return AppColors.warning;
      case StatusType.critical:
        return AppColors.danger;
      case StatusType.inactive:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
