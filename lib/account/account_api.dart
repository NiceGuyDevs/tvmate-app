import 'dart:convert';
import 'package:http/http.dart' as http;
import 'account_store.dart';

/// Base URL for the TVMate backend — override via --dart-define=API_BASE_URL=...
const String _kDefaultBase = 'https://tvmate.app/api';
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _kDefaultBase);

class AccountApi {
  AccountApi._();
  static final instance = AccountApi._();

  bool _refreshing = false;

  /// Fires when any API call receives a 403 with a banned/suspended message.
  /// The value is the reason string (e.g. 'USER_BANNED', 'DEVICE_BANNED').
  /// Shell listens to this for instant kicked-screen navigation.
  void Function(String reason)? onBannedOrSuspended;

  String get _base => apiBaseUrl;

  Map<String, String> _headers({bool auth = false}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    final token = accountStore.accessToken;
    if (auth && token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Future<Map<String, dynamic>> _json(http.Response res) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(res.statusCode, 'Invalid server response');
    }
    if (res.statusCode >= 400) {
      final errMsg = body['error']?.toString() ?? 'Request failed';
      final errCode = body['code']?.toString();
      // Instantly signal ban/suspend from ANY API call
      if (res.statusCode == 403) {
        final lower = errMsg.toLowerCase();
        if (lower.contains('banned')) {
          onBannedOrSuspended?.call(lower.contains('device') ? 'DEVICE_BANNED' : 'USER_BANNED');
        } else if (lower.contains('suspended')) {
          onBannedOrSuspended?.call(lower.contains('device') ? 'DEVICE_SUSPENDED' : 'USER_SUSPENDED');
        }
      }
      throw ApiException(res.statusCode, errMsg, code: errCode, data: body);
    }
    return body;
  }

  /// Checks a raw response for 403 banned/suspended and fires the global callback.
  void _checkBanSuspend(http.Response res) {
    if (res.statusCode == 403) {
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final errMsg = (body['error']?.toString() ?? '').toLowerCase();
        if (errMsg.contains('banned')) {
          onBannedOrSuspended?.call(errMsg.contains('device') ? 'DEVICE_BANNED' : 'USER_BANNED');
        } else if (errMsg.contains('suspended')) {
          onBannedOrSuspended?.call(errMsg.contains('device') ? 'DEVICE_SUSPENDED' : 'USER_SUSPENDED');
        }
      } catch (_) {}
    }
  }

  /// Attempt to silently refresh the access token using the stored refresh token.
  /// Returns true if refresh succeeded and new tokens were saved.
  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    final rt = accountStore.refreshToken;
    if (rt == null) return false;
    _refreshing = true;
    try {
      final res = await refresh(rt);
      await accountStore.saveTokens(
        res['accessToken'] as String,
        res['refreshToken'] as String,
      );
      if (res['user'] != null) {
        await accountStore.saveUser(res['user'] as Map<String, dynamic>);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  /// Execute an authenticated request with automatic token refresh on 401.
  Future<http.Response> _authGet(String url) async {
    var res = await http.get(Uri.parse(url), headers: _headers(auth: true));
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.get(Uri.parse(url), headers: _headers(auth: true));
    }
    return res;
  }

  Future<http.Response> _authPost(String url, {Object? body}) async {
    var res = await http.post(Uri.parse(url), headers: _headers(auth: true),
        body: body != null ? jsonEncode(body) : null);
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.post(Uri.parse(url), headers: _headers(auth: true),
          body: body != null ? jsonEncode(body) : null);
    }
    return res;
  }

  Future<http.Response> _authPatch(String url, {Object? body}) async {
    var res = await http.patch(Uri.parse(url), headers: _headers(auth: true),
        body: body != null ? jsonEncode(body) : null);
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.patch(Uri.parse(url), headers: _headers(auth: true),
          body: body != null ? jsonEncode(body) : null);
    }
    return res;
  }

  Future<http.Response> _authPut(String url, {Object? body}) async {
    var res = await http.put(Uri.parse(url), headers: _headers(auth: true),
        body: body != null ? jsonEncode(body) : null);
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.put(Uri.parse(url), headers: _headers(auth: true),
          body: body != null ? jsonEncode(body) : null);
    }
    return res;
  }

  Future<http.Response> _authDelete(String url) async {
    var res = await http.delete(Uri.parse(url), headers: _headers(auth: true));
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.delete(Uri.parse(url), headers: _headers(auth: true));
    }
    return res;
  }

  // ── Device ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> registerDevice(String fingerprint, {Map<String, dynamic>? metadata}) async {
    final res = await http.post(
      Uri.parse('$_base/v1/devices/register'),
      headers: _headers(),
      body: jsonEncode({'fingerprint': fingerprint, if (metadata != null) 'metadata': metadata}),
    );
    return _json(res);
  }

  // ── Auth ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
    String email,
    String password, {
    String? deviceId,
    String? removeDeviceId,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/v1/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        if (deviceId != null) 'deviceId': deviceId,
        if (removeDeviceId != null) 'removeDeviceId': removeDeviceId,
      }),
    );
    return _json(res);
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? deviceId,
    String? removeDeviceId,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/v1/auth/login'),
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        if (deviceId != null) 'deviceId': deviceId,
        if (removeDeviceId != null) 'removeDeviceId': removeDeviceId,
      }),
    );
    return _json(res);
  }

  Future<Map<String, dynamic>> googleLogin(
    String idToken, {
    String? deviceId,
    String? removeDeviceId,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/v1/auth/google'),
      headers: _headers(),
      body: jsonEncode({
        'idToken': idToken,
        if (deviceId != null) 'deviceId': deviceId,
        if (removeDeviceId != null) 'removeDeviceId': removeDeviceId,
      }),
    );
    return _json(res);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final res = await http.post(
      Uri.parse('$_base/v1/auth/refresh'),
      headers: _headers(),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    return _json(res);
  }

  Future<void> logout(String refreshToken) async {
    await _authPost('$_base/v1/auth/logout', body: {'refreshToken': refreshToken});
  }

  // ── Access ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> validateAccess({Map<String, dynamic>? metadata}) async {
    final res = await _authPost('$_base/v1/access/validate',
        body: {if (metadata != null) 'metadata': metadata});
    return _json(res);
  }

  // ── Profile / Devices ──────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    final res = await _authGet('$_base/v1/me');
    return _json(res);
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    final res = await _authPatch('$_base/v1/me', body: body);
    return _json(res);
  }

  Future<List<dynamic>> getDevices() async {
    final res = await _authGet('$_base/v1/me/devices');
    _checkBanSuspend(res);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, 'Failed to get devices');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<void> renameDevice(String deviceId, String label) async {
    final res = await _authPatch('$_base/v1/me/devices/$deviceId', body: {'label': label});
    _checkBanSuspend(res);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, 'Rename failed');
  }

  Future<void> removeDevice(String deviceId) async {
    final res = await _authDelete('$_base/v1/me/devices/$deviceId');
    _checkBanSuspend(res);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, 'Remove failed');
  }

  // ── Playlists (admin push, one-way pull) ────────────────────────
  // Playlists are no longer client-creatable. The server returns the rows
  // an admin pushed for this (user, device) pair; user edits / deletes
  // propagate back via PUT / DELETE so the admin can see them.
  Future<List<dynamic>> getPlaylists() async {
    final res = await _authGet('$_base/v1/me/playlists');
    _checkBanSuspend(res);
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, 'Failed to get playlists');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw ApiException(res.statusCode, 'Unexpected playlist response format');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> updatePlaylist(String id, {
    String? name,
    String? serverUrl,
    String? username,
    String? password,
    String? m3uUrl,
  }) async {
    final res = await _authPut('$_base/v1/me/playlists/$id', body: {
      if (name != null) 'name': name,
      if (serverUrl != null) 'serverUrl': serverUrl,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (m3uUrl != null) 'm3uUrl': m3uUrl,
    });
    return _json(res);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final res = await _authDelete('$_base/v1/me/playlists/$playlistId');
    _checkBanSuspend(res);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, 'Delete failed');
  }

  // ── Payments ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createCheckout(String planId, {String durationId = '1mo'}) async {
    final res = await _authPost('$_base/v1/payments/create-checkout',
        body: {'planId': planId, 'durationId': durationId});
    return _json(res);
  }
}

final accountApi = AccountApi.instance;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? data;
  ApiException(this.statusCode, this.message, {this.code, this.data});
  @override
  String toString() => message;
}
