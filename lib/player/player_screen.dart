import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_session_restore_store.dart';
import '../data/device_memory_channel.dart';
import '../data/library_controller.dart';
import '../data/parental_control_store.dart';
import '../data/lightning_switch_store.dart';
import '../data/performance_tier_store.dart';
import '../data/subtitle_appearance_store.dart';
import '../data/subtitle_settings_store.dart';
import '../data/episode_vod_label_store.dart';
import '../data/movie_vod_label_store.dart';
import '../data/series_vod_label_store.dart';
import '../l10n/app_localizations.dart';
import '../data/live_epg_controller.dart';
import '../data/epg_time_display.dart';
import '../data/playlist_epg_timezone_store.dart';
import '../theme/team_palette_theme.dart';
import '../ui/focus/tv_focusable.dart';
import '../ui/widgets/tv_catalog_image.dart';
import 'live_lineup_item.dart';
import 'playback_resume_store.dart';
import 'vod_audio_offset_store.dart';
import 'vod_subtitle_position_store.dart';
import 'player_browse_restore.dart';
import 'player_events.dart';
import 'player_service.dart';
import 'player_track.dart';
import 'live_multiview_channel_icons_screen.dart';
import 'player_pool.dart';
import 'live_tv_player_bottom_bar.dart';
import 'player_navigation.dart';
import 'player_session_restore_marker.dart';
import '../shell/live_tv_session_snapshot.dart';
import 'player_recording_catchup_overlay.dart';
import 'player_live_epg_overlay.dart';
import 'player_settings_overlay.dart';
import 'player_tv_overlay.dart';
import 'vod_download.dart';
import 'vod_subtitle_picker.dart';
import 'vod_subtitle_search_memory_store.dart';
import 'vod_subtitle_delay_store.dart';
import 'vod_subtitle_style_panel.dart';
import 'vod_surface_view_android.dart';
import '../subtitles/opensubtitles_client.dart';
import '../ui/recording/recording_channel_availability.dart';
import '../ui/settings/parental_pin_dialog.dart';
import '../ui/settings/parental_scope_dialogs.dart';
import '../xtream/xtream_stream_urls.dart';
import '../xtream/xtream_short_epg_parser.dart';
import 'desktop_player_service.dart';
import 'windows/windows_pip_controller.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

class _MvTile {
  int lineupIndex;
  /// Pool slot index (0-3) assigned to this tile, or -1 if not yet assigned.
  int poolSlot;
  /// Flutter texture id from the pool slot, or null if not yet created.
  int? textureId;
  /// The lineup index currently loaded on this pool slot (-1 = nothing).
  int loadedLineup;
  _MvTile({required this.lineupIndex, this.poolSlot = -1, this.textureId, this.loadedLineup = -1});
}

/// Fullscreen native video ([Texture]) with TV-friendly overlay controls.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    required this.isLive,
    this.contentDescription,
    this.liveLineup,
    this.initialLiveIndex = 0,
    this.resumeContentId,
    this.browseMovieId,
    this.browseSeriesId,
    this.liveChannelId,
    this.liveEpgXmltvId,
    this.liveViewCategoryId,
    this.subtitleSearchQuery,
    /// Android / Windows: optional poster URL for offline download library metadata.
    this.vodPosterUrl,
  });

  final String title;
  final String streamUrl;
  final bool isLive;

  /// VOD: catalog poster/backdrop URL (optional).
  final String? vodPosterUrl;

  /// VOD: query for OpenSubtitles search (movie / episode / file name).
  final String? subtitleSearchQuery;

  /// VOD: full description for the Up info banner (movies / episodes).
  final String? contentDescription;

  /// When non-null (live only), UP/DOWN switch streams in-place without leaving the screen.
  final List<LiveLineupItem>? liveLineup;
  final int initialLiveIndex;

  /// VOD resume key; when set, last saved position is restored once after ready.
  final String? resumeContentId;

  /// Passed to [PlayerBrowseRestore] when popping (movies / series browse context).
  final String? browseMovieId;
  final String? browseSeriesId;

  /// When [liveLineup] is null, EPG still loads from this Xtream stream id.
  final String? liveChannelId;

  /// Panel EPG id when it differs from [liveChannelId].
  final String? liveEpgXmltvId;

  /// Live browse pill id (category or favorite group) when opened from Live TV.
  final String? liveViewCategoryId;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final PlayerService _service;
  StreamSubscription<PlayerNativeEvent>? _sub;

  /// True when this VOD session participates in cold-start restore prefs.
  var _vodSessionRestoreActive = false;

  int? _textureId;
  String? _initError;

  var _controlsVisible = true;

  // ── Right-side options panel (RIGHT opens when live overlay is hidden) ──
  var _rightPanelVisible = false;
  /// While true, UP/DOWN must not zap channels: panel closed for async UI (PIN, settings).
  var _suppressLiveLineSwitchForPanelAsync = false;
  /// 0 = Settings, 1 = Multi, 2 = Catch-up, 3 = EPG, 4 = Parental, 5 = Quality.
  var _rightPanelFocusIndex = 0;
  static const int _kRightPanelLastIndex = 5;

  /// True while catch-up overlay route is open (root navigator); Back pops it first.
  var _recordingCatchupOverlayOpen = false;

  /// True while full-screen live EPG overlay is open. When a child route pops first in the
  /// same Back event, [HardwareKeyboard] still runs and would otherwise call [_exit] — this
  /// flag suppresses that so we return to the live channel.
  var _liveEpgOverlayOpen = false;

  // ── N-tile multiview state ──
  static const int _mvMaxTiles = 4;
  final List<_MvTile> _mvTiles = [];
  var _mvFocusIndex = 0;
  int? _mvEnlargedIndex;
  var _mvMenuVisible = false;
  var _mvMenuFocusIndex = 0;

  bool get _inMultiview => _mvTiles.isNotEmpty;

  // ── Zero-delay leapfrog switching (pool slots 0-1) ──
  /// Single-decoder path: Optimized tier, or Full tier with **Lightning switch** off.
  /// Matches Optimized live timings (buffers, spinner delay). Lightning on (Full only)
  /// enables leapfrog when supported.
  bool get _useOptimizedLivePlayerBehavior =>
      performanceTierStore.isOptimizedEffective || !lightningSwitchStore.enabled;

  /// Two pool decoders for instant channel swap. **Off** on Optimized, Chromecast,
  /// or Full without Lightning — see [_useOptimizedLivePlayerBehavior]. Also **off**
  /// on the Google TV Streamer 4K because live renders through a single native
  /// [SurfaceView] there (green-screen workaround); leapfrog requires two visible
  /// textures at once, which the SurfaceView path cannot juggle.
  bool get _useLeapfrogPool =>
      PlayerPool.supported &&
      !_useOptimizedLivePlayerBehavior &&
      !DeviceMemoryChannel.useInAppTextPadOnly &&
      !DeviceMemoryChannel.isGoogleTvStreamer;

  /// Smaller native live buffers — single-decoder / Chromecast path (faster zaps).
  bool get _liveFastChannelSwitch =>
      _useOptimizedLivePlayerBehavior ||
      DeviceMemoryChannel.useInAppTextPadOnly;

  /// Whether leapfrog is active (only in single-view live mode).
  var _lfActive = false;
  /// Which pool slot (0 or 1) is currently the "visible" one.
  var _lfVisibleSlot = 0;
  /// Flutter texture IDs for leapfrog slots 0 and 1.
  int? _lfTexId0;
  int? _lfTexId1;
  /// Which lineup index is loaded on each leapfrog slot (-1 = nothing).
  var _lfLoaded0 = -1;
  var _lfLoaded1 = -1;

  int get _lfVisibleTexId => _lfVisibleSlot == 0 ? (_lfTexId0 ?? -1) : (_lfTexId1 ?? -1);

  /// TV D-pad: receives pane arrows / OK after route transitions (strip + multiview).
  final FocusNode _playerRootFocusNode = FocusNode(debugLabel: 'playerRoot');

  /// OpenSubtitles API query draft (VOD CC picker); editable in the search row.
  final TextEditingController _vodSubSearchController = TextEditingController();
  final FocusNode _vodSubSearchFocusNode = FocusNode(debugLabel: 'vodSubSearch');
  var _vodSubSearchFocused = false;
  var _vodSubSearchHintDpadIndex = -1;
  /// Bottom [MediaQuery] inset while search field may show the IME.
  double _vodImeBottom = 0;

  /// Autocomplete under the VOD CC search field (OpenSubtitles title hints).
  List<String> _vodSubSearchHints = [];
  var _vodSubSearchHintsLoading = false;
  Timer? _vodSubSearchHintDebounce;
  int _vodSubSearchHintGen = 0;

  /// Middle EPG index; −1 = use on-air anchor when building the window.
  var _liveEpgWindowCenter = -1;

  Timer? _hideTimer;
  Timer? _seekHoldTimer;

  /// Touch: swipe-from-right gesture (live) — start position in screen coords.
  Offset? _liveRightEdgeSwipeDownGlobal;
  int? _liveRightEdgeSwipePointer;

  /// Native video track stats (optional).
  int? _videoWidth;
  int? _videoHeight;
  int? _bitrate;

  /// Live adaptive ladder heights from the manifest (when ExoPlayer exposes them).
  List<int> _liveVideoVariantHeights = const [];

  /// Live: max decode height cap for **this channel only**; null = full ladder.
  int? _liveVideoQualityCapPx;

  int _liveQualityCycleIndex = 0;

  /// Leapfrog: decoded height from the visible pool slot (main ExoPlayer is paused).
  int? _lfPoolVideoHeight;

  /// Throttle [getPlaybackMetrics] while the right rail is open (leapfrog path).
  DateTime? _lastLfPoolMetricsPoll;

  var _playing = true;

  /// Windows live only: [DesktopPlayerService] output volume 0–1.
  var _windowsLiveVolume = 1.0;
  var _windowsLiveVolumeBeforeMute = 1.0;
  OverlayEntry? _windowsLiveVolumeOverlayEntry;
  final GlobalKey _windowsLiveSpeakerButtonKey = GlobalKey();

  var _buffering = false;
  var _positionMs = 0;
  var _bufferedMs = 0;
  var _durationMs = -1;

  /// For live streams, the spinner only appears after a delay of continuous
  /// buffering (1.5s Full, 2s Optimized) so the old frame stays visible.
  var _showLiveSpinner = false;
  Timer? _liveSpinnerDelayTimer;

  Duration get _liveBufferingSpinnerDelay => _useOptimizedLivePlayerBehavior
      ? const Duration(seconds: 2)
      : const Duration(milliseconds: 1500);

  /// For VOD/catch-up, the spinner is suppressed for 800ms after a seek so
  /// rapid seeking (hold Left/Right) doesn't flash the spinner on every tick.
  var _vodSeekSpinnerGrace = false;
  Timer? _vodSeekGraceTimer;

  /// VOD: after continuous buffering this long, offer the same exit affordance
  /// as fatal errors (tap Back / hardware Back) without waiting for native timeout.
  Timer? _vodStuckBufferTimer;
  var _vodStuckBufferOfferExit = false;
  static const Duration _vodStuckBufferOfferDelay = Duration(seconds: 16);

  /// Debounce for subtitle delay: fires [_applyVodSubtitleDelayToPlayer] 700 ms
  /// after the last Left/Right nudge so the SRT is rebuilt without a reload on
  /// every individual button press.
  Timer? _subtitleDelayApplyTimer;

  var _retryBanner = false;
  String? _fatalError;

  var _released = false;
  var _exitInProgress = false;

  /// Tracks whether the app went through [AppLifecycleState.paused] so the
  /// next [AppLifecycleState.resumed] can re-bootstrap live playback.
  /// Mirrors the pattern in [HeroLivePreview].
  var _hadPausedLifecycle = false;

  /// Live: synced index + title; VOD: title from widget.
  late int _liveIndex;
  late String _displayTitle;
  late String _activeStreamUrl;

  var _pendingResumeMs = 0;
  var _resumeApplied = false;
  /// Desktop: prevents overlapping [_applyDesktopResumeSeek] from repeated `ready` events.
  var _desktopResumeSeekInFlight = false;
  Timer? _resumeSaveTimer;

  /// VOD D-pad seek: fast tap + hold (30 s / 60 s / 2 min per tick @ 75 ms).
  /// During hold, only the UI scrubs; the actual ExoPlayer seek fires once on release.
  static const int _vodSeekTapMs = 30000;
  static const int _vodSeekHoldTier1Ms = 30000;
  static const int _vodSeekHoldTier2Ms = 60000;
  static const int _vodSeekHoldTier3Ms = 120000;
  static const int _vodSeekHoldTickMs = 75;

  /// When > 0, the user is scrubbing (hold); timeline shows this instead of [_positionMs].
  int _scrubPositionMs = 0;
  bool _isScrubbing = false;

  // Refreshed on each READY; kept for upcoming audio/subtitle selection UI.
  // ignore: unused_field
  TracksSnapshot _tracksSnapshot = TracksSnapshot.empty;

  /// VOD: bottom timeline + jump row (CC, speed, …). Shown automatically once
  /// duration is known; stays visible (TV-style dock). Back can dismiss.
  var _vodTimelineVisible = false;
  var _vodInfoBannerVisible = false;

  /// VOD: first Down shows timeline + jump strip; L/R still scrub. Second Down
  /// focuses the strip (tier B); L/R move between −15s, −1/−2/−3 min, play,
  /// +3/+2/+1 min, +15s.
  var _vodJumpStripFocused = false;
  /// Default: play (center cluster index **7** in remapped strip — see [_activateVodJumpButton]).
  var _vodJumpFocusIndex = 7;

  /// Windows / Android VOD: **turtle** at **2** (left); max **15** with **Download**, else **14**.
  int get _vodJumpMaxIndex =>
      !kIsWeb &&
              (Platform.isWindows || Platform.isAndroid) &&
              !widget.isLive
          ? 15
          : 14;

  static const int _vodAudioNudgeMs = 50;
  /// Quarter-second steps so each D-pad press is easy to notice (was 50 ms).
  static const int _vodSubtitleDelayNudgeMs = 250;

  /// VOD: A/V sync offset (ms); persisted per [resumeContentId] when non-null.
  var _vodAudioDelayMs = 0;

  /// VOD: external subtitle time offset (ms); persisted per [resumeContentId] when non-null.
  var _vodSubtitleDelayMs = 0;

  /// VOD: per-title subtitle position; null → use global [SubtitleAppearanceStore].
  Offset? _vodPerMovieSubtitlePos;

  /// VOD: session-only speed (resets when the player surface is released).
  var _vodPlaybackSpeed = 1.0;

  var _vodSpeedPickerOpen = false;
  var _vodSpeedPickerFocusIndex = 2;

  /// A/V offset editor (OK on A/V chip); Left/Right adjusts, Back closes.
  var _vodAudioOffsetPopupOpen = false;

  /// Subtitle timing (turtle); Left/Right nudge, Back closes, playback continues.
  var _vodSubtitleDelayPopupOpen = false;

  /// VOD: subtitle look (palette chip) — centered panel, live preview.
  var _vodSubtitleStylePanelOpen = false;

  /// VOD: OpenSubtitles picker (CC chip).
  var _vodSubtitlePickerOpen = false;

  /// Set when a Back dismisses subtitle UI; [_exit] drops one or more duplicate
  /// invocations in the same frame and clears this after the frame (see [_exit]).
  var _suppressNextVodPlayerExitForBack = false;
  var _vodSubLoading = false;
  String? _vodSubError;
  List<OpenSubtitlesLanguageGroup> _vodSubGroups = [];
  var _vodSubLangIndex = 0;
  var _vodSubFileIndex = 0;

  /// 0 = language column, 1 = files column.
  var _vodSubFocusColumn = 0;
  var _vodHasExternalSubtitle = false;

  /// Latest active line(s) from native [TextOutput] (ExoPlayer updates on cue changes).
  List<String> _vodSubtitleLines = const [];

  /// Guards against duplicate activate (hardware + focus both firing on some devices).
  DateTime? _lastVodJumpActivateAt;

  /// Live: true until fade-out animation finishes so Back does not exit mid-fade.
  var _liveOverlayFadingOut = false;
  Timer? _liveFadeOutTimer;

  /// Windows fullscreen live: tap toggles large EPG rail; idle clears.
  var _liveDesktopEpgOpen = false;

  /// Pointer in lower ~20% of video (Windows) — flyer / bottom EPG chrome.
  var _liveDesktopBottomHover = false;

  /// Pointer in upper ~20% of video (Windows) — top bar (Exit, title, …).
  var _liveDesktopTopHover = false;

  bool get _vodSeekable => !widget.isLive && _durationMs > 0;

  bool get _vodChromeHidden {
    if (widget.isLive) return !_controlsVisible;
    if (!_vodSeekable) return true;
    return !_vodTimelineVisible && !_vodInfoBannerVisible;
  }

  bool get _vodWantsOpaqueOverlay =>
      _vodSeekable &&
      (_vodTimelineVisible ||
          _vodInfoBannerVisible ||
          _vodSubtitlePickerOpen ||
          _vodSubtitleStylePanelOpen ||
          _vodSubtitleDelayPopupOpen ||
          _vodAudioOffsetPopupOpen ||
          _vodSpeedPickerOpen);

  double get _playerOverlayOpacity {
    if (widget.isLive) {
      // Live: always 1 — sub-regions use [_liveTopChromeOpacity], timeline, EPG opacities.
      return 1.0;
    }
    return _vodWantsOpaqueOverlay ? 1.0 : 0.0;
  }

  bool get _overlayInteractive {
    if (widget.isLive) {
      return _controlsVisible ||
          _liveOverlayFadingOut ||
          _mvMenuVisible ||
          (_isDesktopLiveUi && _liveAnyChromeVisible);
    }
    return _vodWantsOpaqueOverlay ||
        _vodSpeedPickerOpen ||
        _vodAudioOffsetPopupOpen ||
        _vodSubtitleDelayPopupOpen ||
        _vodSubtitlePickerOpen ||
        _vodSubtitleStylePanelOpen;
  }

  /// Live fullscreen on **Windows desktop only** (not web, not macOS).
  bool get _isDesktopLiveUi =>
      widget.isLive && !kIsWeb && Platform.isWindows;

  bool get _liveAnyChromeVisible {
    if (!widget.isLive) return false;
    if (!_isDesktopLiveUi) return _controlsVisible;
    return _controlsVisible ||
        _liveDesktopBottomHover ||
        _liveDesktopEpgOpen ||
        _liveDesktopTopHover ||
        _rightPanelVisible;
  }

  bool get _liveShowEpgStrip =>
      !_isDesktopLiveUi ||
      _liveDesktopEpgOpen ||
      _controlsVisible ||
      _liveDesktopBottomHover;

  double get _liveTopChromeOpacity {
    if (_mvMenuVisible) return 1.0;
    if (_isDesktopLiveUi) {
      return (_liveDesktopTopHover ||
              _controlsVisible ||
              _rightPanelVisible ||
              _liveOverlayFadingOut)
          ? 1.0
          : 0.0;
    }
    return _controlsVisible ? 1.0 : 0.0;
  }

  double get _liveBottomEpgOpacity {
    if (!widget.isLive) return 0.0;
    if (_isDesktopLiveUi) return _liveShowEpgStrip ? 1.0 : 0.0;
    return _controlsVisible ? 1.0 : 0.0;
  }

  bool get _liveLineSwitching =>
      widget.isLive &&
      widget.liveLineup != null &&
      widget.liveLineup!.length > 1;

  /// Xtream stream id for EPG + catch-up (lineup row or standalone [liveChannelId]).
  String? get _effectiveEpgChannelId {
    if (!widget.isLive) return null;
    final line = widget.liveLineup;
    if (line != null && line.isNotEmpty) {
      final i = _liveIndex.clamp(0, line.length - 1);
      return line[i].channelId;
    }
    final f = widget.liveChannelId?.trim();
    if (f == null || f.isEmpty) return null;
    return f;
  }

  String? get _effectiveEpgXmltvId {
    if (!widget.isLive) return null;
    final line = widget.liveLineup;
    if (line != null && line.isNotEmpty) {
      final i = _liveIndex.clamp(0, line.length - 1);
      return line[i].epgChannelId;
    }
    return widget.liveEpgXmltvId?.trim();
  }

  static bool _isActivateKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.space;

  // ── VOD seek hold logic ──

  void _cancelSeekHold() {
    _seekHoldTimer?.cancel();
    _seekHoldTimer = null;
    if (_isScrubbing) {
      _commitScrub();
    }
  }

  void _startSeekHold(LogicalKeyboardKey key) {
    _cancelSeekHold();
    _isScrubbing = true;
    _scrubPositionMs = _positionMs;
    var tick = 0;
    _seekHoldTimer =
        Timer.periodic(Duration(milliseconds: _vodSeekHoldTickMs), (t) {
      if (!mounted || _released || !_vodSeekable) {
        t.cancel();
        _commitScrub();
        return;
      }
      if (!HardwareKeyboard.instance.isLogicalKeyPressed(key)) {
        t.cancel();
        _commitScrub();
        return;
      }
      tick++;
      final stepMs = tick < 3
          ? _vodSeekHoldTier1Ms
          : (tick < 8 ? _vodSeekHoldTier2Ms : _vodSeekHoldTier3Ms);
      final sign = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      _scrubBy(sign * stepMs);
    });
  }

  void _scrubBy(int deltaMs) {
    if (!_vodSeekable) return;
    final d = _durationMs;
    setState(() {
      _scrubPositionMs = (_scrubPositionMs + deltaMs).clamp(0, d);
    });
    _flashVodTimeline();
  }

  void _commitScrub() {
    if (!_isScrubbing) return;
    _isScrubbing = false;
    final target = _scrubPositionMs;
    unawaited(_service.seekTo(Duration(milliseconds: target)));
    _beginVodSeekGrace();
  }

  void _handleVodDown() {
    if (!_vodSeekable || !mounted || _released) return;
    if (!_vodTimelineVisible) {
      setState(() {
        _vodTimelineVisible = true;
        _vodJumpStripFocused = false;
      });
    } else if (!_vodJumpStripFocused) {
      setState(() {
        _vodJumpStripFocused = true;
        _vodJumpFocusIndex = 7;
      });
    }
    _scheduleHideControls();
  }

  void _nudgeVodAudioDelay(int deltaMs) {
    if (!_vodSeekable || _released) return;
    setState(() {
      _vodAudioDelayMs = (_vodAudioDelayMs + deltaMs).clamp(
        VodAudioOffsetStore.minMs,
        VodAudioOffsetStore.maxMs,
      );
    });
    unawaited(_service.setAudioDelayMs(_vodAudioDelayMs));
    final id = widget.resumeContentId;
    if (id != null) {
      unawaited(VodAudioOffsetStore.setOffsetMs(id, _vodAudioDelayMs));
    }
    _flashVodTimeline();
  }

  void _nudgeVodSubtitleDelay(int deltaMs) {
    if (!_vodSeekable || _released) return;
    if (!_vodHasExternalSubtitle) return;
    setState(() {
      _vodSubtitleDelayMs = (_vodSubtitleDelayMs + deltaMs).clamp(
        VodSubtitleDelayStore.minMs,
        VodSubtitleDelayStore.maxMs,
      );
    });
    // Debounce: rebuild shifted SRT 700 ms after the last nudge so the player
    // is not re-prepared on every individual button press while the user scrubs.
    _subtitleDelayApplyTimer?.cancel();
    _subtitleDelayApplyTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_applyVodSubtitleDelayToPlayer()),
    );
  }

  /// Pushes the current offset to the player (rebuilds SRT on Android) and persists it.
  Future<void> _applyVodSubtitleDelayToPlayer() async {
    if (_released) return;
    if (widget.isLive || !_vodHasExternalSubtitle) return;
    try {
      await _service.setSubtitleDelayMs(_vodSubtitleDelayMs);
      final id = widget.resumeContentId;
      if (id != null) {
        await VodSubtitleDelayStore.setOffsetMs(id, _vodSubtitleDelayMs);
      }
    } catch (_) {}
    if (mounted) {
      _beginVodSeekGrace();
    }
  }

  void _openVodAudioOffsetPopup() {
    if (!_vodSeekable || _released) return;
    if (_vodSubtitleDelayPopupOpen) {
      unawaited(_applyVodSubtitleDelayToPlayer());
    }
    setState(() {
      _vodAudioOffsetPopupOpen = true;
      _vodSubtitleDelayPopupOpen = false;
      _vodSpeedPickerOpen = false;
    });
    _hideTimer?.cancel();
  }

  void _closeVodAudioOffsetPopup() {
    if (!mounted) return;
    setState(() => _vodAudioOffsetPopupOpen = false);
    _scheduleHideControls();
  }

  void _openVodSubtitleDelayPopup() {
    if (!_vodSeekable || _released) return;
    if (!_vodHasExternalSubtitle) return;
    setState(() {
      _vodSubtitleDelayPopupOpen = true;
      _vodAudioOffsetPopupOpen = false;
      _vodSpeedPickerOpen = false;
      // Clean view: hide bottom dock so video + subtitles stay visible while adjusting.
      _vodTimelineVisible = false;
      _vodJumpStripFocused = false;
    });
    _hideTimer?.cancel();
  }

  void _closeVodSubtitleDelayPopup() {
    if (!mounted) return;
    // Cancel any pending debounce — we apply synchronously right here.
    _subtitleDelayApplyTimer?.cancel();
    _subtitleDelayApplyTimer = null;
    setState(() => _vodSubtitleDelayPopupOpen = false);
    unawaited(_applyVodSubtitleDelayToPlayer());
    _flashVodTimeline();
    _scheduleHideControls();
  }

  String _effectiveSubtitleQuery() {
    final q = widget.subtitleSearchQuery?.trim();
    if (q != null && q.isNotEmpty) return q;
    return _deriveSubtitleQueryFromTitleAndUrl(widget.title, widget.streamUrl);
  }

  String _deriveSubtitleQueryFromTitleAndUrl(String title, String url) {
    try {
      final u = Uri.parse(url);
      if (u.pathSegments.isNotEmpty) {
        final seg = u.pathSegments.last;
        if (seg.isNotEmpty && seg.contains('.')) {
          return seg
              .replaceAll(RegExp(r'\.[^.]+$'), '')
              .replaceAll(RegExp(r'[._]+'), ' ')
              .trim();
        }
      }
    } catch (_) {}
    return title.trim();
  }

  /// VOD jump strip: Style / palette chip (must match [PlayerTvVodJumpStrip] remapped indices).
  static const int _kVodJumpFocusStyleIndex = 1;

  /// [_buildVodSubtitleOverlay] bottom inset when subtitle style panel is closed vs open.
  static const double _kVodSubtitleBottomInsetNormal = 112;
  static const double _kVodSubtitleBottomInsetStylePanelOpen = 40;

  /// When the style panel is open, [Positioned.bottom] is smaller — add this to
  /// [SubtitleAppearanceStore.positionOffset] at display time so the caption stays put.
  static const double _kVodSubtitleBottomInsetDelta =
      _kVodSubtitleBottomInsetNormal - _kVodSubtitleBottomInsetStylePanelOpen;

  void _openVodSubtitleStylePanel() {
    if (!_vodSeekable || _released || widget.isLive) return;
    if (_vodSubtitleDelayPopupOpen) {
      unawaited(_applyVodSubtitleDelayToPlayer());
    }
    unawaited(SubtitleAppearanceStore.instance.ensureLoaded());
    _vodSubSearchHintDebounce?.cancel();
    setState(() {
      _vodSubtitleStylePanelOpen = true;
      _vodSubtitlePickerOpen = false;
      _vodSubLoading = false;
      _vodSubError = null;
      _vodSubGroups = [];
      _vodSubSearchFocused = false;
      _vodSubSearchHintDpadIndex = -1;
      _vodSubSearchHints = [];
      _vodSubSearchHintsLoading = false;
      _vodSpeedPickerOpen = false;
      _vodAudioOffsetPopupOpen = false;
      _vodSubtitleDelayPopupOpen = false;
    });
    _vodSubSearchFocusNode.unfocus();
    _hideTimer?.cancel();
    _flashVodTimeline();
  }

  void _closeVodSubtitleStylePanelAndRestoreJumpFocus({
    bool blockDuplicateBackExit = false,
  }) {
    if (!mounted || _released) return;
    if (blockDuplicateBackExit) {
      _suppressNextVodPlayerExitForBack = true;
    }
    setState(() {
      _vodSubtitleStylePanelOpen = false;
      _vodJumpStripFocused = false;
      _vodJumpFocusIndex = _kVodJumpFocusStyleIndex;
    });
    _scheduleHideControls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playerRootFocusNode.requestFocus();
    });
    _scheduleHideControls();
  }

  void _nudgeVodSubtitlePosition(Offset delta) {
    if (!mounted || _released) return;
    final sz = MediaQuery.sizeOf(context);
    final maxX = sz.width * 0.42;
    final maxY = sz.height * 0.45;
    final store = SubtitleAppearanceStore.instance;
    final base = _effectiveVodSubtitleDisplayOffset(store);
    final next = Offset(
      (base.dx + delta.dx).clamp(-maxX, maxX),
      (base.dy + delta.dy).clamp(-maxY, maxY),
    );
    final id = widget.resumeContentId;
    if (id != null) {
      setState(() => _vodPerMovieSubtitlePos = next);
      unawaited(VodSubtitlePositionStore.setOffset(id, next));
    } else {
      unawaited(store.setPositionOffset(next, maxX: maxX, maxY: maxY));
    }
  }

  Offset _effectiveVodSubtitleDisplayOffset(SubtitleAppearanceStore store) {
    if (widget.isLive) return store.positionOffset;
    if (widget.resumeContentId != null && _vodPerMovieSubtitlePos != null) {
      return _vodPerMovieSubtitlePos!;
    }
    return store.positionOffset;
  }

  void _openVodSubtitlePicker() {
    if (!_vodSeekable || _released) return;
    if (_vodSubtitleDelayPopupOpen) {
      unawaited(_applyVodSubtitleDelayToPlayer());
    }
    _vodSubSearchHintDebounce?.cancel();
    setState(() {
      _vodSubtitlePickerOpen = true;
      _vodSubtitleStylePanelOpen = false;
      _vodSpeedPickerOpen = false;
      _vodAudioOffsetPopupOpen = false;
      _vodSubtitleDelayPopupOpen = false;
      _vodSubFocusColumn = 0;
      _vodSubLangIndex = 0;
      _vodSubFileIndex = 0;
      _vodSubError = null;
      _vodSubGroups = [];
      _vodSubLoading = true;
      _vodSubSearchFocused = false;
      _vodSubSearchHintDpadIndex = -1;
      _vodSubSearchHints = [];
      _vodSubSearchHintsLoading = false;
    });
    _vodSubSearchController.text = _effectiveSubtitleQuery();
    _hideTimer?.cancel();
    _flashVodTimeline();
    unawaited(_loadVodSubtitleSearch());
  }

  void _closeVodSubtitlePicker({bool blockDuplicateBackExit = false}) {
    if (!mounted) return;
    if (blockDuplicateBackExit) {
      _suppressNextVodPlayerExitForBack = true;
    }
    _vodSubSearchHintDebounce?.cancel();
    setState(() {
      _vodSubtitlePickerOpen = false;
      _vodSubLoading = false;
      _vodSubError = null;
      _vodSubGroups = [];
      _vodSubSearchFocused = false;
      _vodSubSearchHintDpadIndex = -1;
      _vodSubSearchHints = [];
      _vodSubSearchHintsLoading = false;
    });
    _vodSubSearchFocusNode.unfocus();
    _scheduleHideControls();
    if (blockDuplicateBackExit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playerRootFocusNode.requestFocus();
      });
    }
  }

  void _scheduleVodSubtitlePickerListFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playerRootFocusNode.requestFocus();
    });
  }

  void _onVodSubSearchTextChanged() {
    if (!mounted || !_vodSubtitlePickerOpen) return;
    if (!_vodSubSearchFocused) return;
    if (_vodSubSearchHintDpadIndex >= 0) return;
    _vodSubSearchHintDebounce?.cancel();
    final t = _vodSubSearchController.text.trim();
    if (t.length < 2) {
      if (_vodSubSearchHints.isNotEmpty || _vodSubSearchHintsLoading) {
        setState(() {
          _vodSubSearchHints = [];
          _vodSubSearchHintsLoading = false;
          _vodSubSearchHintDpadIndex = -1;
        });
      }
      return;
    }
    _vodSubSearchHintDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (!_vodSubtitlePickerOpen || !_vodSubSearchFocused) return;
      final t2 = _vodSubSearchController.text.trim();
      if (t2.length < 2) {
        if (mounted) {
          setState(() {
            _vodSubSearchHints = [];
            _vodSubSearchHintsLoading = false;
            _vodSubSearchHintDpadIndex = -1;
          });
        }
        return;
      }
      unawaited(_runVodSubSearchHintsFetch(t2));
    });
  }

  Future<void> _runVodSubSearchHintsFetch(String query) async {
    final myGen = ++_vodSubSearchHintGen;
    if (!mounted) return;
    setState(() => _vodSubSearchHintsLoading = true);
    await SubtitleSettingsStore.instance.ensureLoaded();
    if (!mounted || myGen != _vodSubSearchHintGen) return;
    final key = SubtitleSettingsStore.instance.openSubtitlesApiKey.trim();
    if (key.isEmpty) {
      if (mounted) {
        setState(() {
          _vodSubSearchHints = [];
          _vodSubSearchHintsLoading = false;
          _vodSubSearchHintDpadIndex = -1;
        });
      }
      return;
    }
    try {
      final hints = await OpenSubtitlesClient()
          .fetchSearchQueryHints(apiKey: key, query: query);
      if (!mounted || myGen != _vodSubSearchHintGen) return;
      if (_vodSubSearchController.text.trim() != query) {
        if (mounted) {
          setState(() => _vodSubSearchHintsLoading = false);
        }
        return;
      }
      setState(() {
        _vodSubSearchHints = hints;
        _vodSubSearchHintsLoading = false;
        if (_vodSubSearchHintDpadIndex >= hints.length) {
          _vodSubSearchHintDpadIndex = -1;
        }
      });
    } catch (_) {
      if (!mounted || myGen != _vodSubSearchHintGen) return;
      setState(() {
        _vodSubSearchHints = [];
        _vodSubSearchHintsLoading = false;
        _vodSubSearchHintDpadIndex = -1;
      });
    }
  }

  void _onVodSubSearchSubmitted() {
    _vodSubSearchHintDebounce?.cancel();
    unawaited(_loadVodSubtitleSearch());
  }

  void _onVodSubSearchHintPicked(String hint) {
    if (!mounted) return;
    _vodSubSearchHintDebounce?.cancel();
    setState(() {
      _vodSubSearchController.text = hint;
      _vodSubSearchHints = [];
      _vodSubSearchHintsLoading = false;
      _vodSubSearchHintDpadIndex = -1;
    });
    unawaited(_loadVodSubtitleSearch());
  }

  Future<void> _loadVodSubtitleSearch() async {
    if (!mounted) return;
    _vodSubSearchHintDebounce?.cancel();
    setState(() {
      _vodSubLoading = true;
      _vodSubError = null;
      _vodSubSearchFocused = false;
      _vodSubSearchHintDpadIndex = -1;
      _vodSubSearchHints = [];
      _vodSubSearchHintsLoading = false;
    });
    _vodSubSearchFocusNode.unfocus();
    await SubtitleSettingsStore.instance.ensureLoaded();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final key = SubtitleSettingsStore.instance.openSubtitlesApiKey.trim();
    if (key.isEmpty) {
      setState(() {
        _vodSubLoading = false;
        _vodSubError = l10n.subtitleVodNoApiKey;
      });
      _scheduleVodSubtitlePickerListFocus();
      return;
    }
    final draft = _vodSubSearchController.text.trim();
    final eff = _effectiveSubtitleQuery().trim();
    final query = draft.isNotEmpty ? draft : eff;
    if (query.isEmpty) {
      setState(() {
        _vodSubLoading = false;
        _vodSubError = l10n.subtitleVodEmpty;
      });
      _scheduleVodSubtitlePickerListFocus();
      return;
    }
    final pref = SubtitleSettingsStore.instance.defaultLanguageCode;
    final contentId = widget.resumeContentId;
    final defaultBoxMatchesAuto = draft.isEmpty || draft == eff;
    try {
      final client = OpenSubtitlesClient();
      List<OpenSubtitlesLanguageGroup> groups;
      if (contentId != null &&
          defaultBoxMatchesAuto &&
          eff.isNotEmpty) {
        final saved = await VodSubtitleSearchMemoryStore.getManualQuery(contentId);
        final sm = saved?.trim();
        if (sm != null && sm.isNotEmpty && sm != eff) {
          final both = await Future.wait([
            client.searchSubtitles(
              apiKey: key,
              query: eff,
              preferredLanguage: pref,
            ),
            client.searchSubtitles(
              apiKey: key,
              query: sm,
              preferredLanguage: pref,
            ),
          ]);
          groups = OpenSubtitlesClient.mergeAndSortLanguageGroups(
            [both[0], both[1]],
            preferredLanguage: pref,
          );
        } else {
          groups = await client.searchSubtitles(
            apiKey: key,
            query: query,
            preferredLanguage: pref,
          );
        }
      } else {
        groups = await client.searchSubtitles(
          apiKey: key,
          query: query,
          preferredLanguage: pref,
        );
      }
      if (!mounted) return;
      if (contentId != null &&
          groups.isNotEmpty &&
          query != eff) {
        unawaited(VodSubtitleSearchMemoryStore.setManualQuery(contentId, query));
      }
      setState(() {
        _vodSubGroups = groups;
        _vodSubLoading = false;
        _vodSubError = null;
        _vodSubLangIndex = 0;
        _vodSubFileIndex = 0;
        _vodSubFocusColumn = 0;
      });
      _scheduleVodSubtitlePickerListFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vodSubLoading = false;
        _vodSubError = e.toString();
      });
      _scheduleVodSubtitlePickerListFocus();
    }
  }

  Future<void> _applyVodSubtitleFile(String fileId) async {
    await SubtitleSettingsStore.instance.ensureLoaded();
    final key = SubtitleSettingsStore.instance.openSubtitlesApiKey.trim();
    if (key.isEmpty) return;
    try {
      List<int> bytes = await OpenSubtitlesClient().downloadBytes(
        apiKey: key,
        fileId: fileId,
      );
      if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        bytes = GZipCodec().decode(bytes);
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'tvmate_sub_$fileId.srt');
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      // One native update: path + offset together (avoids back-to-back prepare that dropped subs).
      await _service.setExternalSubtitle(
        path,
        subtitleDelayMs: _vodSubtitleDelayMs,
      );
      final rid = widget.resumeContentId;
      if (rid != null) {
        unawaited(VodSubtitleDelayStore.setOffsetMs(rid, _vodSubtitleDelayMs));
      }
      if (!mounted || _released) return;
      setState(() {
        _vodHasExternalSubtitle = true;
        _vodSubtitlePickerOpen = false;
      });
      _scheduleHideControls();
    } catch (e) {
      if (!mounted) return;
      setState(() => _vodSubError = e.toString());
    }
  }

  Future<void> _clearVodExternalSubtitle() async {
    try {
      await _service.setExternalSubtitle(null);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _vodHasExternalSubtitle = false;
      _vodSubtitleLines = const [];
      _vodSubtitlePickerOpen = false;
    });
    _scheduleHideControls();
  }

  void _openVodSpeedPicker() {
    if (!_vodSeekable || _released) return;
    if (_vodSubtitleDelayPopupOpen) {
      unawaited(_applyVodSubtitleDelayToPlayer());
    }
    final i = kVodPlaybackSpeedPresets.indexWhere(
      (s) => (s - _vodPlaybackSpeed).abs() < 0.01,
    );
    setState(() {
      _vodSpeedPickerOpen = true;
      _vodAudioOffsetPopupOpen = false;
      _vodSubtitleDelayPopupOpen = false;
      _vodSpeedPickerFocusIndex = i >= 0 ? i : 2;
    });
    _hideTimer?.cancel();
  }

  void _applyVodSpeedPreset(double speed) {
    if (_released) return;
    unawaited(_service.setPlaybackSpeed(speed));
    setState(() {
      _vodPlaybackSpeed = speed;
      _vodSpeedPickerOpen = false;
    });
    _flashVodTimeline();
    _scheduleHideControls();
  }

  void _activateVodJumpButton(int index) {
    if (_released) return;
    /// Layout: **0** CC, **1** Style, **2** subtitle timing, **3–11** seek/play, **12** A/V, **13** speed, **14** settings, **15** download.
    final i = index.clamp(0, _vodJumpMaxIndex);
    if (i == 15) {
      if (!widget.isLive &&
          !kIsWeb &&
          (Platform.isWindows || Platform.isAndroid)) {
        final now = DateTime.now();
        if (_lastVodJumpActivateAt != null &&
            now.difference(_lastVodJumpActivateAt!) <
                const Duration(milliseconds: 280)) {
          return;
        }
        _lastVodJumpActivateAt = now;
        _startVodDownloadFromJumpStrip();
        _scheduleHideControls();
      }
      return;
    }
    if (!_vodSeekable) return;
    final now = DateTime.now();
    if (_lastVodJumpActivateAt != null &&
        now.difference(_lastVodJumpActivateAt!) <
            const Duration(milliseconds: 280)) {
      return;
    }
    _lastVodJumpActivateAt = now;

    switch (i) {
      case 0:
        _openVodSubtitlePicker();
        _scheduleHideControls();
        return;
      case 1:
        _openVodSubtitleStylePanel();
        _scheduleHideControls();
        return;
      case 2:
        if (!_vodHasExternalSubtitle) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add subtitles first (CC)'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        _openVodSubtitleDelayPopup();
        _scheduleHideControls();
        return;
      case 3:
        _seekBy(-15000);
        break;
      case 4:
        _seekBy(-60000);
        break;
      case 5:
        _seekBy(-120000);
        break;
      case 6:
        _seekBy(-180000);
        break;
      case 7:
        unawaited(_togglePlayPause());
        break;
      case 8:
        _seekBy(180000);
        break;
      case 9:
        _seekBy(120000);
        break;
      case 10:
        _seekBy(60000);
        break;
      case 11:
        _seekBy(15000);
        break;
      case 12:
        _openVodAudioOffsetPopup();
        _scheduleHideControls();
        return;
      case 13:
        _openVodSpeedPicker();
        _scheduleHideControls();
        return;
      case 14:
        unawaited(_openPlayerSettingsFromVodJump());
        _scheduleHideControls();
        return;
      default:
        break;
    }
    _flashVodTimeline();
    _scheduleHideControls();
  }

  void _startVodDownloadFromJumpStrip() {
    if (!mounted ||
        _released ||
        widget.isLive ||
        kIsWeb ||
        (!Platform.isWindows && !Platform.isAndroid)) {
      return;
    }
    startVodDownload(
      streamUrl: widget.streamUrl,
      title: widget.title,
      posterUrl: widget.vodPosterUrl,
    );
  }

  Future<void> _openPlayerSettingsFromVodJump() async {
    if (!mounted || _released) return;
    await openPlayerSettingsOverlay(context);
    if (mounted) _requestPlayerRootFocus();
  }

  void _showVodInfoBanner() {
    if (!_vodSeekable || !mounted || _released) return;
    setState(() => _vodInfoBannerVisible = true);
    _scheduleHideControls();
  }

  void _flashVodTimeline() {
    if (!_vodSeekable || !mounted || _released) return;
    setState(() => _vodTimelineVisible = true);
    _scheduleHideControls();
  }

  // ── Live overlay helpers ──

  void _showControlsAndFocusPlay() {
    if (!mounted || _released || !widget.isLive) return;
    if (_inMultiview) {
      setState(() {
        _mvMenuVisible = true;
        _mvMenuFocusIndex = 0;
      });
      _hideTimer?.cancel();
      return;
    }
    setState(() {
      _controlsVisible = true;
      _rightPanelVisible = false;
      _liveEpgWindowCenter = -1;
    });
    _scheduleHideControls();
  }

  /// OK / click on video when chrome is hidden: show overlay **and** side menu (Settings, EPG, …).
  void _showLiveTvChromeWithSidePanel() {
    if (!mounted || _released || !widget.isLive) return;
    if (_inMultiview) {
      _showControlsAndFocusPlay();
      return;
    }
    setState(() {
      _controlsVisible = true;
      _rightPanelVisible = true;
      _rightPanelFocusIndex = _firstEnabledRightPanelSlot();
      _liveEpgWindowCenter = -1;
    });
    unawaited(_refreshLiveVideoVariantHeights());
    if (_lfActive) {
      unawaited(_refreshLfPoolVideoHeight());
    }
    _scheduleHideControls();
  }

  void _nudgeLiveEpgWindow(int delta) {
    final id = _effectiveEpgChannelId;
    if (id == null) return;
    final list = LiveEpgController.instance.lookupListings(id);
    if (list.isEmpty) return;
    final anchor = computeLiveEpgAnchorIndex(list);
    var center = _liveEpgWindowCenter >= 0 ? _liveEpgWindowCenter : anchor;
    center = (center + delta).clamp(0, list.length - 1);
    setState(() => _liveEpgWindowCenter = center);
    _pokeControls();
  }

  bool _epgListingEnded(XtreamEpgListing e) {
    final en = e.end;
    if (en == null) return false;
    return DateTime.now().isAfter(en);
  }

  bool _epgListingNotStarted(XtreamEpgListing e) {
    final s = e.start;
    if (s == null) return false;
    return DateTime.now().isBefore(s);
  }

  bool _handleLiveEpgCenterActivate() {
    if (!widget.isLive || !_controlsVisible || _released) return false;
    final id = _effectiveEpgChannelId;
    if (id == null) {
      unawaited(_togglePlayPause());
      return true;
    }
    final listings = LiveEpgController.instance.lookupListings(id);
    if (listings.isEmpty) {
      unawaited(_togglePlayPause());
      return true;
    }
    final anchor = computeLiveEpgAnchorIndex(listings);
    final center = _liveEpgWindowCenter >= 0
        ? _liveEpgWindowCenter.clamp(0, listings.length - 1)
        : anchor;
    final listing = listings[center];
    if (listingIsOnAirNow(listing)) {
      unawaited(_togglePlayPause());
      return true;
    }
    if (_epgListingEnded(listing)) {
      unawaited(_openCatchupForListing(listing));
      return true;
    }
    if (_epgListingNotStarted(listing)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upcoming show — playback not available yet'),
          ),
        );
      }
      return true;
    }
    unawaited(_togglePlayPause());
    return true;
  }

  // ── Multiview: enter / exit / actions ──

  Future<void> _openSettingsOverlayFromPanel() async {
    if (!mounted || _released || !widget.isLive) return;
    _suppressLiveLineSwitchForPanelAsync = true;
    try {
      setState(() => _rightPanelVisible = false);
      await openPlayerSettingsOverlay(context);
      if (mounted) {
        setState(() => _controlsVisible = true);
        _scheduleHideControls();
        _requestPlayerRootFocus();
      }
    } finally {
      _suppressLiveLineSwitchForPanelAsync = false;
    }
  }

  Future<void> _openParentalFromPanel() async {
    if (!mounted || _released || !widget.isLive) return;
    _suppressLiveLineSwitchForPanelAsync = true;
    try {
      setState(() => _rightPanelVisible = false);
      await parentalControlStore.ensureLoaded();
      if (!mounted) return;

      if (!parentalControlStore.isPinConfigured) {
        final created = await showParentalSideMenuCreatePinDialog(context);
        if (!mounted || !created) {
          if (mounted) _requestPlayerRootFocus();
          return;
        }
      } else {
        final verifyOk = await showParentalPinVerifyDialog(context);
        if (!mounted || !verifyOk) {
          if (mounted) _requestPlayerRootFocus();
          return;
        }
      }

      if (!parentalControlStore.enabled) {
        await parentalControlStore.setEnabled(true);
        if (!mounted) return;
      }

      final pid =
          libraryController.activePlaylistId ?? ParentalControlStore.kDemoPlaylistId;
      final chId = _currentLiveChannelId;
      final viewCat = widget.liveViewCategoryId ?? '';
      if (chId == null || chId.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).parentalMustEnableInSettings,
              ),
            ),
          );
        }
        if (mounted) _requestPlayerRootFocus();
        return;
      }

      await showLiveParentalScopeDialog(
        context,
        playlistId: pid,
        viewCategoryId: viewCat,
        channelId: chId.trim(),
        skipPinVerify: true,
      );
      if (mounted) _requestPlayerRootFocus();
    } finally {
      _suppressLiveLineSwitchForPanelAsync = false;
    }
  }

  void _enterMultiview() {
    if (!mounted || _released || !widget.isLive) return;
    setState(() => _rightPanelVisible = false);
    final lineup = widget.liveLineup;
    if (lineup == null || lineup.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Channel list unavailable for this playback'),
          ),
        );
      }
      if (mounted) _pokeControls();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Try to hand off leapfrog slot 0 directly to multiview tile 0.
      final handoff = _lfStopKeepSlot0();
      try { await _service.pause(); } catch (_) {}
      if (!mounted) return;
      final tile0 = _MvTile(lineupIndex: _liveIndex);
      if (handoff != null) {
        tile0.poolSlot = 0;
        tile0.textureId = handoff.texId;
        tile0.loadedLineup = handoff.loadedLineup;
      }
      setState(() {
        _mvTiles.clear();
        _mvTiles.add(tile0);
        _mvFocusIndex = 0;
        _mvEnlargedIndex = null;
        _mvMenuVisible = false;
        _controlsVisible = false;
        _rightPanelVisible = false;
      });
      _hideTimer?.cancel();
      _requestPlayerRootFocus();
      // If handoff succeeded, tile 0 is already playing — just route audio.
      // Otherwise do a full sync.
      if (handoff != null) {
        await _mvRouteAudio();
        if (mounted) setState(() {});
      } else {
        await _mvSyncDecoders(forceReload: true);
      }
    });
  }

  Future<void> _mvAddScreen() async {
    if (!mounted || _released) return;
    final lineup = widget.liveLineup;
    if (lineup == null || lineup.isEmpty) return;
    if (_mvTiles.length >= _mvMaxTiles) return;
    final n = lineup.length;
    final usedIndices = _mvTiles.map((t) => t.lineupIndex).toSet();
    var defaultPick = (_liveIndex + 1) % n;
    for (var i = 0; i < n; i++) {
      final candidate = (defaultPick + i) % n;
      if (!usedIndices.contains(candidate)) {
        defaultPick = candidate;
        break;
      }
    }
    final picked = await Navigator.of(context).push<int?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => LiveMultiviewChannelIconsScreen(
          title: AppLocalizations.of(context)!.mvPickerAddChannel,
          lineup: lineup,
          selectedIndex: defaultPick,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _mvTiles.add(_MvTile(lineupIndex: picked));
      _mvMenuVisible = false;
    });
    _requestPlayerRootFocus();
    // Only sync — existing tiles keep playing, new tile gets set up.
    await _mvSyncDecoders();
  }

  Future<void> _mvRemoveScreen(int tileIndex) async {
    if (!mounted || _released) return;
    if (_mvTiles.length <= 1) {
      await _mvExitMultiview();
      return;
    }
    // Release only the removed tile's pool slot.
    final removed = _mvTiles[tileIndex];
    if (removed.poolSlot >= 0) {
      try { await PlayerPool.releaseSlot(removed.poolSlot); } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _mvTiles.removeAt(tileIndex);
      if (_mvFocusIndex >= _mvTiles.length) {
        _mvFocusIndex = _mvTiles.length - 1;
      }
      if (_mvEnlargedIndex != null) {
        if (_mvEnlargedIndex == tileIndex) {
          _mvEnlargedIndex = null;
        } else if (_mvEnlargedIndex! > tileIndex) {
          _mvEnlargedIndex = _mvEnlargedIndex! - 1;
        }
      }
      _mvMenuVisible = false;
    });
    // Remaining tiles keep their pool slots; just re-route audio.
    await _mvRouteAudio();
    if (mounted) setState(() {});
  }

  Future<void> _mvChangeChannel(int tileIndex) async {
    if (!mounted || _released) return;
    final lineup = widget.liveLineup;
    if (lineup == null || lineup.isEmpty) return;
    final currentIdx = _mvTiles[tileIndex].lineupIndex;
    final picked = await Navigator.of(context).push<int?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => LiveMultiviewChannelIconsScreen(
          title: AppLocalizations.of(context)!.mvPickerChangeChannel,
          lineup: lineup,
          selectedIndex: currentIdx,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _mvTiles[tileIndex].lineupIndex = picked;
      _mvTiles[tileIndex].loadedLineup = -1;
      _mvMenuVisible = false;
    });
    _requestPlayerRootFocus();
    await _mvSyncDecoders();
  }

  void _mvToggleEnlarge() {
    if (!mounted || _released) return;
    setState(() {
      if (_mvEnlargedIndex == _mvFocusIndex) {
        _mvEnlargedIndex = null;
      } else {
        _mvEnlargedIndex = _mvFocusIndex;
      }
      _mvMenuVisible = false;
    });
  }

  Future<void> _mvFullScreen() async {
    final focusedLineup = _mvTiles[_mvFocusIndex].lineupIndex;
    await _mvReleasePool();
    if (!mounted) return;
    setState(() {
      _mvTiles.clear();
      _mvFocusIndex = 0;
      _mvEnlargedIndex = null;
      _mvMenuVisible = false;
    });
    // Resume main player + leapfrog.
    await _switchLiveToIndex(focusedLineup, forceReload: true);
    if (widget.isLive && _useLeapfrogPool) unawaited(_lfStart());
  }

  Future<void> _mvExitMultiview() async {
    final focusedLineup = _mvTiles.isNotEmpty
        ? _mvTiles[_mvFocusIndex.clamp(0, _mvTiles.length - 1)].lineupIndex
        : _liveIndex;
    await _mvReleasePool();
    if (!mounted) return;
    setState(() {
      _mvTiles.clear();
      _mvFocusIndex = 0;
      _mvEnlargedIndex = null;
      _mvMenuVisible = false;
      _controlsVisible = true;
    });
    _scheduleHideControls();
    // Resume main player + leapfrog.
    await _switchLiveToIndex(focusedLineup, forceReload: true);
    if (widget.isLive && _useLeapfrogPool) unawaited(_lfStart());
  }

  /// Ensure every tile has a pool slot with the correct stream loaded.
  /// Each tile gets its own ExoPlayer via [PlayerPool].
  ///
  /// Players are initialized one at a time with a short delay between each
  /// new slot to give the system time to allocate decoders.
  Future<void> _mvSyncDecoders({bool forceReload = false}) async {
    if (!mounted || _released || _mvTiles.isEmpty) return;
    if (!PlayerPool.supported) return;
    final lineup = widget.liveLineup;
    if (lineup == null || lineup.isEmpty) return;

    // Collect already-used pool slots to avoid duplicates.
    final usedSlots = <int>{
      for (final t in _mvTiles)
        if (t.poolSlot >= 0) t.poolSlot,
    };

    for (var i = 0; i < _mvTiles.length; i++) {
      final tile = _mvTiles[i];
      final li = tile.lineupIndex.clamp(0, lineup.length - 1);
      final url = lineup[li].streamUrl.trim();
      if (url.isEmpty) continue;

      // Assign a pool slot if not yet assigned — pick the lowest free slot.
      final isNewSlot = tile.poolSlot < 0;
      if (isNewSlot) {
        var slot = 0;
        while (usedSlots.contains(slot) && slot < PlayerPool.maxSlots) {
          slot++;
        }
        tile.poolSlot = slot;
        usedSlots.add(slot);
        debugPrint('MV tile $i → pool slot $slot (new)');
      }

      final isFocused = i == _mvFocusIndex.clamp(0, _mvTiles.length - 1);
      final isBg = !isFocused;

      // Create the texture if needed.
      if (tile.textureId == null) {
        // Stagger: give previous players time to acquire decoders.
        if (i > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          if (!mounted || _released) return;
        }
        try {
          tile.textureId =
              await PlayerPool.ensureTexture(tile.poolSlot, bg: isBg);
        } catch (e) {
          debugPrint('Pool ensureTexture slot ${tile.poolSlot} failed: $e');
          continue;
        }
        if (!mounted) return;
      }

      // Load the stream if the channel changed or force-reload requested.
      if (li != tile.loadedLineup || forceReload) {
        tile.loadedLineup = li;
        // Stagger loads for new slots being created in sequence.
        if (isNewSlot && i > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          if (!mounted || _released) return;
        }
        try {
          if (isBg) {
            await PlayerPool.setMaxVideoSize(tile.poolSlot,
                maxWidth: 640, maxHeight: 360);
          }
          await PlayerPool.load(tile.poolSlot, url);
          await PlayerPool.play(tile.poolSlot);
        } catch (e) {
          debugPrint('Pool load slot ${tile.poolSlot} failed: $e');
        }
        if (!mounted) return;
        // Let this player settle before starting the next one.
        if (i < _mvTiles.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          if (!mounted || _released) return;
        }
      }
    }

    // Update which tile is for the "main" player state tracking.
    final fi = _mvFocusIndex.clamp(0, _mvTiles.length - 1);
    _liveIndex = _mvTiles[fi].lineupIndex.clamp(0, lineup.length - 1);
    _displayTitle = lineup[_liveIndex].title;

    // Route audio to the focused tile.
    await _mvRouteAudio();

    if (mounted) setState(() {});
  }

  /// Mute all pool slots except the focused tile's slot, and apply
  /// adaptive quality: focused tile gets full resolution, others are
  /// capped to lowest quality to reduce decoder pressure.
  Future<void> _mvRouteAudio() async {
    if (_mvTiles.isEmpty || !PlayerPool.supported) return;
    final fi = _mvFocusIndex.clamp(0, _mvTiles.length - 1);
    for (var i = 0; i < _mvTiles.length; i++) {
      final slot = _mvTiles[i].poolSlot;
      if (slot < 0) continue;
      final isFocused = i == fi;
      try {
        await PlayerPool.setVolume(slot, isFocused ? 1.0 : 0.0);
        await PlayerPool.setMaxVideoSize(slot,
            maxWidth: isFocused ? 0 : 640,
            maxHeight: isFocused ? 0 : 360);
      } catch (_) {}
    }
  }

  /// Release all pool slots used by multiview tiles.
  Future<void> _mvReleasePool() async {
    for (final tile in _mvTiles) {
      if (tile.poolSlot >= 0) {
        try { await PlayerPool.releaseSlot(tile.poolSlot); } catch (_) {}
      }
    }
  }

  /// Focus switch: just swap audio volumes — no stream reloads.
  void _mvSetFocus(int index) {
    if (!mounted || _released || index == _mvFocusIndex) return;
    if (index < 0 || index >= _mvTiles.length) return;
    setState(() => _mvFocusIndex = index);
    unawaited(_mvRouteAudio());
  }

  /// Arrow key navigation between tiles based on layout geometry.
  bool _mvHandleArrowKey(LogicalKeyboardKey k) {
    if (!_inMultiview || _mvMenuVisible) return false;
    final n = _mvTiles.length;
    final fi = _mvFocusIndex;

    int? next;
    if (n == 1) {
      return false;
    }

    // Enlarged: big tile on top, small tiles in bottom row.
    if (_mvEnlargedIndex != null && n > 1) {
      final ei = _mvEnlargedIndex!.clamp(0, n - 1);
      final others = <int>[for (var i = 0; i < n; i++) if (i != ei) i];
      if (fi == ei) {
        if (k == LogicalKeyboardKey.arrowDown && others.isNotEmpty) {
          next = others[0];
        }
      } else {
        final posInOthers = others.indexOf(fi);
        if (k == LogicalKeyboardKey.arrowUp) {
          next = ei;
        } else if (k == LogicalKeyboardKey.arrowRight) {
          if (posInOthers >= 0 && posInOthers < others.length - 1) {
            next = others[posInOthers + 1];
          }
        } else if (k == LogicalKeyboardKey.arrowLeft) {
          if (posInOthers > 0) {
            next = others[posInOthers - 1];
          }
        }
      }
    } else if (n == 2) {
      // Side by side.
      if (k == LogicalKeyboardKey.arrowLeft && fi == 1) next = 0;
      if (k == LogicalKeyboardKey.arrowRight && fi == 0) next = 1;
    } else if (n == 3) {
      // 2 on top, 1 centered bottom.
      //   0  1
      //    2
      if (fi == 0) {
        if (k == LogicalKeyboardKey.arrowRight) next = 1;
        if (k == LogicalKeyboardKey.arrowDown) next = 2;
      } else if (fi == 1) {
        if (k == LogicalKeyboardKey.arrowLeft) next = 0;
        if (k == LogicalKeyboardKey.arrowDown) next = 2;
      } else {
        if (k == LogicalKeyboardKey.arrowUp) next = 0;
      }
    } else if (n == 4) {
      // 2x2 grid:  0 1
      //            2 3
      const grid = [
        [null, 1, null, 2],  // 0: L=-, R=1, U=-, D=2
        [0, null, null, 3],  // 1: L=0, R=-, U=-, D=3
        [null, 3, 0, null],  // 2: L=-, R=3, U=0, D=-
        [2, null, 1, null],  // 3: L=2, R=-, U=1, D=-
      ];
      final dirIndex = {
        LogicalKeyboardKey.arrowLeft: 0,
        LogicalKeyboardKey.arrowRight: 1,
        LogicalKeyboardKey.arrowUp: 2,
        LogicalKeyboardKey.arrowDown: 3,
      }[k];
      if (dirIndex != null) next = grid[fi][dirIndex];
    }

    if (next != null && next >= 0 && next < n) {
      _mvSetFocus(next);
      return true;
    }
    return false;
  }

  List<_MvMenuItem> _mvBuildMenuItems() {
    final l10n = AppLocalizations.of(context)!;
    final items = <_MvMenuItem>[];
    if (_mvTiles.length < _mvMaxTiles) {
      items.add(_MvMenuItem(l10n.mvAddScreen, _MvMenuAction.addScreen));
    }
    items.add(_MvMenuItem(l10n.mvChangeChannel, _MvMenuAction.changeChannel));
    if (_mvTiles.length > 1) {
      final isEnlarged = _mvEnlargedIndex == _mvFocusIndex;
      items.add(_MvMenuItem(
        isEnlarged ? l10n.mvReduceScreen : l10n.mvEnlargeScreen,
        isEnlarged ? _MvMenuAction.reduceScreen : _MvMenuAction.enlargeScreen,
      ));
    }
    items.add(_MvMenuItem(l10n.mvFullScreen, _MvMenuAction.fullScreen));
    if (_mvTiles.length > 1) {
      items.add(_MvMenuItem(l10n.mvRemoveScreen, _MvMenuAction.removeScreen));
    }
    items.add(_MvMenuItem(l10n.mvExitMultiview, _MvMenuAction.exitMultiview));
    return items;
  }

  void _mvActivateMenuItem(_MvMenuAction action) {
    switch (action) {
      case _MvMenuAction.addScreen:
        setState(() => _mvMenuVisible = false);
        unawaited(_mvAddScreen());
        break;
      case _MvMenuAction.changeChannel:
        setState(() => _mvMenuVisible = false);
        unawaited(_mvChangeChannel(_mvFocusIndex));
        break;
      case _MvMenuAction.enlargeScreen:
      case _MvMenuAction.reduceScreen:
        _mvToggleEnlarge();
        break;
      case _MvMenuAction.fullScreen:
        unawaited(_mvFullScreen());
        break;
      case _MvMenuAction.removeScreen:
        unawaited(_mvRemoveScreen(_mvFocusIndex));
        break;
      case _MvMenuAction.exitMultiview:
        unawaited(_mvExitMultiview());
        break;
    }
  }

  /// Resume main ExoPlayer playback (e.g. after multiview exit).
  /// For lifecycle resume after background, use [_rebootstrapAfterResume]
  /// which does a full reload for live streams.
  Future<void> _ensureMainPlayback() async {
    if (_released || !widget.isLive) return;
    try {
      await _service.play();
    } catch (_) {}
  }

  void _requestPlayerRootFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_playerRootFocusNode.canRequestFocus) {
        _playerRootFocusNode.requestFocus();
      }
    });
  }

  // ── Leapfrog lifecycle ──

  Future<void> _lfStart() async {
    if (!_useLeapfrogPool || _lfActive) return;
    _lfActive = true;
    _lfVisibleSlot = 0;
    try {
      _lfTexId0 = await PlayerPool.ensureTexture(0);
      _lfTexId1 = await PlayerPool.ensureTexture(1);
    } catch (_) {
      _lfActive = false;
      return;
    }
    if (!mounted) return;
    // Load the current channel on slot 0.
    final lineup = widget.liveLineup;
    if (lineup != null && lineup.isNotEmpty) {
      final idx = _liveIndex.clamp(0, lineup.length - 1);
      final url = lineup[idx].streamUrl.trim();
      if (url.isNotEmpty) {
        _lfLoaded0 = idx;
        try {
          await PlayerPool.load(0, url);
          await PlayerPool.play(0);
          await PlayerPool.setVolume(0, 1.0);
          await PlayerPool.setVolume(1, 0.0);
        } catch (_) {}
      }
    }
    // Pause the main ExoPlayer so it doesn't fight for decoders.
    try { await _service.pause(); } catch (_) {}
    if (!mounted) return;
    setState(() {});
    unawaited(_lfPreBufferNext());
  }

  Future<void> _lfStop() async {
    if (!_lfActive) return;
    _lfActive = false;
    _lfTexId0 = null;
    _lfTexId1 = null;
    _lfLoaded0 = -1;
    _lfLoaded1 = -1;
    try { await PlayerPool.releaseSlot(0); } catch (_) {}
    try { await PlayerPool.releaseSlot(1); } catch (_) {}
  }

  /// Stop leapfrog but keep slot 0 alive (for handoff to multiview tile 0).
  /// Only releases slot 1. Returns the texture id and loaded lineup of slot 0,
  /// or null if leapfrog wasn't active.
  ({int texId, int loadedLineup})? _lfStopKeepSlot0() {
    if (!_lfActive) return null;
    _lfActive = false;
    final visSlot = _lfVisibleSlot;
    final texId = visSlot == 0 ? _lfTexId0 : _lfTexId1;
    final loaded = visSlot == 0 ? _lfLoaded0 : _lfLoaded1;
    final idleSlot = visSlot == 0 ? 1 : 0;
    _lfTexId0 = null;
    _lfTexId1 = null;
    _lfLoaded0 = -1;
    _lfLoaded1 = -1;
    // Release the idle slot; keep the visible one alive.
    unawaited(PlayerPool.releaseSlot(idleSlot));
    // If the visible slot wasn't slot 0, we need to release it too and
    // the caller can't reuse it (slot indices must match tile indices).
    if (visSlot != 0) {
      // Can't reuse slot 1 as tile 0 — release both, caller will create fresh.
      unawaited(PlayerPool.releaseSlot(visSlot));
      return null;
    }
    if (texId == null || texId < 0 || loaded < 0) return null;
    return (texId: texId, loadedLineup: loaded);
  }

  /// Pre-buffer the next channel in the lineup on the idle slot.
  Future<void> _lfPreBufferNext() async {
    if (!_lfActive || !mounted || _released) return;
    final lineup = widget.liveLineup;
    if (lineup == null || lineup.length <= 1) return;
    final nextIdx = (_liveIndex + 1) % lineup.length;
    final idleSlot = _lfVisibleSlot == 0 ? 1 : 0;
    final url = lineup[nextIdx].streamUrl.trim();
    if (url.isEmpty) return;
    if (idleSlot == 0) {
      _lfLoaded0 = nextIdx;
    } else {
      _lfLoaded1 = nextIdx;
    }
    try {
      await PlayerPool.load(idleSlot, url);
      await PlayerPool.play(idleSlot);
      await PlayerPool.setVolume(idleSlot, 0.0);
    } catch (_) {}
  }

  /// Pre-buffer the previous channel in the lineup on the idle slot.
  Future<void> _lfPreBufferPrev() async {
    if (!_lfActive || !mounted || _released) return;
    final lineup = widget.liveLineup;
    if (lineup == null || lineup.length <= 1) return;
    final prevIdx = (_liveIndex - 1 + lineup.length) % lineup.length;
    final idleSlot = _lfVisibleSlot == 0 ? 1 : 0;
    final url = lineup[prevIdx].streamUrl.trim();
    if (url.isEmpty) return;
    if (idleSlot == 0) {
      _lfLoaded0 = prevIdx;
    } else {
      _lfLoaded1 = prevIdx;
    }
    try {
      await PlayerPool.load(idleSlot, url);
      await PlayerPool.play(idleSlot);
      await PlayerPool.setVolume(idleSlot, 0.0);
    } catch (_) {}
  }

  Future<void> _switchLiveToIndex(int index, {bool forceReload = false}) async {
    if (_released) return;
    final lineup = widget.liveLineup;
    if (lineup == null || lineup.isEmpty) return;
    final idx = index.clamp(0, lineup.length - 1);
    if (idx == _liveIndex && !forceReload) return;

    final wasIndex = _liveIndex;
    _resetLiveVideoQualityState();
    await _clearNativeVideoQualityCaps();

    _liveIndex = idx;
    final item = lineup[_liveIndex];
    _activeStreamUrl = item.streamUrl;
    setState(() {
      _displayTitle = item.title;
      _liveEpgWindowCenter = -1;
    });
    _updateLiveSessionSnapshotFromPlayer();
    final cid = item.channelId;
    if (cid != null) {
      unawaited(
        LiveEpgController.instance.refreshForStream(
          cid,
          epgChannelId: item.epgChannelId,
        ),
      );
    }

    // ── Leapfrog path ──
    if (_lfActive) {
      final idleSlot = _lfVisibleSlot == 0 ? 1 : 0;
      final idleLoaded = idleSlot == 0 ? _lfLoaded0 : _lfLoaded1;

      if (idleLoaded == idx && !forceReload) {
        // The target channel is already pre-buffered on the idle slot.
        // Instant swap: mute old, unmute new, flip visible.
        try {
          await PlayerPool.setVolume(idleSlot, 1.0);
          await PlayerPool.setVolume(_lfVisibleSlot, 0.0);
        } catch (_) {}
        setState(() => _lfVisibleSlot = idleSlot);
      } else {
        // Not pre-buffered — load directly on the idle slot, then swap.
        final url = item.streamUrl.trim();
        if (url.isNotEmpty) {
          if (idleSlot == 0) { _lfLoaded0 = idx; } else { _lfLoaded1 = idx; }
          try {
            await PlayerPool.load(idleSlot, url);
            await PlayerPool.play(idleSlot);
            await PlayerPool.setVolume(idleSlot, 1.0);
            await PlayerPool.setVolume(_lfVisibleSlot, 0.0);
          } catch (_) {}
          setState(() => _lfVisibleSlot = idleSlot);
        }
      }
      // Pre-buffer the next channel in the direction the user was going.
      final goingUp = idx == (wasIndex + 1) % lineup.length;
      unawaited(goingUp ? _lfPreBufferNext() : _lfPreBufferPrev());
      unawaited(_refreshLiveVideoVariantHeights());
      unawaited(_refreshLfPoolVideoHeight());
      return;
    }

    // ── Legacy path (main ExoPlayer) ──
    try {
      await _service.load(
        url: item.streamUrl,
        isLive: true,
        liveFastSwitch: _liveFastChannelSwitch,
      );
      unawaited(_refreshLiveVideoVariantHeights());
      if (mounted && Platform.isWindows && widget.isLive) {
        unawaited(_applyWindowsLiveVolume());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch channel: $e')),
        );
      }
    }
  }

  Future<void> _openCatchupForListing(XtreamEpgListing listing) async {
    final streamId = _effectiveEpgChannelId;
    if (streamId == null) return;
    if (listing.startUnix == null || listing.startUnix == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catch-up is not available for this programme'),
        ),
      );
      return;
    }
    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to an Xtream playlist to use catch-up'),
        ),
      );
      return;
    }
    await playlistEpgTimezoneStore.ensureLoaded();
    var durationMin = 60;
    if (listing.start != null && listing.end != null) {
      final diff = listing.end!.difference(listing.start!).inMinutes;
      if (diff > 0 && diff < 720) durationMin = diff;
    }
    final serverOffset = playlistEpgTimezoneStore.serverUtcOffsetHours(p.id);
    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Playlist credentials are incomplete'),
        ),
      );
      return;
    }
    final links = XtreamStreamLinkBuilder(
      serverUrl: server,
      username: u,
      password: pw,
    );
    final streamUrl = links.catchupUrlWithDuration(
      streamId: streamId,
      startRaw: listing.startRaw,
      startUnix: listing.startUnix!,
      durationMin: durationMin,
      serverUtcOffsetHours: serverOffset,
    );
    if (!mounted) return;
    await openTvMatePlayer(
      context,
      title: listing.title,
      streamUrl: streamUrl,
      isLive: false,
      subtitleSearchQuery: listing.title,
      contentDescription: listing.description,
      suppressPreviousFocusRestore: true,
    );
  }

  // ── Hardware key handler ──

  bool _onPlayerHardwareKey(KeyEvent event) {
    if (!mounted || _released) return false;

    if (event is KeyUpEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight) {
        _cancelSeekHold();
      }
      return false;
    }

    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;

    if (_suppressNextVodPlayerExitForBack &&
        k != LogicalKeyboardKey.goBack &&
        k != LogicalKeyboardKey.escape) {
      _suppressNextVodPlayerExitForBack = false;
    }

    if (ModalRoute.of(context)?.isCurrent == false &&
        k != LogicalKeyboardKey.goBack &&
        k != LogicalKeyboardKey.escape) {
      return false;
    }

    if (!widget.isLive && _vodSubtitleStylePanelOpen) {
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        _closeVodSubtitleStylePanelAndRestoreJumpFocus(
          blockDuplicateBackExit: true,
        );
        return true;
      }
      return false;
    }

    // ── VOD A/V offset popup (Left/Right = adjust, Back = close) ──
    if (!widget.isLive && _vodAudioOffsetPopupOpen) {
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        _closeVodAudioOffsetPopup();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        _nudgeVodAudioDelay(-_vodAudioNudgeMs);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        _nudgeVodAudioDelay(_vodAudioNudgeMs);
        return true;
      }
      if (_isActivateKey(k)) {
        _closeVodAudioOffsetPopup();
        return true;
      }
      return true;
    }

    // ── VOD subtitle timing popup (turtle; same as A/V, separate from audio) ──
    if (!widget.isLive && _vodSubtitleDelayPopupOpen) {
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        _closeVodSubtitleDelayPopup();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        _nudgeVodSubtitleDelay(-_vodSubtitleDelayNudgeMs);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        _nudgeVodSubtitleDelay(_vodSubtitleDelayNudgeMs);
        return true;
      }
      if (_isActivateKey(k)) {
        _closeVodSubtitleDelayPopup();
        return true;
      }
      return true;
    }

    // ── VOD playback-speed picker (captures D-pad until closed) ──
    if (!widget.isLive && _vodSpeedPickerOpen) {
      if (k == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _vodSpeedPickerFocusIndex = (_vodSpeedPickerFocusIndex - 1)
              .clamp(0, kVodPlaybackSpeedPresets.length - 1);
        });
        return true;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _vodSpeedPickerFocusIndex = (_vodSpeedPickerFocusIndex + 1)
              .clamp(0, kVodPlaybackSpeedPresets.length - 1);
        });
        return true;
      }
      // Back and OK both commit the highlighted preset so the user never has to
      // "confirm" separately — highlighting is the selection.
      final idx = _vodSpeedPickerFocusIndex
          .clamp(0, kVodPlaybackSpeedPresets.length - 1);
      _applyVodSpeedPreset(kVodPlaybackSpeedPresets[idx]);
      return true;
    }

    // ── VOD subtitle picker (OpenSubtitles) ──
    if (!widget.isLive && _vodSubtitlePickerOpen) {
      if (_vodSubLoading) {
        if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
          _closeVodSubtitlePicker(blockDuplicateBackExit: true);
          return true;
        }
        return true;
      }
      if (_vodSubSearchFocused) {
        final hintCount = _vodSubSearchHints.length;
        final inHints = _vodSubSearchHintDpadIndex >= 0;
        if (inHints) {
          if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
            setState(() => _vodSubSearchHintDpadIndex = -1);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _vodSubSearchFocusNode.requestFocus();
            });
            return true;
          }
          if (k == LogicalKeyboardKey.arrowUp) {
            if (_vodSubSearchHintDpadIndex > 0) {
              setState(() => _vodSubSearchHintDpadIndex--);
            } else {
              setState(() => _vodSubSearchHintDpadIndex = -1);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _vodSubSearchFocusNode.requestFocus();
              });
            }
            return true;
          }
          if (k == LogicalKeyboardKey.arrowDown) {
            if (hintCount > 0 &&
                _vodSubSearchHintDpadIndex < hintCount - 1) {
              setState(() => _vodSubSearchHintDpadIndex++);
            }
            return true;
          }
          if (k == LogicalKeyboardKey.select ||
              k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.numpadEnter) {
            if (hintCount > 0) {
              final i = _vodSubSearchHintDpadIndex.clamp(0, hintCount - 1);
              _onVodSubSearchHintPicked(_vodSubSearchHints[i]);
            }
            return true;
          }
          return true;
        }
        if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
          if (_vodImeBottom > 0) {
            unawaited(
              SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
            );
            return true;
          }
          setState(() {
            _vodSubSearchFocused = false;
            _vodSubSearchHintDpadIndex = -1;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _playerRootFocusNode.requestFocus();
          });
          return true;
        }
        if (k == LogicalKeyboardKey.arrowDown) {
          if (hintCount > 0) {
            setState(() => _vodSubSearchHintDpadIndex = 0);
            _vodSubSearchFocusNode.unfocus();
            return true;
          }
          setState(() {
            _vodSubSearchFocused = false;
            _vodSubSearchHintDpadIndex = -1;
            _vodSubFocusColumn = 0;
            _vodSubLangIndex = 0;
            _vodSubFileIndex = 0;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _playerRootFocusNode.requestFocus();
          });
          return true;
        }
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter) {
          unawaited(_loadVodSubtitleSearch());
          return true;
        }
        return false;
      }
      final clearRow = _vodHasExternalSubtitle;
      final langCount =
          _vodSubGroups.length + (clearRow ? 1 : 0);
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        _closeVodSubtitlePicker(blockDuplicateBackExit: true);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        setState(() => _vodSubFocusColumn = 0);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        if (clearRow && _vodSubLangIndex == 0) {
          return true;
        }
        final gIdx = clearRow ? _vodSubLangIndex - 1 : _vodSubLangIndex;
        if (gIdx >= 0 &&
            gIdx < _vodSubGroups.length &&
            _vodSubGroups[gIdx].files.isNotEmpty) {
          setState(() => _vodSubFocusColumn = 1);
        }
        return true;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_vodSubFocusColumn == 0) {
          if (langCount <= 0 || _vodSubLangIndex == 0) {
            setState(() {
              _vodSubSearchFocused = true;
              _vodSubSearchHintDpadIndex = -1;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _vodSubSearchFocusNode.requestFocus();
              _onVodSubSearchTextChanged();
            });
            return true;
          }
          setState(() {
            _vodSubLangIndex =
                (_vodSubLangIndex - 1).clamp(0, langCount - 1);
            _vodSubFileIndex = 0;
          });
          return true;
        }
        final gIdx = clearRow ? _vodSubLangIndex - 1 : _vodSubLangIndex;
        if (gIdx >= 0 && gIdx < _vodSubGroups.length) {
          final files = _vodSubGroups[gIdx].files;
          if (files.isNotEmpty) {
            setState(() {
              _vodSubFileIndex =
                  (_vodSubFileIndex - 1).clamp(0, files.length - 1);
            });
          }
        }
        return true;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        if (langCount <= 0) return true;
        if (_vodSubFocusColumn == 0) {
          setState(() {
            _vodSubLangIndex =
                (_vodSubLangIndex + 1).clamp(0, langCount - 1);
            _vodSubFileIndex = 0;
          });
        } else {
          final gIdx = clearRow ? _vodSubLangIndex - 1 : _vodSubLangIndex;
          if (gIdx >= 0 && gIdx < _vodSubGroups.length) {
            final files = _vodSubGroups[gIdx].files;
            if (files.isNotEmpty) {
              setState(() {
                _vodSubFileIndex =
                    (_vodSubFileIndex + 1).clamp(0, files.length - 1);
              });
            }
          }
        }
        return true;
      }
      if (_isActivateKey(k)) {
        if (_vodSubFocusColumn == 0) {
          if (clearRow && _vodSubLangIndex == 0) {
            unawaited(_clearVodExternalSubtitle());
            return true;
          }
          if (_vodSubGroups.isNotEmpty) {
            setState(() {
              _vodSubFocusColumn = 1;
              _vodSubFileIndex = 0;
            });
          }
          return true;
        }
        final gIdx = clearRow ? _vodSubLangIndex - 1 : _vodSubLangIndex;
        if (gIdx >= 0 && gIdx < _vodSubGroups.length) {
          final files = _vodSubGroups[gIdx].files;
          if (files.isNotEmpty) {
            final fi = _vodSubFileIndex.clamp(0, files.length - 1);
            unawaited(_applyVodSubtitleFile(files[fi].fileId));
          }
        }
        return true;
      }
      return true;
    }

    // ── Multiview context menu open ──
    if (widget.isLive && _mvMenuVisible) {
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        setState(() => _mvMenuVisible = false);
        return true;
      }
      final items = _mvBuildMenuItems();
      if (k == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _mvMenuFocusIndex = (_mvMenuFocusIndex - 1).clamp(0, items.length - 1);
        });
        return true;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _mvMenuFocusIndex = (_mvMenuFocusIndex + 1).clamp(0, items.length - 1);
        });
        return true;
      }
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
        setState(() => _mvMenuVisible = false);
        _mvHandleArrowKey(k);
        _requestPlayerRootFocus();
        return true;
      }
      if (_isActivateKey(k)) {
        final idx = _mvMenuFocusIndex.clamp(0, items.length - 1);
        _mvActivateMenuItem(items[idx].action);
        return true;
      }
      return true;
    }

    // ── Multiview tile arrows (not in menu) ──
    if (widget.isLive && _inMultiview && !_mvMenuVisible) {
      if (_mvHandleArrowKey(k)) return true;
    }

    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      if (!Platform.isAndroid) {
        unawaited(_exit());
      }
      return true;
    }

    if (widget.isLive && !_controlsVisible && _isActivateKey(k)) {
      if (_inMultiview) {
        setState(() {
          _mvMenuVisible = true;
          _mvMenuFocusIndex = 0;
        });
        _hideTimer?.cancel();
        return true;
      }
      _showControlsAndFocusPlay();
      return true;
    }
    if (!widget.isLive &&
        _vodSeekable &&
        !_vodJumpStripFocused &&
        _isActivateKey(k)) {
      unawaited(_togglePlayPause());
      return true;
    }

    // ── Right-side options panel (open) ──
    if (widget.isLive && _rightPanelVisible && !_inMultiview) {
      if (k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.goBack ||
          k == LogicalKeyboardKey.escape) {
        setState(() => _rightPanelVisible = false);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _rightPanelFocusIndex =
              _stepRightPanelSlot(_rightPanelFocusIndex, -1);
        });
        return true;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _rightPanelFocusIndex =
              _stepRightPanelSlot(_rightPanelFocusIndex, 1);
        });
        return true;
      }
      if (_isActivateKey(k)) {
        if (_rightPanelFocusIndex == 0) {
          unawaited(_openSettingsOverlayFromPanel());
        } else if (_rightPanelFocusIndex == 1) {
          _enterMultiview();
        } else if (_rightPanelFocusIndex == 2) {
          _openCatchUpFromPlayer();
        } else if (_rightPanelFocusIndex == 3) {
          _openEpgFromPanel();
        } else if (_rightPanelFocusIndex == 4) {
          unawaited(_openParentalFromPanel());
        } else if (_rightPanelFocusIndex == 5) {
          unawaited(_cycleLiveVideoQuality());
        }
        return true;
      }
      return true;
    }

    // ── Multiview: DOWN opens the tile menu ──
    if (widget.isLive && _inMultiview && k == LogicalKeyboardKey.arrowDown) {
      if (!_mvMenuVisible) {
        setState(() {
          _mvMenuVisible = true;
          _mvMenuFocusIndex = 0;
        });
        _hideTimer?.cancel();
      }
      return true;
    }

    // ── Live TV channel switching: UP/DOWN switch channels (not while panel async/PIN flow).
    if (_liveLineSwitching &&
        !_inMultiview &&
        !_suppressLiveLineSwitchForPanelAsync) {
      if (k == LogicalKeyboardKey.arrowUp) {
        _switchLiveRelative(1);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        _switchLiveRelative(-1);
        return true;
      }
    }

    // ── RIGHT key: EPG visible → next programme; overlay hidden → open side menu ──
    if (widget.isLive &&
        !_inMultiview &&
        !_rightPanelVisible &&
        k == LogicalKeyboardKey.arrowRight) {
      _applyLiveTvArrowRightAction();
      return true;
    }

    // ── LEFT key: navigate EPG when visible ──
    if (widget.isLive && !_inMultiview && _controlsVisible &&
        k == LogicalKeyboardKey.arrowLeft) {
      _nudgeLiveEpgWindow(-1);
      return true;
    }

    // ── SELECT on EPG ──
    if (widget.isLive && _controlsVisible && !_rightPanelVisible &&
        !_inMultiview && _isActivateKey(k)) {
      return _handleLiveEpgCenterActivate();
    }

      if (!widget.isLive && _vodSeekable && _vodJumpStripFocused) {
      if (k == LogicalKeyboardKey.arrowLeft) {
        if (_vodJumpFocusIndex > 0) {
          setState(() => _vodJumpFocusIndex--);
        }
        _scheduleHideControls();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        if (_vodJumpFocusIndex < _vodJumpMaxIndex) {
          setState(() => _vodJumpFocusIndex++);
        }
        _scheduleHideControls();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        setState(() => _vodJumpStripFocused = false);
        _scheduleHideControls();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        _scheduleHideControls();
        return true;
      }
      if (_isActivateKey(k)) {
        _activateVodJumpButton(_vodJumpFocusIndex);
        return true;
      }
    }

    if (!widget.isLive && _vodSeekable) {
      if (k == LogicalKeyboardKey.arrowDown) {
        _handleVodDown();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        _showVodInfoBanner();
        return true;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        _seekBy(-_vodSeekTapMs);
        _startSeekHold(LogicalKeyboardKey.arrowLeft);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        _seekBy(_vodSeekTapMs);
        _startSeekHold(LogicalKeyboardKey.arrowRight);
        return true;
      }
    }

    if (k == LogicalKeyboardKey.mediaPlay) {
      unawaited(_service.play());
      if (widget.isLive) _pokeControls();
      return true;
    }
    if (k == LogicalKeyboardKey.mediaPause) {
      unawaited(_service.pause());
      if (widget.isLive) _pokeControls();
      return true;
    }
    if (k == LogicalKeyboardKey.mediaPlayPause) {
      unawaited(_togglePlayPause());
      if (widget.isLive) _pokeControls();
      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _vodSubSearchController.addListener(_onVodSubSearchTextChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final b = MediaQuery.viewInsetsOf(context).bottom;
      if (b != _vodImeBottom) {
        setState(() => _vodImeBottom = b);
      }
    });
    if (Platform.isAndroid) {
      unawaited(DeviceMemoryChannel.setKeepScreenOn(true));
    }
    HardwareKeyboard.instance.addHandler(_onPlayerHardwareKey);
    final lineup = widget.liveLineup;
    if (lineup != null && lineup.isNotEmpty) {
      _liveIndex = widget.initialLiveIndex.clamp(0, lineup.length - 1);
      final first = lineup[_liveIndex];
      _displayTitle = first.title;
      _activeStreamUrl = first.streamUrl;
    } else {
      _liveIndex = 0;
      _displayTitle = widget.title;
      _activeStreamUrl = widget.streamUrl;
    }

    _service = createPlayerService();
    _sub = _service.events.listen(_onEvent);
    if (widget.isLive) {
      PlayerSessionRestoreMarker.markLiveOpened();
      final cid = _effectiveEpgChannelId;
      if (cid != null) {
        unawaited(
          LiveEpgController.instance.refreshForStream(
            cid,
            epgChannelId: _effectiveEpgXmltvId,
          ),
        );
      }
    } else if (widget.resumeContentId != null) {
      _vodSessionRestoreActive = true;
      PlayerSessionRestoreMarker.markVodOpened();
      unawaited(
        AppSessionRestoreStore.instance.recordVodPlaybackSnapshot(
          resumeContentId: widget.resumeContentId!,
          title: widget.title,
          streamUrl: widget.streamUrl,
          contentDescription: widget.contentDescription,
          subtitleSearchQuery: widget.subtitleSearchQuery,
          browseMovieId: widget.browseMovieId,
          browseSeriesId: widget.browseSeriesId,
        ),
      );
    }
    scheduleMicrotask(_bootstrap);
    unawaited(SubtitleAppearanceStore.instance.ensureLoaded());
    if (widget.isLive) {
      _scheduleHideControls();
    } else {
      _hideTimer?.cancel();
    }
  }

  /// Live stream was killed when the app went to background; on resume the
  /// player pops and the channel is re-opened fresh by the browse screen.
  var _liveBackgroundKilled = false;

  /// Set when [_exit] is triggered by a background-kill resume so the pop
  /// result tells the browse screen to re-open the channel immediately.
  var _exitDueToBackgroundKill = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!Platform.isAndroid) return;
    switch (state) {
      case AppLifecycleState.paused:
        if (widget.isLive && !_released) {
          _updateLiveSessionSnapshotFromPlayer();
          _liveBackgroundKilled = true;
          unawaited(_killLiveStreamForBackground());
        }
        _hadPausedLifecycle = true;
        unawaited(DeviceMemoryChannel.setKeepScreenOn(false));
        break;
      case AppLifecycleState.resumed:
        if (widget.isLive && _liveBackgroundKilled && mounted && !_released) {
          _liveBackgroundKilled = false;
          _exitDueToBackgroundKill = true;
          unawaited(_exit());
          return;
        }
        if (mounted && !_released) {
          unawaited(DeviceMemoryChannel.setKeepScreenOn(true));
          if (_hadPausedLifecycle) {
            _hadPausedLifecycle = false;
            unawaited(_rebootstrapAfterResume());
          }
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        unawaited(DeviceMemoryChannel.setKeepScreenOn(false));
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final b = MediaQuery.viewInsetsOf(context).bottom;
    if (b == _vodImeBottom) return;
    setState(() => _vodImeBottom = b);
  }

  /// Immediately stops all live playback resources without popping the route.
  /// Called when the app goes to background while watching live TV.
  Future<void> _killLiveStreamForBackground() async {
    if (_released) return;
    if (_inMultiview) {
      try { await _mvReleasePool(); } catch (_) {}
      _mvTiles.clear();
    }
    try { await _lfStop(); } catch (_) {}
    try { await _service.pause(); } catch (_) {}
    try { await _service.releaseTexture(); } catch (_) {}
    if (mounted) setState(() => _textureId = null);
  }

  /// Re-bootstrap playback after the app returns from background.
  ///
  /// [MainActivity.onPause] pauses ExoPlayer and the surface may be
  /// invalidated while the activity is stopped. For live streams the buffer
  /// also goes stale, so a fresh [load] is required (not just [play]).
  /// For VOD we only need to resume playback at the current position.
  Future<void> _rebootstrapAfterResume() async {
    if (_released || !mounted) return;
    if (widget.isLive) {
      // Stop leapfrog pool — it will be restarted after the main player
      // re-bootstraps (same as initial _bootstrap).
      if (_lfActive) {
        await _lfStop();
      }
      // Fully release the old surface so no stale last-frame is visible,
      // then create a fresh texture + load the channel from scratch.
      try {
        await _service.releaseTexture();
      } catch (_) {}
      setState(() {
        _textureId = null;
        _initError = null;
        _retryBanner = false;
        _fatalError = null;
      });
      try {
        final id = await _service.ensureTexture();
        if (!mounted || _released) return;
        await _service.load(
          url: _activeStreamUrl,
          isLive: true,
          liveFastSwitch: _liveFastChannelSwitch,
        );
        if (!mounted || _released) return;
        setState(() {
          _textureId = id;
          _initError = null;
        });
        if (_useLeapfrogPool) {
          unawaited(_lfStart());
        }
      } catch (e) {
        if (!mounted || _released) return;
        setState(() => _initError = e.toString());
      }
    } else {
      // VOD: surface is still valid, just resume playback at current position.
      try {
        await _service.play();
      } catch (_) {}
    }
  }

  /// Syncs the current in-player live channel back to [LiveTvSessionSnapshot]
  /// so [MainShellScreen._persistSessionSnapshot] writes the correct channel
  /// when the app goes to background.
  void _updateLiveSessionSnapshotFromPlayer() {
    if (!widget.isLive) return;
    final chId = _currentLiveChannelId;
    if (chId == null || chId.isEmpty) return;
    final catId = widget.liveViewCategoryId;
    if (catId == null || catId.isEmpty) return;
    LiveTvSessionSnapshot.update(categoryId: catId, channelId: chId);
  }

  bool get _isDesktopPlayer => _service is DesktopPlayerService;

  Future<void> _bootstrap() async {
    if (!isNativePlayerSupported) {
      if (mounted) {
        setState(() => _initError = 'Playback is not available on this platform.');
      }
      return;
    }
    Offset? loadedVodSubPos;
    try {
      if (widget.resumeContentId != null && !widget.isLive) {
        final r = await PlaybackResumeStore.getResumePositionMs(
          widget.resumeContentId!,
        );
        if (!mounted) return;
        if (r != null && r > 0) {
          _pendingResumeMs = r;
        }
        final off = await VodAudioOffsetStore.getOffsetMs(widget.resumeContentId!);
        if (!mounted) return;
        _vodAudioDelayMs = off;
        final subDelay =
            await VodSubtitleDelayStore.getOffsetMs(widget.resumeContentId!);
        if (!mounted) return;
        _vodSubtitleDelayMs = subDelay;
        loadedVodSubPos =
            await VodSubtitlePositionStore.getIfSet(widget.resumeContentId!);
        if (!mounted) return;
      }

      final id = await _service.ensureTexture();
      if (!mounted || _released) return;
      try {
        await _service.load(
          url: _activeStreamUrl,
          isLive: widget.isLive,
          audioDelayMs: widget.isLive ? 0 : _vodAudioDelayMs,
          subtitleDelayMs: widget.isLive ? 0 : _vodSubtitleDelayMs,
          playbackSpeed: widget.isLive ? 1.0 : _vodPlaybackSpeed,
          liveFastSwitch: widget.isLive && _liveFastChannelSwitch,
        );
      } catch (_) {
        if (_released || !mounted) return;
        rethrow;
      }
      if (!mounted || _released) return;
      setState(() {
        _textureId = id;
        _initError = null;
        if (loadedVodSubPos != null) {
          _vodPerMovieSubtitlePos = loadedVodSubPos;
        }
      });
      if (widget.isLive && Platform.isWindows) {
        unawaited(_applyWindowsLiveVolume());
      }
      _startResumeSaver();
      // Start leapfrog pre-buffering for live channels (strong devices / Shield Full only).
      if (widget.isLive && _useLeapfrogPool) {
        unawaited(_lfStart());
      }
    } catch (e) {
      if (!mounted || _released) return;
      setState(() => _initError = e.toString());
    }
  }

  void _startResumeSaver() {
    _resumeSaveTimer?.cancel();
    if (widget.resumeContentId == null || widget.isLive) return;
    _resumeSaveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveResumePosition(),
    );
  }

  void _maybeClampResume() {
    final d = _durationMs;
    if (_pendingResumeMs <= 0 || d <= 0) return;
    const endGapMs = 8000;
    if (_pendingResumeMs > d - endGapMs) {
      _pendingResumeMs = math.max(0, d - endGapMs);
    }
  }

  int _effectivePositionMsForPersistence() {
    final sync = _service.playbackPositionMsSync;
    if (sync != null) return sync;
    return _positionMs;
  }

  /// Windows/macOS: mpv may ignore the first seek while demuxing — retry until we
  /// land near the saved resume point, then set [_resumeApplied] (unlike Android).
  Future<void> _applyDesktopResumeSeek() async {
    if (!_isDesktopPlayer ||
        widget.isLive ||
        _released ||
        _resumeApplied ||
        _pendingResumeMs <= 0 ||
        widget.resumeContentId == null) {
      return;
    }
    if (_desktopResumeSeekInFlight) return;
    _desktopResumeSeekInFlight = true;
    final target = _pendingResumeMs;
    const step = Duration(milliseconds: 200);
    const maxAttempts = 30;
    const toleranceMs = 1800;
    try {
      for (var i = 0; i < maxAttempts; i++) {
        if (!mounted || _released) return;
        try {
          await _service.seekTo(Duration(milliseconds: target));
        } catch (_) {}
        await Future<void>.delayed(step);
        if (!mounted || _released) return;
        final actual =
            _service.playbackPositionMsSync ?? _positionMs;
        if ((actual - target).abs() <= toleranceMs) {
          if (mounted) {
            setState(() {
              _positionMs = actual;
              _resumeApplied = true;
            });
          }
          return;
        }
        if (actual > target + toleranceMs) {
          if (mounted) {
            setState(() {
              _positionMs = actual;
              _resumeApplied = true;
            });
          }
          return;
        }
      }
      final fallback = _service.playbackPositionMsSync ?? _positionMs;
      if (mounted && !_released) {
        setState(() {
          _positionMs = fallback;
          _resumeApplied = true;
        });
      }
    } finally {
      _desktopResumeSeekInFlight = false;
    }
  }

  Future<void> _refreshTracks() async {
    try {
      final snap = await _service.getTracksSnapshot();
      if (mounted && !_released) {
        setState(() => _tracksSnapshot = snap);
      }
    } catch (_) {}
  }

  void _onEvent(PlayerNativeEvent e) {
    if (!mounted || _released) return;
    switch (e.type) {
      case 'channelSwitch':
        break;
      case 'state':
        final wasBuffering = _buffering;
        _buffering = e.isBuffering;
        if (!widget.isLive) {
          if (e.isBuffering && !wasBuffering) {
            _vodStuckBufferTimer?.cancel();
            _vodStuckBufferOfferExit = false;
            _vodStuckBufferTimer = Timer(_vodStuckBufferOfferDelay, () {
              if (!mounted || _released || !_buffering || _fatalError != null) {
                return;
              }
              setState(() => _vodStuckBufferOfferExit = true);
            });
          } else if (!e.isBuffering) {
            _vodStuckBufferTimer?.cancel();
            _vodStuckBufferTimer = null;
            if (_vodStuckBufferOfferExit) {
              setState(() => _vodStuckBufferOfferExit = false);
            }
          }
        }
        if (widget.isLive) {
          if (e.isBuffering) {
            if (_liveSpinnerDelayTimer == null || !_liveSpinnerDelayTimer!.isActive) {
              _liveSpinnerDelayTimer?.cancel();
              _liveSpinnerDelayTimer = Timer(
                _liveBufferingSpinnerDelay,
                () {
                  if (!mounted || _released) return;
                  if (_buffering) setState(() => _showLiveSpinner = true);
                },
              );
            }
          } else {
            _liveSpinnerDelayTimer?.cancel();
            _liveSpinnerDelayTimer = null;
            _showLiveSpinner = false;
          }
        }
        if (!widget.isLive && e.playbackState == 'ready') {
          _vodSeekGraceTimer?.cancel();
          _vodSeekSpinnerGrace = false;
        }
        setState(() {});
        if (e.playbackState == 'ready') {
          _maybeClampResume();
          if (!_resumeApplied &&
              _pendingResumeMs > 0 &&
              !widget.isLive &&
              widget.resumeContentId != null) {
            if (_isDesktopPlayer) {
              unawaited(_applyDesktopResumeSeek());
            } else {
              _resumeApplied = true;
              unawaited(
                _service.seekTo(Duration(milliseconds: _pendingResumeMs)),
              );
            }
          }
          unawaited(_refreshTracks());
          if (widget.isLive && isNativePlayerSupported) {
            unawaited(_refreshLiveVideoVariantHeights());
          }
        }
        break;
      case 'isPlaying':
        setState(() => _playing = e.isPlaying ?? false);
        break;
      case 'progress':
        final prevDurBeforeTick = _durationMs;
        setState(() {
          // Native/desktop may emit **partial** progress (e.g. position-only).
          // Do not overwrite known duration/buffer with defaults — that cleared
          // VOD chrome on every tick (Windows media_kit separate streams).
          if (e.positionMs != null) {
            _positionMs = e.positionMs!;
          }
          if (e.bufferedMs != null) {
            _bufferedMs = e.bufferedMs!;
          }
          final prevDur = _durationMs;
          if (e.durationMs != null) {
            _durationMs = e.durationMs!;
          }
          final d = _durationMs;
          // Show the dock once when duration first becomes known — do not force
          // visible on every progress tick (that fought auto-hide and caused flicker).
          if (!widget.isLive && d > 0 && prevDur <= 0) {
            _vodTimelineVisible = true;
          }
          if (e.isPlaying != null) {
            _playing = e.isPlaying!;
          }
          final vw = e.videoWidth;
          final vh = e.videoHeight;
          final br = e.bitrate;
          if (vw != null && vw > 0) _videoWidth = vw;
          if (vh != null && vh > 0) _videoHeight = vh;
          if (br != null && br > 0) _bitrate = br;
        });
        if (widget.isLive &&
            _lfActive &&
            _rightPanelVisible &&
            PlayerPool.supported) {
          final now = DateTime.now();
          if (_lastLfPoolMetricsPoll == null ||
              now.difference(_lastLfPoolMetricsPoll!) >
                  const Duration(milliseconds: 900)) {
            _lastLfPoolMetricsPoll = now;
            unawaited(_refreshLfPoolVideoHeight());
          }
        }
        _maybeClampResume();
        // Without this, the dock can stay forever the first time duration arrives
        // (no hide timer was ever scheduled).
        if (!widget.isLive &&
            e.durationMs != null &&
            e.durationMs! > 0 &&
            prevDurBeforeTick <= 0) {
          _scheduleHideControls();
        }
        break;
      case 'cues':
        final next = e.cueLines ?? const <String>[];
        if (listEquals(_vodSubtitleLines, next)) return;
        setState(() => _vodSubtitleLines = next);
        break;
      case 'retrying':
        _vodStuckBufferTimer?.cancel();
        _vodStuckBufferTimer = null;
        setState(() {
          _retryBanner = true;
          _fatalError = null;
          _vodStuckBufferOfferExit = false;
        });
        break;
      case 'error':
        _vodStuckBufferTimer?.cancel();
        _vodStuckBufferTimer = null;
        setState(() {
          _retryBanner = false;
          _fatalError = e.message ?? 'Playback failed';
          _vodStuckBufferOfferExit = false;
        });
        break;
    }
  }

  void _pokeControls() {
    if (!mounted || _released || !widget.isLive) return;
    _liveFadeOutTimer?.cancel();
    if (_inMultiview) return;
    setState(() {
      _controlsVisible = true;
      _liveOverlayFadingOut = false;
    });
    _scheduleHideControls();
  }

  /// Same outcome as D-pad **Right** on live (EPG nudge when chrome visible, else open panel).
  void _applyLiveTvArrowRightAction() {
    if (!mounted || _released || !widget.isLive || _inMultiview || _rightPanelVisible) {
      return;
    }
    if (_controlsVisible) {
      _nudgeLiveEpgWindow(1);
      return;
    }
    setState(() {
      _rightPanelVisible = true;
      _rightPanelFocusIndex = _firstEnabledRightPanelSlot();
    });
    unawaited(_refreshLiveVideoVariantHeights());
    if (_lfActive) {
      unawaited(_refreshLfPoolVideoHeight());
    }
    _pokeControls();
  }

  void _onVideoSurfaceTap() {
    if (widget.isLive && _isDesktopLiveUi) {
      setState(() {
        _liveDesktopEpgOpen = !_liveDesktopEpgOpen;
        if (_liveDesktopEpgOpen) {
          _liveDesktopBottomHover = true;
        }
      });
      _scheduleHideControls();
      return;
    }
    if (!widget.isLive && _vodSeekable) {
      if (_vodChromeHidden) {
        _handleVodDown();
      } else {
        unawaited(_togglePlayPause());
      }
      return;
    }
    if (widget.isLive &&
        (Platform.isAndroid || Platform.isIOS) &&
        !_inMultiview) {
      if (!_controlsVisible) {
        _showControlsAndFocusPlay();
      } else {
        unawaited(_togglePlayPause());
      }
      return;
    }
    unawaited(_togglePlayPause());
    if (widget.isLive) {
      _pokeControls();
    } else {
      _flashVodTimeline();
    }
  }

  void _liveRightEdgeSwipeReset() {
    _liveRightEdgeSwipePointer = null;
    _liveRightEdgeSwipeDownGlobal = null;
  }

  void _onLiveRightEdgePointerDown(PointerDownEvent e) {
    if (!widget.isLive || _released || _inMultiview || _rightPanelVisible) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    if (e.kind != PointerDeviceKind.touch) return;
    _liveRightEdgeSwipePointer = e.pointer;
    _liveRightEdgeSwipeDownGlobal = e.position;
  }

  /// Touch-only: short tap on the right-edge strip opens chrome and/or the
  /// options panel without changing D-pad **Right** behavior ([_applyLiveTvArrowRightAction]).
  void _onLiveRightEdgeStripTap() {
    if (!mounted || _released || !widget.isLive || _inMultiview) return;
    if (_rightPanelVisible) return;
    if (!_controlsVisible) {
      _showLiveTvChromeWithSidePanel();
      return;
    }
    setState(() {
      _rightPanelVisible = true;
      _rightPanelFocusIndex = _firstEnabledRightPanelSlot();
    });
    unawaited(_refreshLiveVideoVariantHeights());
    if (_lfActive) {
      unawaited(_refreshLfPoolVideoHeight());
    }
    _pokeControls();
  }

  void _onLiveRightEdgePointerUp(PointerUpEvent e) {
    if (e.pointer != _liveRightEdgeSwipePointer ||
        _liveRightEdgeSwipeDownGlobal == null) {
      _liveRightEdgeSwipeReset();
      return;
    }
    final start = _liveRightEdgeSwipeDownGlobal!;
    _liveRightEdgeSwipeReset();
    if (!widget.isLive || _released || _inMultiview || _rightPanelVisible) return;
    final dx = e.position.dx - start.dx;
    final dy = (e.position.dy - start.dy).abs();
    // D-pad-equivalent swipe: left from edge (unchanged remote semantics).
    if (dx <= -40 && dy <= 72) {
      _applyLiveTvArrowRightAction();
      return;
    }
    // Touch: small movement = tap on strip → open panel (or chrome + panel).
    if (dx.abs() < 16 && dy < 32) {
      _onLiveRightEdgeStripTap();
    }
  }

  void _beginLiveOverlayFadeOut() {
    _liveFadeOutTimer?.cancel();
    setState(() {
      _controlsVisible = false;
      _liveOverlayFadingOut = true;
      _rightPanelVisible = false;
      _liveEpgWindowCenter = -1;
      if (_isDesktopLiveUi) {
        _liveDesktopBottomHover = false;
        _liveDesktopEpgOpen = false;
        _liveDesktopTopHover = false;
      }
    });
    _liveFadeOutTimer = Timer(PlayerTvOverlayTheme.fadeDuration, () {
      if (!mounted || _released) return;
      setState(() => _liveOverlayFadingOut = false);
    });
  }

  void _hideControlsOverlay({bool immediate = false}) {
    _hideTimer?.cancel();
    if (!mounted || _released) return;
    if (widget.isLive) {
      if (_mvMenuVisible) {
        setState(() => _mvMenuVisible = false);
        return;
      }
      if (immediate || _liveOverlayFadingOut) {
        _liveFadeOutTimer?.cancel();
        setState(() {
          _controlsVisible = false;
          _liveOverlayFadingOut = false;
          _rightPanelVisible = false;
          _liveEpgWindowCenter = -1;
          if (_isDesktopLiveUi) {
            _liveDesktopBottomHover = false;
            _liveDesktopEpgOpen = false;
            _liveDesktopTopHover = false;
          }
        });
      } else if (_controlsVisible) {
        _beginLiveOverlayFadeOut();
      }
      return;
    }
    if (_vodSubtitleStylePanelOpen) {
      _closeVodSubtitleStylePanelAndRestoreJumpFocus();
      return;
    }
    if (_vodSubtitleDelayPopupOpen) {
      _closeVodSubtitleDelayPopup();
      return;
    }
    var unfocusVodSubSearch = false;
    if (_vodSubtitlePickerOpen) {
      _vodSubSearchHintDebounce?.cancel();
    }
    setState(() {
      if (_vodAudioOffsetPopupOpen) {
        _vodAudioOffsetPopupOpen = false;
      } else if (_vodSpeedPickerOpen) {
        _vodSpeedPickerOpen = false;
      } else if (_vodSubtitlePickerOpen) {
        unfocusVodSubSearch = true;
        _vodSubtitlePickerOpen = false;
        _vodSubLoading = false;
        _vodSubError = null;
        _vodSubGroups = [];
        _vodSubSearchFocused = false;
        _vodSubSearchHintDpadIndex = -1;
        _vodSubSearchHints = [];
        _vodSubSearchHintsLoading = false;
      } else {
        _vodTimelineVisible = false;
        _vodInfoBannerVisible = false;
        _vodJumpStripFocused = false;
      }
    });
    if (unfocusVodSubSearch) _vodSubSearchFocusNode.unfocus();
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    if (widget.isLive && _rightPanelVisible) {
      return;
    }
    if (!widget.isLive &&
        (_vodSpeedPickerOpen ||
            _vodAudioOffsetPopupOpen ||
            _vodSubtitleDelayPopupOpen ||
            _vodSubtitlePickerOpen ||
            _vodSubtitleStylePanelOpen)) {
      return;
    }
    if (widget.isLive && _mvMenuVisible) {
      return;
    }
    _hideTimer = Timer(PlayerTvOverlayTheme.autoHideDuration, () {
      if (!mounted || _released) return;
      if (widget.isLive) {
        _beginLiveOverlayFadeOut();
      } else {
        if (_vodSpeedPickerOpen ||
            _vodAudioOffsetPopupOpen ||
            _vodSubtitleDelayPopupOpen ||
            _vodSubtitlePickerOpen ||
            _vodSubtitleStylePanelOpen) {
          return;
        }
        // Hide the full bottom dock after idle (timeline + jump row) so the
        // screen clears; next Back exits if nothing is showing.
        setState(() {
          _vodTimelineVisible = false;
          _vodInfoBannerVisible = false;
          _vodJumpStripFocused = false;
        });
      }
    });
  }

  Future<void> _saveResumePosition() async {
    final id = widget.resumeContentId;
    if (id == null || widget.isLive) return;
    final pos = _effectivePositionMsForPersistence();
    if (pos < 3000) return;
    await PlaybackResumeStore.setResumePositionMs(id, pos);
  }

  /// VOD movies / series: same labels as manual toggles ([MovieVodLabel]).
  Future<void> _applyAutoVodMovieLabelIfNeeded() async {
    if (widget.isLive) return;
    final dur = _durationMs;
    if (dur <= 0) return;
    var pos = _positionMs;
    if (pos < 0) pos = 0;
    const endFrac = 0.92;
    const minProgressMs = 3000;
    final resumeKey = widget.resumeContentId;
    final movieId = widget.browseMovieId;
    final seriesId = widget.browseSeriesId;
    if (movieId != null) {
      await MovieVodLabelStore.instance.ensureLoaded();
      if (pos >= dur * endFrac) {
        await MovieVodLabelStore.instance.setLabel(
          movieId,
          MovieVodLabel.watched,
        );
        if (resumeKey != null) {
          await PlaybackResumeStore.clear(resumeKey);
        }
      } else if (pos >= minProgressMs && pos < dur * endFrac) {
        await MovieVodLabelStore.instance.setLabel(
          movieId,
          MovieVodLabel.continueWatching,
        );
      }
    } else if (seriesId != null) {
      await SeriesVodLabelStore.instance.ensureLoaded();
      String? episodeId;
      if (resumeKey != null && resumeKey.startsWith('episode_')) {
        episodeId = resumeKey.substring('episode_'.length);
      }
      if (episodeId != null) {
        await EpisodeVodLabelStore.instance.ensureLoaded();
        if (pos >= dur * endFrac) {
          await EpisodeVodLabelStore.instance.setLabel(
            episodeId,
            MovieVodLabel.watched,
          );
          if (resumeKey != null) {
            await PlaybackResumeStore.clear(resumeKey);
          }
        } else if (pos >= minProgressMs && pos < dur * endFrac) {
          await EpisodeVodLabelStore.instance.setLabel(
            episodeId,
            MovieVodLabel.continueWatching,
          );
        }
      }
      if (pos >= dur * endFrac) {
        await SeriesVodLabelStore.instance.setLabel(
          seriesId,
          MovieVodLabel.watched,
        );
        if (resumeKey != null && episodeId == null) {
          await PlaybackResumeStore.clear(resumeKey);
        }
      } else if (pos >= minProgressMs && pos < dur * endFrac) {
        await SeriesVodLabelStore.instance.setLabel(
          seriesId,
          MovieVodLabel.continueWatching,
        );
      }
    }
  }

  Future<void> _releasePlayerSurface() async {
    if (_released) return;
    _released = true;
    final syncExitPos = _service.playbackPositionMsSync;
    if (syncExitPos != null) {
      _positionMs = syncExitPos;
    }
    _hideTimer?.cancel();
    _liveFadeOutTimer?.cancel();
    _cancelSeekHold();
    _liveSpinnerDelayTimer?.cancel();
    _vodSeekGraceTimer?.cancel();
    _vodStuckBufferTimer?.cancel();
    _vodStuckBufferTimer = null;
    _resumeSaveTimer?.cancel();
    await _sub?.cancel();
    _sub = null;

    void clearTexture() {
      _textureId = null;
      _vodStuckBufferOfferExit = false;
    }

    if (mounted) {
      setState(clearTexture);
    } else {
      clearTexture();
    }

    try {
      await _saveResumePosition();
    } catch (_) {}
    try {
      await _applyAutoVodMovieLabelIfNeeded();
    } catch (_) {}
    try {
      await _service.pause();
    } catch (_) {}
    try {
      await _service.releaseTexture();
    } catch (_) {}
    _service.dispose();
  }

  Future<void> _exit() async {
    if (_exitInProgress) return;
    // PopScope + HardwareKeyboard + Focus can all react to one Back press; closing
    // the subtitle UI may be followed by a duplicate [_exit] in the same frame.
    // Keep [blockDuplicateBackExit] true until after the frame so every echo is dropped.
    if (!widget.isLive && _suppressNextVodPlayerExitForBack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _suppressNextVodPlayerExitForBack = false;
      });
      return;
    }
    _exitInProgress = true;
    try {
      if (_inMultiview) {
        await _mvReleasePool();
        _mvTiles.clear();
      }
      await _lfStop();
      await _releasePlayerSurface();
      if (!mounted) return;
      Navigator.of(context).pop(
        PlayerBrowseRestore(
          liveChannelId:
              widget.isLive ? _effectiveEpgChannelId : null,
          movieId: widget.isLive ? null : widget.browseMovieId,
          seriesId: widget.isLive ? null : widget.browseSeriesId,
          reopenLiveChannel: _exitDueToBackgroundKill,
        ),
      );
    } finally {
      _exitInProgress = false;
    }
  }

  void _switchLiveRelative(int delta) {
    if (_released || !_liveLineSwitching) return;
    final lineup = widget.liveLineup!;
    final n = lineup.length;
    var idx = (_liveIndex + delta) % n;
    if (idx < 0) idx += n;
    unawaited(_switchLiveToIndex(idx));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isAndroid) {
      unawaited(DeviceMemoryChannel.setKeepScreenOn(false));
    }
    if (widget.isLive) {
      PlayerSessionRestoreMarker.markLiveClosed();
    } else if (_vodSessionRestoreActive) {
      PlayerSessionRestoreMarker.markVodClosed();
      unawaited(AppSessionRestoreStore.instance.clearVodPlaybackSnapshot());
    }
    _cancelSeekHold();
    _liveSpinnerDelayTimer?.cancel();
    _vodSeekGraceTimer?.cancel();
    _vodStuckBufferTimer?.cancel();
    _vodStuckBufferTimer = null;
    _subtitleDelayApplyTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onPlayerHardwareKey);
    _hideTimer?.cancel();
    _liveFadeOutTimer?.cancel();
    _resumeSaveTimer?.cancel();
    _vodSubSearchHintDebounce?.cancel();
    final id = widget.resumeContentId;
    if (!widget.isLive && id != null) {
      unawaited(VodSubtitleDelayStore.setOffsetMs(id, _vodSubtitleDelayMs));
    }
    _vodSubSearchController.removeListener(_onVodSubSearchTextChanged);
    _vodSubSearchController.dispose();
    _vodSubSearchFocusNode.dispose();
    _playerRootFocusNode.dispose();
    if (!_released) {
      unawaited(_releasePlayerSurface());
    }
    if (Platform.isWindows) {
      unawaited(WindowsPipController.instance.exitPipIfActive());
      _dismissWindowsLiveVolumeOverlay();
    }
    super.dispose();
  }

  KeyEventResult _onRootKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (_suppressNextVodPlayerExitForBack &&
        k != LogicalKeyboardKey.goBack &&
        k != LogicalKeyboardKey.escape) {
      _suppressNextVodPlayerExitForBack = false;
    }

    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      if (!Platform.isAndroid) {
        unawaited(_exit());
      }
      return KeyEventResult.handled;
    }

    if (widget.isLive &&
        _rightPanelVisible &&
        !_inMultiview &&
        (k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowLeft ||
            k == LogicalKeyboardKey.arrowRight ||
            _isActivateKey(k))) {
      return KeyEventResult.handled;
    }

    if (widget.isLive && _inMultiview && !_mvMenuVisible) {
      if (_mvHandleArrowKey(k)) return KeyEventResult.handled;
    }

    if (widget.isLive &&
        !_controlsVisible &&
        _inMultiview &&
        _textureId != null &&
        _fatalError == null &&
        _isActivateKey(k)) {
      setState(() {
        _mvMenuVisible = true;
        _mvMenuFocusIndex = 0;
      });
      _hideTimer?.cancel();
      return KeyEventResult.handled;
    }
    if (widget.isLive &&
        !_controlsVisible &&
        !_inMultiview &&
        _textureId != null &&
        _fatalError == null &&
        _isActivateKey(k)) {
      _showLiveTvChromeWithSidePanel();
      return KeyEventResult.handled;
    }
    if (widget.isLive && !_inMultiview) _pokeControls();
    return KeyEventResult.ignored;
  }

  Future<void> _togglePlayPause() async {
    if (_released) return;
    if (widget.isLive) _pokeControls();
    try {
      if (_playing) {
        await _service.pause();
        if (!mounted || _released) return;
        setState(() => _playing = false);
      } else {
        await _service.play();
        if (!mounted || _released) return;
        setState(() => _playing = true);
      }
    } catch (_) {}
  }

  Future<void> _applyWindowsLiveVolume() async {
    if (!_isDesktopPlayer || !widget.isLive || _released) return;
    try {
      await _service.setVolume(_windowsLiveVolume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _toggleWindowsLiveMute() async {
    if (!_isDesktopPlayer || !widget.isLive) return;
    if (_windowsLiveVolume > 0.001) {
      _windowsLiveVolumeBeforeMute = _windowsLiveVolume;
      setState(() => _windowsLiveVolume = 0);
    } else {
      setState(() {
        _windowsLiveVolume =
            _windowsLiveVolumeBeforeMute > 0.001 ? _windowsLiveVolumeBeforeMute : 1.0;
      });
    }
    await _applyWindowsLiveVolume();
    _windowsLiveVolumeOverlayEntry?.markNeedsBuild();
  }

  void _dismissWindowsLiveVolumeOverlay() {
    _windowsLiveVolumeOverlayEntry?.remove();
    _windowsLiveVolumeOverlayEntry = null;
  }

  void _toggleWindowsLiveVolumeOverlay() {
    if (!_isDesktopLiveUi || !mounted) return;
    if (_windowsLiveVolumeOverlayEntry != null) {
      _dismissWindowsLiveVolumeOverlay();
      setState(() {});
      return;
    }
    final box = _windowsLiveSpeakerButtonKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null || !mounted) return;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final pos = box.localToGlobal(Offset.zero);
    final sz = box.size;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    const panelW = 220.0;
    const panelH = 96.0;
    var left = pos.dx + sz.width / 2 - panelW / 2;
    var top = pos.dy - panelH - 8;
    left = left.clamp(8.0, w - panelW - 8);
    top = top.clamp(8.0, h - panelH - 8);

    _windowsLiveVolumeOverlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _dismissWindowsLiveVolumeOverlay();
                if (mounted) setState(() {});
              },
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: panelW,
            child: Material(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Volume',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.volume_mute_rounded,
                          color: Colors.white.withValues(alpha: 0.45),
                          size: 20,
                        ),
                        Expanded(
                          child: Slider(
                            value: _windowsLiveVolume.clamp(0.0, 1.0),
                            onChanged: (v) {
                              setState(() => _windowsLiveVolume = v);
                              unawaited(_applyWindowsLiveVolume());
                              _windowsLiveVolumeOverlayEntry?.markNeedsBuild();
                            },
                          ),
                        ),
                        Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white.withValues(alpha: 0.45),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(_windowsLiveVolume * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlayState.insert(_windowsLiveVolumeOverlayEntry!);
    setState(() {});
  }

  void _seekBy(int deltaMs) {
    if (!_vodSeekable) return;
    final d = _durationMs;
    final next = (_positionMs + deltaMs).clamp(0, d);
    unawaited(_service.seekTo(Duration(milliseconds: next)));
    _beginVodSeekGrace();
    setState(() => _positionMs = next);
    _flashVodTimeline();
  }

  void _beginVodSeekGrace() {
    _vodSeekGraceTimer?.cancel();
    _vodSeekSpinnerGrace = true;
    _vodSeekGraceTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        if (!mounted || _released) return;
        setState(() => _vodSeekSpinnerGrace = false);
      },
    );
  }

  // ── Multiview layout builder ──

  double get _mainVideoAspectOr169 {
    final vw = _videoWidth;
    final vh = _videoHeight;
    if (vw != null && vh != null && vw > 0 && vh > 0) {
      return vw / vh;
    }
    return 16 / 9;
  }

  /// Compute the largest 16:9 rect that fits inside [maxW] x [maxH].
  static (double w, double h) _fit169(double maxW, double maxH) {
    const ar = 16.0 / 9.0;
    var w = maxW;
    var h = w / ar;
    if (h > maxH) {
      h = maxH;
      w = h * ar;
    }
    return (w, h);
  }

  Widget _buildMultiviewLayout(Color accent) {
    final lineup = widget.liveLineup!;
    final n = _mvTiles.length;
    if (n == 0) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final stageW = constraints.maxWidth;
      final stageH = constraints.maxHeight;
      const gap = 6.0;
      const br = 8.0;
      const bw = 2.5;

      Widget buildTile(int tileIdx, double w, double h) {
        final tile = _mvTiles[tileIdx];
        final isFocused = tileIdx == _mvFocusIndex;
        final item = lineup[tile.lineupIndex.clamp(0, lineup.length - 1)];

        final borderColor = isFocused ? accent : Colors.white.withValues(alpha: 0.12);
        final borderWidth = isFocused ? bw : 1.0;

        Widget content;
        if (tile.textureId != null) {
          content = Texture(
            filterQuality: FilterQuality.medium,
            textureId: tile.textureId!,
          );
        } else {
          content = _MvTileCard(item: item);
        }

        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(br),
            border: Border.all(color: borderColor, width: borderWidth),
            color: Colors.black,
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        );
      }

      if (n == 1) {
        final (tw, th) = _fit169(stageW * 0.72, stageH * 0.72);
        return Center(child: buildTile(0, tw, th));
      }

      // ── Enlarged: big on top, small tiles in a bottom row ──
      if (_mvEnlargedIndex != null && n > 1) {
        final ei = _mvEnlargedIndex!.clamp(0, n - 1);
        final others = <int>[for (var i = 0; i < n; i++) if (i != ei) i];

        final bigH = stageH * 0.72;
        final (bigW, bigHf) = _fit169(stageW * 0.92, bigH);

        final bottomH = stageH - bigHf - gap;
        final smallSlotW = (stageW - gap * (others.length - 1)) / others.length;
        final (smallW, smallH) = _fit169(smallSlotW, bottomH);

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildTile(ei, bigW, bigHf),
            SizedBox(height: gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var j = 0; j < others.length; j++) ...[
                  if (j > 0) SizedBox(width: gap),
                  buildTile(others[j], smallW, smallH),
                ],
              ],
            ),
          ],
        );
      }

      // ── 2 equal: side by side ──
      if (n == 2) {
        final slotW = (stageW - gap) / 2;
        final (tw, th) = _fit169(slotW, stageH);
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildTile(0, tw, th),
              SizedBox(width: gap),
              buildTile(1, tw, th),
            ],
          ),
        );
      }

      // ── 3 equal: 2 on top row, 1 centered bottom ──
      if (n == 3) {
        final topH = (stageH - gap) / 2;
        final topSlotW = (stageW - gap) / 2;
        final (topW, topHf) = _fit169(topSlotW, topH);
        final (botW, botH) = _fit169(topSlotW, stageH - topHf - gap);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildTile(0, topW, topHf),
                  SizedBox(width: gap),
                  buildTile(1, topW, topHf),
                ],
              ),
              SizedBox(height: gap),
              buildTile(2, botW, botH),
            ],
          ),
        );
      }

      // ── 4 equal: 2x2 grid, edge-to-edge ──
      final cellSlotW = (stageW - gap) / 2;
      final cellSlotH = (stageH - gap) / 2;
      final (cellW, cellH) = _fit169(cellSlotW, cellSlotH);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTile(0, cellW, cellH),
                SizedBox(width: gap),
                buildTile(1, cellW, cellH),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTile(2, cellW, cellH),
                SizedBox(width: gap),
                buildTile(3, cellW, cellH),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ── Right-side options panel ──

  String? get _currentLiveChannelId {
    final line = widget.liveLineup;
    if (line == null || line.isEmpty) return null;
    return line[_liveIndex.clamp(0, line.length - 1)].channelId;
  }

  bool get _catchUpAvailableForCurrentChannel {
    final id = _currentLiveChannelId;
    if (id == null || id.isEmpty) return false;
    return recordingCatchUpAvailableForChannelId(id);
  }

  /// True when short EPG has loaded and has at least one programme (or display line).
  bool get _rightPanelEpgEnabled {
    final id = _effectiveEpgChannelId;
    if (id == null || id.isEmpty) return false;
    if (libraryController.useDemoData) return false;
    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) return false;
    final epg = LiveEpgController.instance;
    if (epg.isLoadingFor(id)) return false;
    return epg.lookupListings(id).isNotEmpty || epg.lookupDisplay(id) != null;
  }

  /// Show slash on EPG icon when guide is unavailable (not while loading).
  bool get _rightPanelEpgNoGuideSlash {
    final id = _effectiveEpgChannelId;
    if (id == null || id.isEmpty) return false;
    if (libraryController.useDemoData) return true;
    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) return true;
    final epg = LiveEpgController.instance;
    if (epg.isLoadingFor(id)) return false;
    return epg.lookupListings(id).isEmpty && epg.lookupDisplay(id) == null;
  }

  bool _rightPanelSlotEnabled(int slot) {
    switch (slot) {
      case 0:
      case 1:
      case 4:
        return true;
      case 2:
        return _catchUpAvailableForCurrentChannel;
      case 3:
        return _rightPanelEpgEnabled;
      case 5:
        return widget.isLive && !_inMultiview && isNativePlayerSupported;
      default:
        return false;
    }
  }

  int _firstEnabledRightPanelSlot() {
    for (var i = 0; i <= _kRightPanelLastIndex; i++) {
      if (_rightPanelSlotEnabled(i)) return i;
    }
    return 0;
  }

  int _stepRightPanelSlot(int from, int delta) {
    var i = from.clamp(0, _kRightPanelLastIndex);
    for (var guard = 0; guard < 8; guard++) {
      final next = (i + delta).clamp(0, _kRightPanelLastIndex);
      if (next == i) return i;
      i = next;
      if (_rightPanelSlotEnabled(i)) return i;
    }
    return from;
  }

  void _resetLiveVideoQualityState() {
    _liveVideoQualityCapPx = null;
    _liveQualityCycleIndex = 0;
    _liveVideoVariantHeights = const [];
    _lfPoolVideoHeight = null;
    _lastLfPoolMetricsPoll = null;
  }

  Future<void> _clearNativeVideoQualityCaps() async {
    try {
      await _service.setLiveVideoMaxHeight(0);
    } catch (_) {}
    if (!PlayerPool.supported) return;
    for (var s = 0; s < PlayerPool.maxSlots; s++) {
      try {
        await PlayerPool.setUserQualityMaxHeight(s, 0);
      } catch (_) {}
    }
  }

  Future<void> _refreshLiveVideoVariantHeights() async {
    if (!widget.isLive || !isNativePlayerSupported) return;
    try {
      if (_lfActive) {
        final list =
            await PlayerPool.getVideoVariantHeights(_lfVisibleSlot);
        if (!mounted) return;
        setState(() => _liveVideoVariantHeights = list);
      } else {
        final snap = await _service.getTracksSnapshot();
        if (!mounted) return;
        setState(() => _liveVideoVariantHeights = snap.videoHeights);
      }
    } catch (_) {}
  }

  Future<void> _refreshLfPoolVideoHeight() async {
    if (!_lfActive || !PlayerPool.supported) return;
    try {
      final m = await PlayerPool.getPlaybackMetrics(_lfVisibleSlot);
      if (!mounted) return;
      final h = m.height;
      setState(() => _lfPoolVideoHeight = h > 0 ? h : null);
    } catch (_) {}
  }

  List<int?> _liveQualityCapSequence() {
    final v = _liveVideoVariantHeights;
    final unique = v.where((h) => h > 0).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (unique.length <= 1) {
      return [null, 720, 480];
    }
    final maxH = unique.first;
    final caps = <int?>[null];
    for (final h in unique) {
      if (h < maxH) caps.add(h);
    }
    return caps;
  }

  String _liveQualityBadgeLabel() {
    final cap = _liveVideoQualityCapPx;
    if (cap != null && cap > 0) {
      return _shortVideoHeightLabel(cap);
    }
    final h = _lfActive ? (_lfPoolVideoHeight ?? _videoHeight) : _videoHeight;
    if (h == null || h <= 0) return 'AUTO';
    return _shortVideoHeightLabel(h);
  }

  String _shortVideoHeightLabel(int h) {
    if (h >= 2160) return '4K';
    if (h >= 1440) return '1440';
    if (h >= 1080) return '1080';
    if (h >= 720) return '720';
    if (h >= 540) return '540';
    if (h >= 480) return '480';
    return '${h}p';
  }

  Future<void> _applyLiveVideoQualityNative() async {
    final cap = _liveVideoQualityCapPx ?? 0;
    try {
      if (_lfActive) {
        final vis = _lfVisibleSlot;
        final idle = _lfVisibleSlot == 0 ? 1 : 0;
        await PlayerPool.setUserQualityMaxHeight(vis, cap);
        await PlayerPool.setUserQualityMaxHeight(idle, 0);
      } else {
        await _service.setLiveVideoMaxHeight(cap);
      }
    } catch (_) {}
    if (_lfActive) {
      await _refreshLfPoolVideoHeight();
    }
  }

  Future<void> _cycleLiveVideoQuality() async {
    if (!widget.isLive || _inMultiview || !isNativePlayerSupported) return;
    await _refreshLiveVideoVariantHeights();
    if (!mounted) return;
    final caps = _liveQualityCapSequence();
    if (caps.isEmpty) return;
    final nextIdx = (_liveQualityCycleIndex + 1) % caps.length;
    final next = caps[nextIdx];
    setState(() {
      _liveQualityCycleIndex = nextIdx;
      _liveVideoQualityCapPx = next;
    });
    await _applyLiveVideoQualityNative();
    if (!mounted) return;
    unawaited(_refreshLiveVideoVariantHeights());
  }

  void _openCatchUpFromPlayer() {
    final id = _currentLiveChannelId;
    if (id == null || id.isEmpty) return;
    if (!recordingCatchUpAvailableForChannelId(id)) return;
    setState(() => _recordingCatchupOverlayOpen = true);
    unawaited(
      openRecordingCatchupOverlay(context, channelId: id).whenComplete(() {
        if (mounted) {
          setState(() {
            _recordingCatchupOverlayOpen = false;
            _controlsVisible = true;
          });
          _scheduleHideControls();
        }
      }),
    );
  }

  /// Same lifecycle as [_openCatchUpFromPlayer]: [unawaited] + [whenComplete] — no
  /// [await], so Back handling and overlay pop stay aligned with catch-up (no stray
  /// navigation to the grid).
  void _openEpgFromPanel() {
    if (!mounted || _released || !widget.isLive) return;
    final id = _effectiveEpgChannelId;
    if (id == null || id.isEmpty || !_rightPanelEpgEnabled) return;
    setState(() {
      _rightPanelVisible = false;
      _liveEpgOverlayOpen = true;
    });
    final line = widget.liveLineup;
    final iconUrl = line != null && line.isNotEmpty
        ? line[_liveIndex.clamp(0, line.length - 1)].iconUrl
        : null;
    final accent = context.teamPalette.accent;
    unawaited(
      openPlayerLiveEpgOverlay(
        context,
        streamId: id,
        epgChannelId: _effectiveEpgXmltvId,
        channelTitle: _displayTitle,
        channelIconUrl: iconUrl,
        playlistId: libraryController.activePlaylistId,
        accent: accent,
      ).whenComplete(() {
        if (mounted) {
          setState(() {
            _liveEpgOverlayOpen = false;
            _controlsVisible = true;
          });
          _scheduleHideControls();
          _requestPlayerRootFocus();
        }
      }),
    );
  }

  Widget _buildRightOptionsPanel(Color accent) {
    final catchUpOk = _catchUpAvailableForCurrentChannel;
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([
        LiveEpgController.instance,
        libraryController,
      ]),
      builder: (context, _) {
        final epgOk = _rightPanelEpgEnabled;
        final epgSlash = _rightPanelEpgNoGuideSlash;
        return AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: _rightPanelVisible ? Offset.zero : const Offset(1, 0),
          child: Container(
            width: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.88),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
              border: Border(
                left: BorderSide(
                  color: accent.withOpacity(0.4),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RightPanelItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  accent: accent,
                  focused: _rightPanelFocusIndex == 0,
                  enabled: true,
                  onActivate: () => unawaited(_openSettingsOverlayFromPanel()),
                ),
                _RightPanelItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Multi',
                  accent: accent,
                  focused: _rightPanelFocusIndex == 1,
                  enabled: true,
                  onActivate: _enterMultiview,
                ),
                _RightPanelItem(
                  icon: catchUpOk ? Icons.history_rounded : Icons.block_rounded,
                  label: catchUpOk ? 'Catch-up' : 'No catch-up',
                  accent: accent,
                  focused: _rightPanelFocusIndex == 2,
                  enabled: catchUpOk,
                  onActivate:
                      catchUpOk ? _openCatchUpFromPlayer : () {},
                ),
                _RightPanelItem(
                  icon: Icons.view_day_rounded,
                  label: l10n.playerEpgPanelLabel,
                  accent: accent,
                  focused: _rightPanelFocusIndex == 3,
                  enabled: epgOk,
                  showNoGuideSlash: !epgOk && epgSlash,
                  onActivate: epgOk
                      ? () => _openEpgFromPanel()
                      : () {},
                ),
                _RightPanelItem(
                  icon: Icons.lock_outline_rounded,
                  label: l10n.parentalPlayerParental,
                  accent: accent,
                  focused: _rightPanelFocusIndex == 4,
                  enabled: true,
                  onActivate: () => unawaited(_openParentalFromPanel()),
                ),
                _RightPanelItem(
                  icon: Icons.high_quality_rounded,
                  label: l10n.playerRightPanelQuality,
                  badge: _rightPanelSlotEnabled(5)
                      ? _liveQualityBadgeLabel()
                      : null,
                  accent: accent,
                  focused: _rightPanelFocusIndex == 5,
                  enabled: _rightPanelSlotEnabled(5),
                  onActivate: _rightPanelSlotEnabled(5)
                      ? () => unawaited(_cycleLiveVideoQuality())
                      : () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Video surface (normal non-multiview) ──

  Widget _buildVideoSurface(Color accentColor) {
    // Desktop: use media_kit's Video widget directly
    if (_isDesktopPlayer) {
      final desktopService = _service as DesktopPlayerService;
      return SizedBox.expand(
        child: mkv.Video(
          controller: desktopService.videoController,
          fill: Colors.black,
          // Hide media_kit default overlay (seek bar, play, volume, etc.); TV chrome is
          // built in this screen.
          controls: mkv.NoVideoControls,
          // Subtitles are drawn only in [_buildVodSubtitleOverlay] (parity with Android).
          subtitleViewConfiguration: const mkv.SubtitleViewConfiguration(
            visible: false,
          ),
        ),
      );
    }

    final id = _textureId;
    if (id == null) {
      return Center(
        child: CircularProgressIndicator(color: accentColor),
      );
    }
    if (widget.isLive) {
      if (_inMultiview) {
        return _buildMultiviewLayout(accentColor);
      }
      final liveTexId = _lfActive ? _lfVisibleTexId : id;
      if (liveTexId < 0) {
        return Center(child: CircularProgressIndicator(color: accentColor));
      }
      // Streamer 4K single-view live: route through a native SurfaceView so
      // SurfaceFlinger colour-converts the MediaTek vendor-private YUV that some
      // channels (HEVC / 10-bit / HDR / High-profile H.264) produce — Flutter's
      // Texture pipeline would sample those buffers as solid green. Multiview
      // keeps the Texture path for simplicity (multiple tiles, one SurfaceView is
      // not enough), and every other Android device is untouched.
      if (DeviceMemoryChannel.isGoogleTvStreamer) {
        return const SizedBox.expand(child: VodSurfaceViewAndroid());
      }
      return SizedBox.expand(
        child: Texture(filterQuality: FilterQuality.medium, textureId: liveTexId),
      );
    }
    // Streamer 4K VOD path: render into a native SurfaceView so that
    // SurfaceFlinger handles colour conversion (the Flutter texture path would
    // sample the MediaTek vendor-private YUV format as solid green). Every other
    // device stays on the original Flutter Texture widget below.
    final Widget videoSurface = (Platform.isAndroid &&
            DeviceMemoryChannel.isGoogleTvStreamer)
        ? const VodSurfaceViewAndroid()
        : Texture(filterQuality: FilterQuality.medium, textureId: id);
    final vw = _videoWidth;
    final vh = _videoHeight;
    if (vw == null || vh == null || vw <= 0 || vh <= 0) {
      return SizedBox.expand(child: videoSurface);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final s = _vodContainVideoSize(
          maxW,
          maxH,
          vw.toDouble(),
          vh.toDouble(),
        );
        return Center(
          child: SizedBox(
            width: s.width,
            height: s.height,
            child: videoSurface,
          ),
        );
      },
    );
  }

  // ── Multiview context menu widget ──

  Widget _buildMvContextMenu(
    ThemeData theme,
    Color accent,
    AppLocalizations l10n,
  ) {
    final items = _mvBuildMenuItems();
    final clampedIdx = _mvMenuFocusIndex.clamp(0, items.length - 1);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.4),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.mvMenuTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: i == clampedIdx
                                    ? accent
                                    : Colors.white.withValues(alpha: 0.18),
                                width: i == clampedIdx ? 2.2 : 1,
                              ),
                            ),
                            child: Text(
                              items[i].label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.94),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          l10n.mvMenuHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? get _vodSubtitleLineNow {
    if (widget.isLive || _vodSubtitleLines.isEmpty) return null;
    // Android/TV: only overlay external SRT from our pipeline (cues).
    // Desktop (media_kit): same Flutter overlay; cues come from [stream.subtitle].
    if (!_isDesktopPlayer && !_vodHasExternalSubtitle) return null;
    return _vodSubtitleLines.join('\n');
  }

  /// Active cue text, or placeholder while the look panel is open for live preview.
  String? get _vodSubtitlePreviewText {
    if (widget.isLive) return null;
    final cue = _vodSubtitleLineNow;
    if (cue != null && cue.isNotEmpty) return cue;
    if (_vodSubtitleStylePanelOpen) return 'Subtitle preview';
    return null;
  }

  Widget _buildVodSubtitleOverlay() {
    return ListenableBuilder(
      listenable: SubtitleAppearanceStore.instance,
      builder: (context, _) {
        final store = SubtitleAppearanceStore.instance;
        if (!store.loaded) return const SizedBox.shrink();
        final text = _vodSubtitlePreviewText;
        if (text == null) return const SizedBox.shrink();
        if (!store.subtitlesEnabled && !_vodSubtitleStylePanelOpen) {
          return const SizedBox.shrink();
        }
        final mq = MediaQuery.sizeOf(context);
        final bottomInset = _vodSubtitleStylePanelOpen
            ? _kVodSubtitleBottomInsetStylePanelOpen
            : _kVodSubtitleBottomInsetNormal;
        final maxCaptionW = (mq.width - 80).clamp(120.0, mq.width);
        final panelDyComp = _vodSubtitleStylePanelOpen
            ? -_kVodSubtitleBottomInsetDelta
            : 0.0;
        final baseOff = _effectiveVodSubtitleDisplayOffset(store);
        final captionOffset = Offset(
          baseOff.dx,
          baseOff.dy + panelDyComp,
        );
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: captionOffset,
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCaptionW),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: store.backgroundColor
                          .withValues(alpha: store.backgroundOpacity),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: store.textColor,
                        fontSize: store.fontSizeSp,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withValues(alpha: 0.75),
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chrome = context.teamPalette;

    if (_initError != null) {
      return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_exit());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: _onRootKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _initError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TvFocusable(
                    autofocus: true,
                    onActivate: () => unawaited(_exit()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.commonBack,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    }

    // Android: show VOD chrome (incl. offline download) even if duration not reported yet.
    final showSeek = !widget.isLive &&
        (_durationMs > 0 || (!kIsWeb && Platform.isAndroid));
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // ── Pushed overlay routes (peel one layer) ──
        if (_recordingCatchupOverlayOpen) {
          Navigator.of(context, rootNavigator: true).pop();
          return;
        }
        if (widget.isLive && _liveEpgOverlayOpen) {
          Navigator.of(context, rootNavigator: true).pop();
          return;
        }
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) {
          Navigator.of(context).pop();
          return;
        }

        // ── Live: peel in-player layers ──
        if (widget.isLive && _mvMenuVisible) {
          setState(() => _mvMenuVisible = false);
          return;
        }
        if (widget.isLive && _inMultiview) {
          unawaited(_mvExitMultiview());
          return;
        }
        if (widget.isLive && _rightPanelVisible) {
          setState(() => _rightPanelVisible = false);
          return;
        }
        // Navigation policy §5: chrome visible → dismiss immediately, stay on live.
        if (widget.isLive &&
            (_controlsVisible ||
                _liveOverlayFadingOut ||
                (_isDesktopLiveUi &&
                    (_liveDesktopEpgOpen ||
                        _liveDesktopBottomHover ||
                        _liveDesktopTopHover)))) {
          _hideControlsOverlay(immediate: true);
          return;
        }
        // §5.2: clean live → exit to grid.
        if (widget.isLive) {
          unawaited(_exit());
          return;
        }

        // ── VOD: peel in-player layers ──
        if (_vodSubtitleStylePanelOpen) {
          _closeVodSubtitleStylePanelAndRestoreJumpFocus();
          return;
        }
        if (_vodSubtitlePickerOpen) {
          _closeVodSubtitlePicker();
          return;
        }
        if (_vodAudioOffsetPopupOpen) {
          _closeVodAudioOffsetPopup();
          return;
        }
        if (_vodSubtitleDelayPopupOpen) {
          _closeVodSubtitleDelayPopup();
          return;
        }
        if (_vodSpeedPickerOpen) {
          setState(() => _vodSpeedPickerOpen = false);
          _scheduleHideControls();
          return;
        }
        if (_vodWantsOpaqueOverlay) {
          _hideControlsOverlay();
          _scheduleHideControls();
          return;
        }
        // §7.4: clean movie → exit to details.
        unawaited(_exit());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _playerRootFocusNode,
          autofocus: true,
          onKeyEvent: _onRootKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              return MouseRegion(
                onHover: (event) {
                  if (Platform.isAndroid) return;
                  if (widget.isLive && _isDesktopLiveUi) {
                    final y = event.localPosition.dy;
                    const topFrac = 0.20;
                    const bottomFrac = 0.20;
                    final inTop = y < h * topFrac;
                    final inBottom = y > h * (1.0 - bottomFrac);
                    setState(() {
                      if (inTop) {
                        _liveDesktopTopHover = true;
                        _liveDesktopBottomHover = false;
                      } else if (inBottom) {
                        _liveDesktopBottomHover = true;
                        _liveDesktopTopHover = false;
                      } else {
                        _liveDesktopTopHover = false;
                        _liveDesktopBottomHover = false;
                      }
                    });
                    _scheduleHideControls();
                    return;
                  }
                  if (widget.isLive) {
                    _pokeControls();
                  } else {
                    _flashVodTimeline();
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, lc) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _onVideoSurfaceTap,
                              child: ColoredBox(
                                color: Colors.black,
                                child: _buildVideoSurface(chrome.accent),
                              ),
                            ),
                            if (widget.isLive &&
                                (Platform.isAndroid || Platform.isIOS))
                              Positioned(
                                top: 0,
                                bottom: 0,
                                right: 0,
                                width: math.max(36.0, lc.maxWidth * 0.12),
                                child: Listener(
                                  behavior: HitTestBehavior.translucent,
                                  onPointerDown: _onLiveRightEdgePointerDown,
                                  onPointerUp: _onLiveRightEdgePointerUp,
                                  onPointerCancel: (e) {
                                    if (e.pointer ==
                                        _liveRightEdgeSwipePointer) {
                                      _liveRightEdgeSwipeReset();
                                    }
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (!widget.isLive) _buildVodSubtitleOverlay(),
            if (!widget.isLive &&
                showSeek &&
                _vodSubtitleStylePanelOpen)
              Positioned.fill(
                child: VodSubtitleStylePanel(
                  accent: chrome.accent,
                  onClose: _closeVodSubtitleStylePanelAndRestoreJumpFocus,
                  onPositionDelta: _nudgeVodSubtitlePosition,
                  onResetLayoutExtras: widget.resumeContentId != null
                      ? () async {
                          await VodSubtitlePositionStore.clear(
                            widget.resumeContentId!,
                          );
                          if (mounted) {
                            setState(() => _vodPerMovieSubtitlePos = null);
                          }
                        }
                      : null,
                ),
              ),
            if (_textureId != null &&
                (widget.isLive
                    ? _showLiveSpinner
                    : (_buffering && !_vodSeekSpinnerGrace)))
              const _BufferingSpinnerOverlay(),
            if (_retryBanner)
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        'Playback failed. Retrying…',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_fatalError != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.65),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fatalError!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TvFocusable(
                            autofocus: true,
                            onActivate: () => unawaited(_exit()),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Text(
                                'Back',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_fatalError == null)
              Positioned.fill(
                // VOD: when the dock/banner is hidden, [_playerOverlayOpacity] is 0 but this
                // layer still covered the video — taps never reached [GestureDetector] below, so
                // no chrome appeared (Windows/mouse). Pass events through until chrome is shown.
                child: IgnorePointer(
                  ignoring: !widget.isLive &&
                      !_vodWantsOpaqueOverlay &&
                      !_vodSpeedPickerOpen &&
                      !_vodAudioOffsetPopupOpen &&
                      !_vodSubtitleDelayPopupOpen,
                  child: AnimatedOpacity(
                    opacity: _playerOverlayOpacity,
                    duration: PlayerTvOverlayTheme.fadeDuration,
                    curve: Curves.easeOutCubic,
                    child: ExcludeFocus(
                      excluding: !_overlayInteractive,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                        if (kDebugMode)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: IgnorePointer(
                              child: Text(
                                'overlay v$kPlayerTvOverlayBuild',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (widget.isLive)
                          Positioned(
                            left: 8,
                            right: 8,
                            top: 0,
                            child: IgnorePointer(
                              ignoring: _liveTopChromeOpacity == 0.0,
                              child: AnimatedOpacity(
                                opacity: _liveTopChromeOpacity,
                                duration: PlayerTvOverlayTheme.fadeDuration,
                                curve: Curves.easeOutCubic,
                                child: ExcludeFocus(
                                  excluding: _inMultiview,
                                  child: SafeArea(
                                    bottom: false,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.82),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 5,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TvFocusable(
                                              parallaxSlide: 0,
                                              focusScale: 1.02,
                                              onActivate: () =>
                                                  unawaited(_exit()),
                                              focusPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.arrow_back_rounded,
                                                    color: Colors.white
                                                        .withOpacity(0.92),
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _isDesktopLiveUi
                                                        ? 'Exit'
                                                        : 'Back',
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white
                                                          .withOpacity(0.94),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  _displayTitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize:
                                                        PlayerTvOverlayTheme
                                                            .headerTitleSize,
                                                    color: Colors.white
                                                        .withOpacity(0.96),
                                                    shadows: const [
                                                      Shadow(
                                                        blurRadius: 8,
                                                        color: Colors.black87,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (!Platform.isAndroid)
                                              TvFocusable(
                                                parallaxSlide: 0,
                                                focusScale: 1.05,
                                                onActivate: () => unawaited(
                                                    _togglePlayPause()),
                                                focusPadding:
                                                    const EdgeInsets.all(4),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Icon(
                                                    _playing
                                                        ? Icons.pause_rounded
                                                        : Icons
                                                            .play_arrow_rounded,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 6,
                                                top: 2,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: chrome.accent
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: chrome.accent
                                                        .withOpacity(0.4),
                                                  ),
                                                ),
                                                child: Text(
                                                  'LIVE',
                                                  style: theme
                                                      .textTheme.labelMedium
                                                      ?.copyWith(
                                                    color: chrome.accent,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.1,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!widget.isLive &&
                            showSeek &&
                            _vodTimelineVisible &&
                            !_vodSubtitleStylePanelOpen)
                          Positioned(
                            left: 8,
                            right: 8,
                            top: 0,
                            child: SafeArea(
                              bottom: false,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TvFocusable(
                                        parallaxSlide: 0,
                                        focusScale: 1.02,
                                        onActivate: () => unawaited(_exit()),
                                        focusPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.arrow_back_rounded,
                                              color: Colors.white
                                                  .withOpacity(0.92),
                                              size: 22,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              !kIsWeb &&
                                                      (Platform.isWindows ||
                                                          Platform.isMacOS)
                                                  ? 'Exit'
                                                  : 'Back',
                                              style: theme
                                                  .textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white
                                                    .withOpacity(0.94),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _displayTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme
                                                .textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: PlayerTvOverlayTheme
                                                  .headerTitleSize,
                                              color: Colors.white
                                                  .withOpacity(0.96),
                                              shadows: const [
                                                Shadow(
                                                  blurRadius: 8,
                                                  color: Colors.black87,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!Platform.isAndroid)
                                        TvFocusable(
                                          parallaxSlide: 0,
                                          focusScale: 1.05,
                                          onActivate: () =>
                                              unawaited(_togglePlayPause()),
                                          focusPadding:
                                              const EdgeInsets.all(4),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _playing
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.white
                                                  .withOpacity(0.9),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (widget.isLive && !_inMultiview)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SafeArea(
                              top: false,
                              left: false,
                              right: false,
                              child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                IgnorePointer(
                                  ignoring: _liveBottomEpgOpacity == 0,
                                  child: AnimatedOpacity(
                                    opacity: _liveBottomEpgOpacity,
                                    duration: PlayerTvOverlayTheme.fadeDuration,
                                    curve: Curves.easeOutCubic,
                                    child: PlayerTvBottomSheetChrome(
                                      shrinkWrapWithMaxHeight:
                                          _isDesktopLiveUi,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                        if (_effectiveEpgChannelId != null)
                                          ListenableBuilder(
                                            listenable: Listenable.merge([
                                              LiveEpgController.instance,
                                              playlistEpgTimezoneStore,
                                            ]),
                                            builder: (context, _) {
                                              final id =
                                                  _effectiveEpgChannelId!;
                                              final epg =
                                                  LiveEpgController.instance;
                                              final listings =
                                                  epg.lookupListings(id);
                                              final anchor =
                                                  computeLiveEpgAnchorIndex(
                                                listings,
                                              );
                                              final center =
                                                  _liveEpgWindowCenter >= 0
                                                      ? _liveEpgWindowCenter
                                                          .clamp(
                                                          0,
                                                          listings.isEmpty
                                                              ? 0
                                                              : listings
                                                                      .length -
                                                                  1,
                                                        )
                                                      : anchor;
                                              final line = widget.liveLineup;
                                              final iconUrl = line !=
                                                          null &&
                                                      line.isNotEmpty
                                                  ? line[_liveIndex
                                                          .clamp(
                                                          0,
                                                          line.length -
                                                              1)]
                                                      .iconUrl
                                                  : null;
                                              return LiveTvPlayerBottomBar(
                                                channelTitle: _displayTitle,
                                                listings: listings,
                                                centerIndex: center,
                                                accent: chrome.accent,
                                                isLoading:
                                                    epg.isLoadingFor(id),
                                                channelIconUrl: iconUrl,
                                                playlistId: libraryController
                                                    .activePlaylistId,
                                                onEpgEarlier:
                                                    _isDesktopLiveUi
                                                        ? () =>
                                                            _nudgeLiveEpgWindow(
                                                              -1,
                                                            )
                                                        : null,
                                                onEpgLater:
                                                    _isDesktopLiveUi
                                                        ? () =>
                                                            _nudgeLiveEpgWindow(
                                                              1,
                                                            )
                                                        : null,
                                              );
                                            },
                                          )
                                        else
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Text(
                                              _displayTitle,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: theme
                                                  .textTheme.titleMedium
                                                  ?.copyWith(
                                                color: Colors.white
                                                    .withOpacity(0.92),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        if (_isDesktopLiveUi &&
                                            _effectiveEpgChannelId != null)
                                          ListenableBuilder(
                                            listenable: Listenable.merge([
                                              LiveEpgController.instance,
                                              libraryController,
                                              playlistEpgTimezoneStore,
                                            ]),
                                            builder: (context, _) {
                                              final id =
                                                  _effectiveEpgChannelId!;
                                              final epg =
                                                  LiveEpgController.instance;
                                              final listings =
                                                  epg.lookupListings(id);
                                              final anchor =
                                                  computeLiveEpgAnchorIndex(
                                                listings,
                                              );
                                              final center =
                                                  _liveEpgWindowCenter >= 0
                                                      ? _liveEpgWindowCenter
                                                          .clamp(
                                                          0,
                                                          listings.isEmpty
                                                              ? 0
                                                              : listings
                                                                      .length -
                                                                  1,
                                                        )
                                                      : anchor;
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  left: 8,
                                                  right: 8,
                                                  bottom: 10,
                                                ),
                                                child:
                                                    _WindowsLiveDesktopEpgTimelineStrip(
                                                  listings: listings,
                                                  centerIndex: center,
                                                  accent: chrome.accent,
                                                  playlistId: libraryController
                                                      .activePlaylistId,
                                                  loading:
                                                      epg.isLoadingFor(id),
                                                ),
                                              );
                                            },
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: _isDesktopLiveUi
                                              ? Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      flex: 1,
                                                      child: Row(
                                                        children: [
                                                          _WindowsLiveDesktopToolbarExit(
                                                            accent: chrome.accent,
                                                            onPressed: () =>
                                                                unawaited(
                                                                    _exit()),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          _WindowsLiveDesktopToolbarIcon(
                                                            accent: chrome.accent,
                                                            icon: Icons
                                                                .navigate_before_rounded,
                                                            tooltip:
                                                                'Previous channel',
                                                            enabled:
                                                                _liveLineSwitching,
                                                            onPressed: () {
                                                              _pokeControls();
                                                              _switchLiveRelative(
                                                                  -1);
                                                            },
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          _WindowsLiveDesktopToolbarIcon(
                                                            accent: chrome.accent,
                                                            icon: Icons
                                                                .navigate_next_rounded,
                                                            tooltip:
                                                                'Next channel',
                                                            enabled:
                                                                _liveLineSwitching,
                                                            onPressed: () {
                                                              _pokeControls();
                                                              _switchLiveRelative(
                                                                  1);
                                                            },
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          _WindowsLiveDesktopToolbarIcon(
                                                            accent: chrome.accent,
                                                            icon: _windowsLiveVolume <
                                                                    0.001
                                                                ? Icons
                                                                    .volume_off_rounded
                                                                : Icons
                                                                    .volume_mute_rounded,
                                                            tooltip: 'Mute',
                                                            onPressed: () =>
                                                                unawaited(
                                                                    _toggleWindowsLiveMute()),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          KeyedSubtree(
                                                            key:
                                                                _windowsLiveSpeakerButtonKey,
                                                            child:
                                                                _WindowsLiveDesktopToolbarIcon(
                                                              accent:
                                                                  chrome.accent,
                                                              icon: Icons
                                                                  .volume_up_rounded,
                                                              tooltip:
                                                                  'Volume',
                                                              onPressed:
                                                                  _toggleWindowsLiveVolumeOverlay,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          Expanded(
                                                            child: Align(
                                                              alignment:
                                                                  Alignment
                                                                      .centerLeft,
                                                              child:
                                                                  PlayerTvStreamMetaChips(
                                                                videoWidth:
                                                                    _videoWidth,
                                                                videoHeight:
                                                                    _videoHeight,
                                                                bitrate:
                                                                    _bitrate,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                      ),
                                                      child:
                                                          _WindowsLiveDesktopCircularPlay(
                                                        playing: _playing,
                                                        accent: chrome.accent,
                                                        onPressed: () =>
                                                            unawaited(
                                                                _togglePlayPause()),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          ListenableBuilder(
                                                            listenable:
                                                                Listenable.merge([
                                                              LiveEpgController
                                                                  .instance,
                                                              libraryController,
                                                            ]),
                                                            builder: (context,
                                                                _) {
                                                              final epgOk =
                                                                  _rightPanelEpgEnabled;
                                                              final epgSlash =
                                                                  _rightPanelEpgNoGuideSlash;
                                                              final catchUpOk =
                                                                  _catchUpAvailableForCurrentChannel;
                                                              return Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  _WindowsLiveDesktopCatchUpButton(
                                                                    accent: chrome
                                                                        .accent,
                                                                    enabled:
                                                                        catchUpOk,
                                                                    icon: catchUpOk
                                                                        ? Icons
                                                                            .history_rounded
                                                                        : Icons
                                                                            .block_rounded,
                                                                    label: catchUpOk
                                                                        ? 'Catch-up'
                                                                        : 'No catch-up',
                                                                    onPressed: catchUpOk
                                                                        ? _openCatchUpFromPlayer
                                                                        : null,
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 8),
                                                                  _WindowsLiveDesktopEpgButton(
                                                                    accent: chrome
                                                                        .accent,
                                                                    enabled:
                                                                        epgOk,
                                                                    showNoGuideSlash:
                                                                        !epgOk &&
                                                                            epgSlash,
                                                                    label: l10n
                                                                        .playerEpgPanelLabel,
                                                                    onPressed: epgOk
                                                                        ? _openEpgFromPanel
                                                                        : null,
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          ),
                                                          PlayerTvLiveHints(
                                                            showChannelSwitch:
                                                                _liveLineSwitching,
                                                            showGuideHints:
                                                                true,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          PlayerTvStreamMetaChips(
                                                        videoWidth: _videoWidth,
                                                        videoHeight:
                                                            _videoHeight,
                                                        bitrate: _bitrate,
                                                      ),
                                                    ),
                                                    PlayerTvLiveHints(
                                                      showChannelSwitch:
                                                          _liveLineSwitching,
                                                      showGuideHints: true,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ],
                            ),
                          ),
                          ),
                        // ── Right-side options panel ──
                        if (widget.isLive && !_inMultiview && _rightPanelVisible)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: _buildRightOptionsPanel(chrome.accent),
                          ),
                        if (!widget.isLive &&
                            showSeek &&
                            _vodInfoBannerVisible)
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 0,
                            child: SafeArea(
                              bottom: false,
                              child: PlayerTvVodInfoBanner(
                                title: _displayTitle,
                                description: widget.contentDescription,
                                videoWidth: _videoWidth,
                                videoHeight: _videoHeight,
                                bitrate: _bitrate,
                              ),
                            ),
                          ),
                        if (!widget.isLive &&
                            showSeek &&
                            _vodTimelineVisible &&
                            !_vodSubtitleStylePanelOpen &&
                            !_vodSubtitleDelayPopupOpen)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: PlayerTvVodBottomChrome(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  PlayerTvVodTimelineStrip(
                                    positionMs: _isScrubbing
                                        ? _scrubPositionMs
                                        : _positionMs,
                                    durationMs: _durationMs,
                                    videoWidth: _videoWidth,
                                    videoHeight: _videoHeight,
                                    onSeek: (targetMs) {
                                      if (!_vodSeekable || _released) return;
                                      final clamped = targetMs.clamp(0, _durationMs);
                                      unawaited(_service.seekTo(Duration(milliseconds: clamped)));
                                      _beginVodSeekGrace();
                                      setState(() => _positionMs = clamped);
                                      _flashVodTimeline();
                                    },
                                  ),
                                  PlayerTvVodJumpStrip(
                                    stripFocused: _vodJumpStripFocused,
                                    focusIndex: _vodJumpFocusIndex,
                                    playing: _playing,
                                    audioDelayMs: _vodAudioDelayMs,
                                    subtitleDelayMs: _vodSubtitleDelayMs,
                                    playbackSpeed: _vodPlaybackSpeed,
                                    ccActive: _vodHasExternalSubtitle,
                                    showDownloadButton: !kIsWeb &&
                                        (Platform.isWindows ||
                                            Platform.isAndroid),
                                    onJumpSeek: (deltaMs) {
                                      _seekBy(deltaMs);
                                    },
                                    onTogglePlayPause: () {
                                      unawaited(_togglePlayPause());
                                    },
                                    onCcTap: () {
                                      _activateVodJumpButton(0);
                                    },
                                    onStyleTap: () {
                                      _activateVodJumpButton(1);
                                    },
                                    onSubtitleDelayTap: () {
                                      _activateVodJumpButton(2);
                                    },
                                    onAudioTap: () {
                                      _activateVodJumpButton(12);
                                    },
                                    onSpeedTap: () {
                                      _activateVodJumpButton(13);
                                    },
                                    onSettingsTap: () {
                                      _activateVodJumpButton(14);
                                    },
                                    onDownloadTap: !kIsWeb &&
                                            (Platform.isWindows ||
                                                Platform.isAndroid)
                                        ? () => _activateVodJumpButton(15)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!widget.isLive &&
                            showSeek &&
                            _vodAudioOffsetPopupOpen)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 168,
                            child: SafeArea(
                              top: false,
                              child: Center(
                                child: PlayerTvVodAudioOffsetPopup(
                                  delayMs: _vodAudioDelayMs,
                                  accent: chrome.accent,
                                ),
                              ),
                            ),
                          ),
                        if (!widget.isLive && _vodSubtitleDelayPopupOpen)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 40,
                            child: SafeArea(
                              top: false,
                              child: Center(
                                child: PlayerTvVodSubtitleDelayPopup(
                                  delayMs: _vodSubtitleDelayMs,
                                  accent: chrome.accent,
                                ),
                              ),
                            ),
                          ),
                        if (!widget.isLive &&
                            showSeek &&
                            _vodSpeedPickerOpen)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 120,
                            child: SafeArea(
                              top: false,
                              child: Center(
                                child: PlayerTvVodSpeedPicker(
                                  focusIndex: _vodSpeedPickerFocusIndex,
                                  accent: chrome.accent,
                                ),
                              ),
                            ),
                          ),
                        if (!widget.isLive &&
                            showSeek &&
                            _vodSubtitlePickerOpen)
                          Positioned.fill(
                            child: VodSubtitlePickerPanel(
                              loading: _vodSubLoading,
                              errorMessage: _vodSubError,
                              groups: _vodSubGroups,
                              searchQueryController: _vodSubSearchController,
                              searchFocusNode: _vodSubSearchFocusNode,
                              searchFieldFocused: _vodSubSearchFocused &&
                                  _vodSubSearchHintDpadIndex < 0,
                              searchHintDpadIndex: _vodSubSearchHintDpadIndex,
                              searchHints: _vodSubSearchHints,
                              searchHintsLoading: _vodSubSearchHintsLoading,
                              onSearchSubmitted: _onVodSubSearchSubmitted,
                              onSearchHintSelected: _onVodSubSearchHintPicked,
                              langIndex: _vodSubLangIndex,
                              fileIndex: _vodSubFileIndex,
                              focusColumn: _vodSubFocusColumn,
                              accent: chrome.accent,
                              clearEnabled: _vodHasExternalSubtitle,
                              title: l10n.subtitleVodPickerTitle,
                              hintLoading: l10n.subtitleVodLoading,
                              hintEmpty: l10n.subtitleVodEmpty,
                              hintPickLanguage: l10n.subtitleVodPickLanguage,
                              labelLanguages: l10n.subtitleVodLanguages,
                              labelFiles: l10n.subtitleVodFiles,
                              actionClear: l10n.subtitleVodClear,
                              labelExit: l10n.subtitleAppearanceExitMenu,
                              labelSelectFooter: l10n.subtitleVodFooterSelect,
                            ),
                          ),
                        if (Platform.isWindows &&
                            !_inMultiview &&
                            _fatalError == null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: SafeArea(
                              bottom: false,
                              child: ListenableBuilder(
                                listenable: WindowsPipController.instance,
                                builder: (context, _) {
                                  final pip =
                                      WindowsPipController.instance.isPipActive;
                                  return Material(
                                    color: Colors.black
                                        .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      onTap: () async {
                                        if (pip) {
                                          await WindowsPipController.instance
                                              .exitPip();
                                        } else {
                                          await WindowsPipController.instance
                                              .enterPip();
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              pip
                                                  ? Icons.close_fullscreen
                                                  : Icons
                                                      .picture_in_picture_alt_outlined,
                                              color: Colors.white
                                                  .withValues(alpha: 0.92),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              pip
                                                  ? 'Normal view'
                                                  : 'Mini player',
                                              style: theme
                                                  .textTheme.labelLarge
                                                  ?.copyWith(
                                                color: Colors.white
                                                    .withValues(alpha: 0.92),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (!widget.isLive &&
                            _vodStuckBufferOfferExit &&
                            _fatalError == null &&
                            _buffering &&
                            _textureId != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 28,
                            child: SafeArea(
                              top: false,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Playback is taking longer than usual.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        onTap: () => unawaited(_exit()),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            l10n.commonBack,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              color: chrome.accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.isLive && _mvMenuVisible)
              _buildMvContextMenu(
                theme,
                chrome.accent,
                AppLocalizations.of(context)!,
              ),
          ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _MvMenuAction {
  addScreen,
  changeChannel,
  enlargeScreen,
  reduceScreen,
  fullScreen,
  removeScreen,
  exitMultiview,
}

class _MvMenuItem {
  final String label;
  final _MvMenuAction action;
  const _MvMenuItem(this.label, this.action);
}

/// Channel card placeholder for tiles without a live decoder.
class _MvTileCard extends StatelessWidget {
  const _MvTileCard({required this.item});

  final LiveLineupItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = item.iconUrl?.trim() ?? '';
    final runes = item.title.trim().runes;
    final ini = runes.isEmpty
        ? '?'
        : String.fromCharCode(runes.first).toUpperCase();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: u.isNotEmpty
                  ? TvCatalogImage(url: u)
                  : ColoredBox(
                      color: Colors.white.withValues(alpha: 0.08),
                      child: Center(
                        child: Text(
                          ini,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the largest axis-aligned rect with aspect [videoW]:[videoH] that fits in the box.
Size _vodContainVideoSize(
  double maxWidth,
  double maxHeight,
  double videoW,
  double videoH,
) {
  if (videoW <= 0 || videoH <= 0 || maxWidth <= 0 || maxHeight <= 0) {
    return Size(maxWidth, maxHeight);
  }
  final ar = videoW / videoH;
  final boxAr = maxWidth / maxHeight;
  if (ar > boxAr) {
    final w = maxWidth;
    return Size(w, w / ar);
  }
  final h = maxHeight;
  return Size(h * ar, h);
}

/// Windows live: fat programme timeline above the icon row — start / end times
/// (playlist EPG timezone) and progress through the focused listing.
class _WindowsLiveDesktopEpgTimelineStrip extends StatefulWidget {
  const _WindowsLiveDesktopEpgTimelineStrip({
    required this.listings,
    required this.centerIndex,
    required this.accent,
    required this.playlistId,
    required this.loading,
  });

  final List<XtreamEpgListing> listings;
  final int centerIndex;
  final Color accent;
  final String? playlistId;
  final bool loading;

  @override
  State<_WindowsLiveDesktopEpgTimelineStrip> createState() =>
      _WindowsLiveDesktopEpgTimelineStripState();
}

class _WindowsLiveDesktopEpgTimelineStripState
    extends State<_WindowsLiveDesktopEpgTimelineStrip> {
  Timer? _tick;

  static const double _trackHeight = 20.8;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: Colors.white.withValues(alpha: 0.92),
      fontWeight: FontWeight.w800,
      fontSize: 14,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (widget.loading && widget.listings.isEmpty) {
      return SizedBox(
        height: _trackHeight + 4,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Loading guide…',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    if (widget.listings.isEmpty) {
      return const SizedBox.shrink();
    }

    final idx = widget.centerIndex.clamp(0, widget.listings.length - 1);
    final listing = widget.listings[idx];
    final (startL, endL) = formatEpgProgramStartEndLabels(
      listing,
      widget.playlistId,
    );
    final p = liveListingProgress01(listing);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              child: Text(
                startL,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: _trackHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: p.clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: _trackHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.accent.withValues(alpha: 0.45),
                                  widget.accent.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 56,
              child: Text(
                endL,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Centered spinner over the video; does not cover the full screen.
class _BufferingSpinnerOverlay extends StatelessWidget {
  const _BufferingSpinnerOverlay();

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
            ),
          ],
        ),
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: p.accent,
            strokeWidth: 3.2,
          ),
        ),
      ),
    );
  }
}

/// Windows live bottom bar: matches top header — back icon + "Exit" label.
class _WindowsLiveDesktopToolbarExit extends StatelessWidget {
  const _WindowsLiveDesktopToolbarExit({
    required this.accent,
    required this.onPressed,
  });

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Exit',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            constraints: const BoxConstraints(minHeight: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: accent.withValues(alpha: 0.38),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 8),
                Text(
                  'Exit',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.94),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Windows live bottom bar: compact icon + tooltip (Mute / Volume / …).
class _WindowsLiveDesktopToolbarIcon extends StatelessWidget {
  const _WindowsLiveDesktopToolbarIcon({
    required this.accent,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.enabled = true,
  });

  final Color accent;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: accent.withValues(alpha: enabled ? 0.38 : 0.16),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white.withValues(alpha: enabled ? 0.85 : 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

/// Windows live: centered circular play / pause.
class _WindowsLiveDesktopCircularPlay extends StatelessWidget {
  const _WindowsLiveDesktopCircularPlay({
    required this.playing,
    required this.accent,
    required this.onPressed,
  });

  final bool playing;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing ? 'Pause' : 'Play',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 30,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live TV fullscreen on Windows: in-player **Catch-up** (same as right panel).
class _WindowsLiveDesktopCatchUpButton extends StatelessWidget {
  const _WindowsLiveDesktopCatchUpButton({
    required this.accent,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color accent;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onPressed != null;
    final color = !enabled
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.white.withValues(alpha: 0.72);
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: canTap
                            ? accent.withValues(alpha: 0.42)
                            : Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 22,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 8.5,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live TV fullscreen on Windows: in-player **EPG** control (same action as side panel).
class _WindowsLiveDesktopEpgButton extends StatelessWidget {
  const _WindowsLiveDesktopEpgButton({
    required this.accent,
    required this.enabled,
    required this.showNoGuideSlash,
    required this.label,
    required this.onPressed,
  });

  final Color accent;
  final bool enabled;
  final bool showNoGuideSlash;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onPressed != null;
    final color = !enabled
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.white.withValues(alpha: 0.72);
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: canTap
                                ? accent.withValues(alpha: 0.42)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.view_day_rounded,
                            size: 22,
                            color: color,
                          ),
                        ),
                      ),
                      if (showNoGuideSlash)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EpgNoGuideSlashPainter(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 8.5,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RightPanelItem extends StatelessWidget {
  const _RightPanelItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.focused,
    this.enabled = true,
    this.showNoGuideSlash = false,
    this.badge,
    required this.onActivate,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool focused;

  /// Optional second line (e.g. live video quality badge).
  final String? badge;

  /// False = no catch-up for this channel; OK does nothing.
  final bool enabled;

  /// When [enabled] is false: draw a slash on the icon (no TV guide).
  final bool showNoGuideSlash;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Colors.white.withOpacity(0.38)
        : (focused ? accent : Colors.white.withOpacity(0.6));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: focused
                  ? (enabled
                      ? accent.withOpacity(0.18)
                      : Colors.white.withOpacity(0.06))
                  : Colors.white.withOpacity(0.06),
              border: Border.all(
                color: focused
                    ? (enabled
                        ? accent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.28))
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                if (showNoGuideSlash)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EpgNoGuideSlashPainter(
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              height: 1.05,
              fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (badge != null && badge!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              badge!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withOpacity(focused ? 0.95 : 0.75),
                fontSize: 7.5,
                height: 1.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EpgNoGuideSlashPainter extends CustomPainter {
  _EpgNoGuideSlashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.82),
      Offset(size.width * 0.82, size.height * 0.18),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _EpgNoGuideSlashPainter oldDelegate) =>
      oldDelegate.color != color;
}
