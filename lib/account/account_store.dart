import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDeviceId = 'tvmate_device_id';
const _kDeviceKey = 'tvmate_device_key';
const _kDeviceSecret = 'tvmate_device_secret';
const _kAccessToken = 'tvmate_access_token';
const _kRefreshToken = 'tvmate_refresh_token';
const _kUserJson = 'tvmate_user';

class AccountStore extends ChangeNotifier {
  AccountStore._();
  static final instance = AccountStore._();

  final _secure = const FlutterSecureStorage();
  bool _loaded = false;

  String? _deviceId;
  String? _deviceKey;
  String? _deviceSecret;
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;

  String? get deviceId => _deviceId;
  String? get deviceKey => _deviceKey;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null && _accessToken != null;
  bool get hasDevice => _deviceId != null;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _deviceId = await _secure.read(key: _kDeviceId);
    _deviceKey = await _secure.read(key: _kDeviceKey);
    _deviceSecret = await _secure.read(key: _kDeviceSecret);
    _accessToken = await _secure.read(key: _kAccessToken);
    _refreshToken = await _secure.read(key: _kRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_kUserJson);
    if (userStr != null) {
      try { _user = jsonDecode(userStr) as Map<String, dynamic>; } catch (_) {}
    }
    _loaded = true;
  }

  Future<void> saveDevice(String id, String key, String secret) async {
    _deviceId = id;
    _deviceKey = key;
    _deviceSecret = secret;
    await _secure.write(key: _kDeviceId, value: id);
    await _secure.write(key: _kDeviceKey, value: key);
    await _secure.write(key: _kDeviceSecret, value: secret);
    notifyListeners();
  }

  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _secure.write(key: _kAccessToken, value: access);
    await _secure.write(key: _kRefreshToken, value: refresh);
    notifyListeners();
  }

  Future<void> saveUser(Map<String, dynamic> u) async {
    _user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserJson, jsonEncode(u));
    notifyListeners();
  }

  Future<void> clearAuth() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _secure.delete(key: _kAccessToken);
    await _secure.delete(key: _kRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserJson);
    notifyListeners();
  }

  /// Serialized for [TvMateBackupService] **personal** exports only.
  /// Returns `null` when there is nothing to restore (no device, no session).
  Future<Map<String, dynamic>?> exportForBackup() async {
    await ensureLoaded();
    final out = <String, dynamic>{};
    if (_deviceId != null) out['deviceId'] = _deviceId;
    if (_deviceKey != null) out['deviceKey'] = _deviceKey;
    if (_deviceSecret != null) out['deviceSecret'] = _deviceSecret;
    if (_accessToken != null) out['accessToken'] = _accessToken;
    if (_refreshToken != null) out['refreshToken'] = _refreshToken;
    if (_user != null) out['user'] = _user;
    if (out.isEmpty) return null;
    return out;
  }

  /// Restores account/device/session from a **personal** backup. Share backups
  /// must not include this block. Idempotent: missing keys are skipped.
  Future<void> applyFromBackup(Map<String, dynamic>? m) async {
    await ensureLoaded();
    if (m == null || m.isEmpty) return;
    await clearAuth();
    final did = m['deviceId'] as String?;
    final dk = m['deviceKey'] as String?;
    final ds = m['deviceSecret'] as String?;
    if (did != null && dk != null && ds != null) {
      await saveDevice(did, dk, ds);
    }
    final at = m['accessToken'] as String?;
    final rt = m['refreshToken'] as String?;
    if (at != null && rt != null) {
      await saveTokens(at, rt);
    }
    final u = m['user'];
    if (u is Map<String, dynamic>) {
      await saveUser(u);
    }
  }
}

final accountStore = AccountStore.instance;
