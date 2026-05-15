import 'package:flutter/material.dart';

import '../app_theme.dart';

class BadgeWidget extends StatelessWidget {
  const BadgeWidget({
    required this.icon,
    required this.label,
    super.key,
    this.colors = AppTheme.emeraldIndigo,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final fillColor = Colors.white.withValues(alpha: isDark ? 0.06 : 0.72);

    return SizedBox(
      width: 112,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(1.3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: isDark ? 0.24 : 0.14),
                  blurRadius: 22,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.36),
                ),
              ),
              child: Icon(icon, color: colors.first, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
