import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasscodeService {
  static const _passcodeHashKey = 'passcode_hash';
  static const _passcodeSaltKey = 'passcode_salt';
  static const _legacyPasscodeKey = 'passcode';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<bool> isPasscodeSet() async {
    final hash = await _secureStorage.read(key: _passcodeHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPasscode(String passcode) async {
    final salt = _generateSalt();
    final hash = _hashPasscode(passcode, salt);
    await _secureStorage.write(key: _passcodeSaltKey, value: salt);
    await _secureStorage.write(key: _passcodeHashKey, value: hash);
  }

  Future<bool> verifyPasscode(String passcode) async {
    final salt = await _secureStorage.read(key: _passcodeSaltKey);
    final savedHash = await _secureStorage.read(key: _passcodeHashKey);

    if (salt == null || savedHash == null) {
      return false;
    }

    return _hashPasscode(passcode, salt) == savedHash;
  }

  Future<void> clearPasscode() async {
    await _secureStorage.delete(key: _passcodeSaltKey);
    await _secureStorage.delete(key: _passcodeHashKey);

    // Ensure legacy storage is also cleared.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPasscodeKey);
  }

  Future<void> migrateLegacyPasscodeIfNeeded() async {
    final hasSecurePasscode = await isPasscodeSet();
    if (hasSecurePasscode) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyPasscode = prefs.getString(_legacyPasscodeKey);
    if (legacyPasscode == null || legacyPasscode.isEmpty) {
      return;
    }

    await setPasscode(legacyPasscode);
    await prefs.remove(_legacyPasscodeKey);
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPasscode(String passcode, String salt) {
    final payload = utf8.encode('$salt:$passcode');
    return sha256.convert(payload).toString();
  }
}
