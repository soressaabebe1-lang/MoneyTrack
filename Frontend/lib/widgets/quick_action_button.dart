import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Primary = filled brand green (e.g. Add Income).
  /// Secondary = outlined (e.g. Add Expense).
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPrimary) {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      );
    }

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black87,
          side: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
