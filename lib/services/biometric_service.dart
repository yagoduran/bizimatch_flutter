import 'package:local_auth/local_auth.dart';

/// BiometricService: gailuaren biometria bidezko autentikazioa kudeatzen du.
///
/// Zer egiten duen:
/// - Gailuak biometria onartzen duen egiaztatzen du eta autentikazio eskaera egiten du.
/// Parametroak: ez du parametrorik jasotzen. Itzulera: `Future<bool>` arrakasta adierazteko.
class BiometricService {
  BiometricService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> authenticate() async {
    /// Gailuko biometria erabiliz erabiltzailearen identitatea baieztatzen du.
    ///
    /// Itzulera: `true` autentikazioa arrakastatsua bada, bestela `false`.
    try {
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      final isDeviceSupported = await _localAuthentication.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }

      // Biometric prompt-a abian jartzen dugu, token edo sinadura helburuetarako.
      return await _localAuthentication.authenticate(
        localizedReason:
            'Confirma tu identidad para firmar y generar el contrato.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } catch (_) {
      return false;
    }
  }
}
