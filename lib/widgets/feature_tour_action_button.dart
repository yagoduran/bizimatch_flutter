import 'package:flutter/material.dart';

/// Botoi sinple eta estilizatua, feature tour edo tutorial pantailatan erabiltzeko.
///
/// Parametroak:
/// - `label`: Botoian erakutsiko den testua.
/// - `onTap`: `VoidCallback` gisa pasatzen den ekintza, erabiltzaileak botoia sakatzen duenean exekutatuko dena.
///   Callback hau ez du widget-ak aldatzen; ordea, aplikazioaren egoera kanpoan alda daiteke.
/// - `primary`: Boolean bat; true bada estilo nagusiagoa (kolore betearekin) aplikatzen da.
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
        // `onTap` callback-a hemen pass-through egiten da InkWell-era.
        // Erabiltzailearen interakzioa kanpoko logikari pasatzen zaio.
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
