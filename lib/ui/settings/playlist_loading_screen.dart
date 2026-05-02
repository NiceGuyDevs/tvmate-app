import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/library_controller.dart';
import '../../data/playlist_type.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';
import '../../xtream/xtream_api_client.dart';
import '../../xtream/xtream_exceptions.dart';
import '../../xtream/xtream_user_info.dart';
import '../../shell/team_shell_backdrop.dart';
import 'player_settings_overlay_scope.dart';

/// Adds a playlist: real Xtream API ingest for Xtream drafts, placeholder for M3U.
class PlaylistLoadingScreen extends StatefulWidget {
  const PlaylistLoadingScreen({super.key, required this.draft});

  final PlaylistDraft draft;

  @override
  State<PlaylistLoadingScreen> createState() => _PlaylistLoadingScreenState();
}

class _PlaylistLoadingScreenState extends State<PlaylistLoadingScreen> {
  final _rnd = Random();

  var _phase = 0;
  var _live = 0;
  var _movies = 0;
  var _series = 0;

  late final int _tLive;
  late final int _tMovies;
  late final int _tSeries;

  var _started = false;

  static const _stepTimeout = Duration(seconds: 50);
  static const _syncTimeout = Duration(seconds: 120);

  @override
  void initState() {
    super.initState();
    _tLive = 800 + _rnd.nextInt(4200);
    _tMovies = 400 + _rnd.nextInt(6100);
    _tSeries = 120 + _rnd.nextInt(1800);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipeline());
  }

  Future<void> _runPipeline() async {
    if (_started || !mounted) return;
    _started = true;

    if (widget.draft.type == PlaylistType.m3u) {
      await _runM3uFakePipeline();
    } else {
      await _runXtreamPipeline();
    }
  }

  Future<void> _runXtreamPipeline() async {
    setState(() => _phase = 0);
    XtreamApiClient? client;
    List<Map<String, dynamic>>? live;
    List<Map<String, dynamic>>? vod;
    List<Map<String, dynamic>>? ser;
    try {
      final d = widget.draft;
      client = XtreamApiClient(
        baseUrl: d.serverUrl!.trim(),
        username: d.username!.trim(),
        password: d.password!,
      );
      final userInfo =
          await client.verifyAuthAndGetUserInfo().timeout(_stepTimeout);
      final subscriptionExpiresAtSec = xtreamParseExpDateUnix(userInfo);
      if (!mounted) return;

      setState(() => _phase = 1);
      live = await client.getLiveStreams().timeout(_stepTimeout);
      if (!mounted) return;
      vod = await client.getVodStreams().timeout(_stepTimeout);
      if (!mounted) return;
      ser = await client.getSeriesList().timeout(_stepTimeout);
      if (!mounted) return;

      setState(() {
        _live = live!.length;
        _movies = vod!.length;
        _series = ser!.length;
        _phase = 2;
      });
      debugPrint(
        'tvmate.xtream.add: streams live=$_live movies=$_movies series=$_series',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      await libraryController.addPlaylist(
        draft: widget.draft,
        liveCount: _live,
        moviesCount: _movies,
        seriesCount: _series,
        subscriptionExpiresAtSec: subscriptionExpiresAtSec,
      );
      try {
        await xtreamCatalogRepository
            .syncFromLibraryWithPrefetchedStreams(
              libraryController,
              client: client,
              liveStreamsRaw: live,
              vodStreamsRaw: vod,
              seriesListRaw: ser,
            )
            .timeout(_syncTimeout);
      } catch (e, st) {
        debugPrint('tvmate.xtream.add catalog sync: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Playlist saved, but full catalog sync failed. '
                'Try switching sections or reopening the app. ($e)',
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimeoutException {
      _fail('Request timed out. Check the server URL and network.');
    } on XtreamAuthException catch (e) {
      _fail(e.message);
    } on XtreamBadUrlException catch (e) {
      _fail(e.message);
    } on XtreamNetworkException catch (e) {
      _fail(e.message);
    } on XtreamParseException catch (e) {
      _fail(e.message);
    } catch (e, st) {
      debugPrint('tvmate.xtream.add error: $e\n$st');
      _fail('Could not add playlist: $e');
    }
  }

  Future<void> _fail(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.teamPalette.surfaceElevated,
          title: const Text('Could not add playlist'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _runM3uFakePipeline() async {
    setState(() => _phase = 0);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() => _phase = 1);
    const totalMs = 2200;
    final sw = Stopwatch()..start();
    while (mounted && sw.elapsedMilliseconds < totalMs) {
      final t = (sw.elapsedMilliseconds / totalMs).clamp(0.0, 1.0);
      setState(() {
        _live = (_tLive * t).round();
        _movies = (_tMovies * t).round();
        _series = (_tSeries * t).round();
      });
      await Future<void>.delayed(const Duration(milliseconds: 48));
    }
    if (!mounted) return;

    setState(() {
      _live = _tLive;
      _movies = _tMovies;
      _series = _tSeries;
      _phase = 2;
    });

    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;

    await libraryController.addPlaylist(
      draft: widget.draft,
      liveCount: _live,
      moviesCount: _movies,
      seriesCount: _series,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (_phase) {
      0 => 'Connecting…',
      1 => 'Fetching catalog…',
      _ => 'Finalizing…',
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (!PlayerSettingsOverlayScope.isActiveContext(context))
              const SizedBox.expand(
                child: TeamShellBackdrop(),
              ),
            Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: context.teamPalette.accent.withOpacity(0.92),
                    backgroundColor: context.teamPalette.accent.withOpacity(0.12),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedOpacity(
                  opacity: _phase >= 1 ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: AppTheme.focusAnimationCurve,
                  child: Column(
                    children: [
                      _StatLine(label: 'Live Channels', value: _live),
                      const SizedBox(height: 10),
                      _StatLine(label: 'Movies', value: _movies),
                      const SizedBox(height: 10),
                      _StatLine(label: 'Series', value: _series),
                    ],
                  ),
                ),
                if (_phase == 2) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Saving to device…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
                ],
              ),
            ),
          ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label:',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.78),
            ),
          ),
        ),
        Text(
          value.toString().padLeft(5, '0'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w800,
            color: context.teamPalette.accent.withOpacity(0.96),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
