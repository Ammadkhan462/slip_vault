import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to open Slip Vault',
        biometricOnly: false,
      );
    } on PlatformException {
      return false;
    }
  }
}
