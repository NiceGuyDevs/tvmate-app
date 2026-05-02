import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'xtream_exceptions.dart';
import 'xtream_url.dart';

/// Minimal Xtream Codes `player_api.php` client (JSON).
class XtreamApiClient {
  XtreamApiClient({
    required String baseUrl,
    required this.username,
    required this.password,
  }) : playerApi = xtreamPlayerApiUri(baseUrl);

  final Uri playerApi;
  final String username;
  final String password;

  Map<String, String> _query({
    String? action,
    Map<String, String>? extra,
  }) {
    final q = <String, String>{
      'username': username,
      'password': password,
    };
    if (action != null && action.isNotEmpty) {
      q['action'] = action;
    }
    if (extra != null) {
      q.addAll(extra);
    }
    return q;
  }

  Future<dynamic> _getJson({
    String? action,
    Map<String, String>? extra,
  }) async {
    final uri = playerApi.replace(queryParameters: _query(action: action, extra: extra));
    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw XtreamNetworkException('Connection timed out. Please try again.');
    } on SocketException catch (e) {
      // Keep the raw OS-level detail in logs only — UI gets a friendly phrase.
      debugPrint('[Xtream] SocketException: ${e.message}');
      throw XtreamNetworkException('Connection lost. Please check your network.');
    } on HttpException catch (e) {
      debugPrint('[Xtream] HttpException: ${e.message}');
      throw XtreamNetworkException('Server unreachable. Please try again.');
    }

    final preview = res.body.length > 200 ? '${res.body.substring(0, 200)}…' : res.body;
    debugPrint(
      '[Xtream] GET action=${action ?? '(auth)'} status=${res.statusCode} '
      'bodyLen=${res.body.length} preview=$preview',
    );

    if (res.statusCode != 200) {
      // Many panels return 404/401/403 for bad credentials or wrong player_api URL.
      // Show a clear message instead of a raw "HTTP 404".
      if (res.statusCode == 404 ||
          res.statusCode == 401 ||
          res.statusCode == 403) {
        throw XtreamAuthException('Bad PlayList Login');
      }
      throw XtreamNetworkException('Server error (${res.statusCode}). Please try again.');
    }
    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw XtreamParseException('Invalid JSON from server.');
    }
  }

  /// Validates credentials (`player_api.php` without action, or with action empty).
  Future<void> verifyAuth() async {
    await verifyAuthAndGetUserInfo();
  }

  /// Same as [verifyAuth] but returns `user_info` (e.g. `exp_date`) from the auth JSON.
  Future<Map<String, dynamic>> verifyAuthAndGetUserInfo() async {
    final json = await _getJson();
    _assertAuthorized(json);
    if (json is Map && json['user_info'] is Map) {
      return Map<String, dynamic>.from(json['user_info'] as Map);
    }
    return {};
  }

  /// Returns the server_info block from the auth response.
  /// Contains `timezone`, `time_now`, `timestamp_now` etc.
  Future<Map<String, dynamic>> getServerInfo() async {
    final json = await _getJson();
    if (json is Map && json['server_info'] is Map) {
      return Map<String, dynamic>.from(json['server_info'] as Map);
    }
    return const {};
  }

  void _assertAuthorized(dynamic json) {
    if (json is! Map) {
      throw XtreamAuthException('Unexpected server response.');
    }
    final ui = json['user_info'];
    if (ui == null) {
      throw XtreamAuthException('Invalid credentials or server response.');
    }
    if (ui is Map) {
      final auth = ui['auth'];
      if (auth == 0 || auth == '0') {
        throw XtreamAuthException('Invalid username or password.');
      }
      final status = ui['status']?.toString().toLowerCase();
      if (status == 'banned' || status == 'disabled') {
        throw XtreamAuthException('Account is not active.');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getLiveCategories() async =>
      _asMapList(await _getJson(action: 'get_live_categories'));

  Future<List<Map<String, dynamic>>> getLiveStreams() async =>
      _getJsonMapListIsolate(action: 'get_live_streams');

  Future<List<Map<String, dynamic>>> getVodCategories() async =>
      _asMapList(await _getJson(action: 'get_vod_categories'));

  Future<List<Map<String, dynamic>>> getVodStreams() async =>
      _getJsonMapListIsolate(action: 'get_vod_streams');

  Future<List<Map<String, dynamic>>> getSeriesCategories() async =>
      _asMapList(await _getJson(action: 'get_series_categories'));

  Future<List<Map<String, dynamic>>> getSeriesList() async =>
      _getJsonMapListIsolate(action: 'get_series');

  /// Short EPG for one live stream (`stream_id` + optional `limit`).
  ///
  /// Some panels honor [startUnix] / [endUnix] (Unix seconds) to limit the
  /// programme window; others ignore them and return a sliding window from "now".
  Future<dynamic> getShortEpg({
    required String streamId,
    int limit = 16,
    int? startUnix,
    int? endUnix,
  }) async {
    final extra = <String, String>{
      'stream_id': streamId,
      'limit': limit.toString(),
    };
    if (startUnix != null) extra['start'] = '$startUnix';
    if (endUnix != null) extra['end'] = '$endUnix';
    return _getJson(
      action: 'get_short_epg',
      extra: extra,
    );
  }

  /// Fuller EPG table for one stream (same shape as short EPG on many panels).
  Future<dynamic> getSimpleDataTable({
    required String streamId,
    int limit = 32,
    int? startUnix,
    int? endUnix,
  }) async {
    final extra = <String, String>{
      'stream_id': streamId,
      'limit': limit.toString(),
    };
    if (startUnix != null) extra['start'] = '$startUnix';
    if (endUnix != null) extra['end'] = '$endUnix';
    return _getJson(
      action: 'get_simple_data_table',
      extra: extra,
    );
  }

  /// Calls `get_simple_data_table` with ONLY stream_id — no limit, no date
  /// range. According to the Xtream API docs this returns ALL EPG data
  /// (past + future) for the stream.
  Future<dynamic> getAllEpg({required String streamId}) async {
    return _getJson(
      action: 'get_simple_data_table',
      extra: {'stream_id': streamId},
    );
  }

  /// Full-day EPG fetch with multiple fallback strategies.
  ///
  /// When [forDay] is set, requests that calendar day in the device's local
  /// timezone as Unix [start,end) when the panel supports range parameters.
  Future<dynamic> getFullDayEpg({
    required String streamId,
    DateTime? forDay,
  }) async {
    int? startUnix;
    int? endUnix;
    if (forDay != null) {
      final dayStart = DateTime(forDay.year, forDay.month, forDay.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      startUnix = dayStart.millisecondsSinceEpoch ~/ 1000;
      endUnix = dayEnd.millisecondsSinceEpoch ~/ 1000;
    }

    dynamic best;
    int bestCount = 0;

    const recordingEpgLimit = 2000;

    try {
      final raw = await getShortEpg(
        streamId: streamId,
        limit: recordingEpgLimit,
        startUnix: startUnix,
        endUnix: endUnix,
      );
      final count = _listingsFromRaw(raw).length;
      if (count > bestCount) { best = raw; bestCount = count; }
    } catch (_) {}

    if (bestCount < 10) {
      try {
        final raw = await getSimpleDataTable(
          streamId: streamId,
          limit: recordingEpgLimit,
          startUnix: startUnix,
          endUnix: endUnix,
        );
        final count = _listingsFromRaw(raw).length;
        if (count > bestCount) { best = raw; bestCount = count; }
      } catch (_) {}
    }

    if (bestCount < 5) {
      try {
        final extra = <String, String>{'stream_id': streamId};
        if (startUnix != null) extra['start'] = '$startUnix';
        if (endUnix != null) extra['end'] = '$endUnix';
        final raw = await _getJson(
          action: 'get_short_epg',
          extra: extra,
        );
        final count = _listingsFromRaw(raw).length;
        if (count > bestCount) { best = raw; bestCount = count; }
      } catch (_) {}
    }

    return best ?? const <dynamic>[];
  }

  List<dynamic> _listingsFromRaw(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      for (final key in const [
        'epg_listings',
        'listings',
        'epg',
        'data',
        'programs',
      ]) {
        final v = json[key];
        if (v is List) return v;
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    final json = await _getJson(
      action: 'get_series_info',
      extra: {'series_id': seriesId},
    );
    if (json is! Map<String, dynamic>) {
      throw XtreamParseException('Invalid series info.');
    }
    return json;
  }

  /// Fetches raw HTTP body and decodes JSON + converts to List<Map> in a
  /// background isolate. Used for large payloads (streams, VOD, series) to
  /// keep the main thread free for rendering.
  Future<List<Map<String, dynamic>>> _getJsonMapListIsolate({
    required String action,
  }) async {
    final uri = playerApi.replace(
      queryParameters: _query(action: action),
    );
    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw XtreamNetworkException('Connection timed out. Please try again.');
    } on SocketException catch (e) {
      debugPrint('[Xtream] SocketException: ${e.message}');
      throw XtreamNetworkException('Connection lost. Please check your network.');
    } on HttpException catch (e) {
      debugPrint('[Xtream] HttpException: ${e.message}');
      throw XtreamNetworkException('Server unreachable. Please try again.');
    }

    debugPrint(
      '[Xtream] GET action=$action status=${res.statusCode} '
      'bodyLen=${res.body.length}',
    );

    if (res.statusCode != 200) {
      if (res.statusCode == 404 ||
          res.statusCode == 401 ||
          res.statusCode == 403) {
        throw XtreamAuthException('Bad PlayList Login');
      }
      throw XtreamNetworkException('Server error (${res.statusCode}). Please try again.');
    }

    try {
      return await compute(_decodeJsonMapList, res.body);
    } catch (e) {
      if (e is XtreamParseException) rethrow;
      throw XtreamParseException('Invalid JSON from server.');
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic json) {
    if (json is! List) {
      throw XtreamParseException('Expected JSON array from server.');
    }
    return json.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

/// Top-level function for compute(): decodes JSON string into a typed map list.
List<Map<String, dynamic>> _decodeJsonMapList(String body) {
  final json = jsonDecode(body);
  if (json is! List) {
    throw XtreamParseException('Expected JSON array from server.');
  }
  return json.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
