import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'account_api.dart';
import 'account_store.dart';

const _kDeviceChannel = MethodChannel('com.tvmate.app/device');

/// Orchestrates the device-registration → access-validation flow on app launch.
/// First launch: register device → 30-day trial → full access (no login needed).
/// After trial expires: paywall shown, user must create an account + subscribe.
class AccessGate {
  AccessGate._();
  static final instance = AccessGate._();

  AccessResult? lastResult;

  Future<AccessResult> check() async {
    await accountStore.ensureLoaded();

    // 1. Ensure device is registered (first launch → auto 30-day trial)
    if (!accountStore.hasDevice) {
      try {
        final fingerprint = await _getHardwareFingerprint();
        final metadata = await _getDeviceMetadata();
        final res = await accountApi.registerDevice(fingerprint, metadata: metadata);
        await accountStore.saveDevice(
          res['deviceId'] as String,
          res['deviceKey'] as String,
          res['deviceSecret'] as String,
        );
        await accountStore.saveTokens(
          res['accessToken'] as String,
          res['refreshToken'] as String,
        );
      } catch (e) {
        debugPrint('[AccessGate] device register failed: $e');
        lastResult = AccessResult(allowed: false, reason: 'NETWORK_ERROR');
        return lastResult!;
      }
    }

    // 2. Proactively refresh if we have a refresh token (handles expired access tokens)
    if (accountStore.refreshToken != null) {
      try {
        final res = await accountApi.refresh(accountStore.refreshToken!);
        await accountStore.saveTokens(
          res['accessToken'] as String,
          res['refreshToken'] as String,
        );
        if (res['user'] != null) await accountStore.saveUser(res['user'] as Map<String, dynamic>);
      } catch (e) {
        // Detect ban/suspend during token refresh (backend returns 403)
        if (e is ApiException && e.statusCode == 403) {
          final msg = e.message.toLowerCase();
          if (msg.contains('banned')) {
            lastResult = AccessResult(allowed: false, reason: msg.contains('device') ? 'DEVICE_BANNED' : 'USER_BANNED');
            return lastResult!;
          }
          if (msg.contains('suspended')) {
            lastResult = AccessResult(allowed: false, reason: msg.contains('device') ? 'DEVICE_SUSPENDED' : 'USER_SUSPENDED');
            return lastResult!;
          }
        }
        if (accountStore.accessToken == null) {
          await accountStore.clearAuth();
        }
      }
    }

    // 2b. If user signed out (or refresh wiped tokens) but the device is still
    // registered, re-mint device-only tokens so /access/validate runs as the
    // device and surfaces TRIAL_EXPIRED / trialConsumed correctly.
    if (accountStore.accessToken == null && accountStore.hasDevice) {
      try {
        final fingerprint = await _getHardwareFingerprint();
        final metadata = await _getDeviceMetadata();
        final res = await accountApi.registerDevice(fingerprint, metadata: metadata);
        await accountStore.saveTokens(
          res['accessToken'] as String,
          res['refreshToken'] as String,
        );
      } catch (e) {
        debugPrint('[AccessGate] device re-register failed: $e');
      }
    }

    // 3. Validate access (works for both device-only and logged-in users)
    if (accountStore.accessToken != null) {
      try {
        final metadata = await _getDeviceMetadata();
        final res = await accountApi.validateAccess(metadata: metadata);
        final serverAllowed = res['allowed'] == true;
        final reason = res['reason']?.toString() ?? (serverAllowed ? 'OK' : 'UNKNOWN');

        if (reason.contains('BANNED') || reason.contains('SUSPENDED')) {
          lastResult = AccessResult(allowed: false, reason: reason);
          return lastResult!;
        }

        lastResult = AccessResult(
          allowed: true,
          reason: reason,
          trialEndsAt: res['trialEndsAt'] as String?,
          accessGrantedUntil: res['accessGrantedUntil'] as String?,
          needsSubscription: !serverAllowed,
        );
        return lastResult!;
      } catch (e) {
        debugPrint('[AccessGate] validate failed: $e');
        // Detect banned/suspended from HTTP 403 middleware responses
        final msg = e.toString().toLowerCase();
        if (e is ApiException && (e.statusCode == 403 || e.statusCode == 401)) {
          if (msg.contains('banned')) {
            lastResult = AccessResult(allowed: false, reason: msg.contains('device') ? 'DEVICE_BANNED' : 'USER_BANNED');
            return lastResult!;
          }
          if (msg.contains('suspended')) {
            lastResult = AccessResult(allowed: false, reason: msg.contains('device') ? 'DEVICE_SUSPENDED' : 'USER_SUSPENDED');
            return lastResult!;
          }
        }
        if (lastResult != null && lastResult!.allowed) {
          return lastResult!;
        }
        lastResult = AccessResult(allowed: false, reason: 'NETWORK_ERROR');
        return lastResult!;
      }
    }

    lastResult = AccessResult(allowed: false, reason: 'NO_TOKEN');
    return lastResult!;
  }

  Future<String> _getHardwareFingerprint() async {
    if (Platform.isAndroid) {
      try {
        final String? androidId =
            await _kDeviceChannel.invokeMethod('getAndroidId');
        if (androidId != null && androidId.isNotEmpty) return androidId;
      } catch (e) {
        debugPrint('[AccessGate] getAndroidId failed: $e');
      }
    } else if (Platform.isWindows) {
      try {
        final result = await Process.run(
          'wmic',
          ['csproduct', 'get', 'UUID'],
          runInShell: true,
        );
        if (result.exitCode == 0) {
          final lines = (result.stdout as String)
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l != 'UUID')
              .toList();
          if (lines.isNotEmpty && lines.first.length >= 8) {
            return lines.first.toLowerCase();
          }
        }
      } catch (e) {
        debugPrint('[AccessGate] Windows HWID failed: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        final result = await Process.run(
          'ioreg',
          ['-rd1', '-c', 'IOPlatformExpertDevice'],
        );
        if (result.exitCode == 0) {
          final stdout = result.stdout as String;
          final match =
              RegExp(r'"IOPlatformUUID"\s*=\s*"([^"]+)"').firstMatch(stdout);
          if (match != null) return match.group(1)!.toLowerCase();
        }
      } catch (e) {
        debugPrint('[AccessGate] macOS HWID failed: $e');
      }
    }
    final r = Random.secure();
    return List.generate(
        32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Map<String, dynamic>?> _getDeviceMetadata() async {
    if (Platform.isAndroid) {
      try {
        final result =
            await _kDeviceChannel.invokeMethod<Map>('getFullDeviceInfo');
        if (result != null) return Map<String, dynamic>.from(result);
      } catch (e) {
        debugPrint('[AccessGate] getFullDeviceInfo failed: $e');
      }
      return null;
    }

    // Desktop metadata via dart:io
    final meta = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'hostname': Platform.localHostname,
      'locale': Platform.localeName,
      'dartVersion': Platform.version,
      'deviceType': 'desktop',
    };

    if (Platform.isWindows) {
      try {
        final cpu = await Process.run('wmic', ['cpu', 'get', 'Name'],
            runInShell: true);
        if (cpu.exitCode == 0) {
          final lines = (cpu.stdout as String)
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l != 'Name')
              .toList();
          if (lines.isNotEmpty) meta['cpuModel'] = lines.first;
        }
      } catch (_) {}
      try {
        final mem = await Process.run(
            'wmic',
            ['ComputerSystem', 'get', 'TotalPhysicalMemory'],
            runInShell: true);
        if (mem.exitCode == 0) {
          final lines = (mem.stdout as String)
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l != 'TotalPhysicalMemory')
              .toList();
          if (lines.isNotEmpty) {
            final bytes = int.tryParse(lines.first);
            if (bytes != null) meta['totalRamMb'] = bytes ~/ (1024 * 1024);
          }
        }
      } catch (_) {}
      try {
        final model = await Process.run(
            'wmic', ['csproduct', 'get', 'Name'],
            runInShell: true);
        if (model.exitCode == 0) {
          final lines = (model.stdout as String)
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l != 'Name')
              .toList();
          if (lines.isNotEmpty) meta['model'] = lines.first;
        }
      } catch (_) {}
      try {
        final mfg = await Process.run(
            'wmic', ['csproduct', 'get', 'Vendor'],
            runInShell: true);
        if (mfg.exitCode == 0) {
          final lines = (mfg.stdout as String)
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l != 'Vendor')
              .toList();
          if (lines.isNotEmpty) meta['manufacturer'] = lines.first;
        }
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        final sw = await Process.run('sw_vers', []);
        if (sw.exitCode == 0) meta['swVers'] = (sw.stdout as String).trim();
      } catch (_) {}
      try {
        final hw = await Process.run(
            'sysctl', ['-n', 'hw.model']);
        if (hw.exitCode == 0) meta['model'] = (hw.stdout as String).trim();
      } catch (_) {}
      try {
        final mem = await Process.run(
            'sysctl', ['-n', 'hw.memsize']);
        if (mem.exitCode == 0) {
          final bytes = int.tryParse((mem.stdout as String).trim());
          if (bytes != null) meta['totalRamMb'] = bytes ~/ (1024 * 1024);
        }
      } catch (_) {}
    }

    return meta;
  }
}

final accessGate = AccessGate.instance;

class AccessResult {
  final bool allowed;
  final String reason;
  final String? trialEndsAt;
  final String? accessGrantedUntil;
  final bool needsSubscription;
  AccessResult({
    required this.allowed,
    required this.reason,
    this.trialEndsAt,
    this.accessGrantedUntil,
    this.needsSubscription = false,
  });
}
