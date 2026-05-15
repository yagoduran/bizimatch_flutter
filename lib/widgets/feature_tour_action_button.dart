import 'package:flutter/material.dart';

class FeatureTourActionButton extends StatelessWidget {
  const FeatureTourActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  static const Color _emerald = Color(0xFF2ECC71);

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : const Color(0xFF475467);
    final background = primary ? _emerald : const Color(0xFFF2F4F7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
