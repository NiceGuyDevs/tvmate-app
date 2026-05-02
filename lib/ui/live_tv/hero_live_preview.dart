import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import '../../data/device_memory_channel.dart';
import '../../data/live_hero_preview_audio_store.dart';
import '../../data/live_hero_preview_coordinator.dart';
import '../../data/performance_tier_store.dart';
import '../../player/vod_surface_view_android.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import 'hero_live_preview_desktop.dart';
import 'live_preview_channel.dart';
import 'hero_tv_bezel_frame.dart';
import 'mock_live_tv_data.dart';

/// Muted live stream in the hero; debounced [streamUrl] changes. TV-style bezel.
///
/// [useTvBezel] — when **true** (default), draws the retro frame around the picture
/// (Live TV hero). Set to **false** for a **full-bleed** preview (e.g. Multi-view)
/// so video uses the whole area without the decorative border.
///
/// [tvFrameStyle] / [bezelFinish] — passed to [HeroTvBezelFrame] when [useTvBezel] is true.
class HeroLivePreview extends StatefulWidget {
  const HeroLivePreview({
    super.key,
    required this.streamUrl,
    required this.channel,
    required this.width,
    required this.height,
    this.bottomInsideScreen,
    this.useTvBezel = true,
    this.tvFrameStyle = 1,
    this.bezelFinish = 0,
    this.parentalBlackout = false,
  });

  final String streamUrl;
  final MockLiveChannel channel;
  final double width;
  final double height;

  /// Timeline (clocks + progress) drawn **inside** the TV screen, bottom edge.
  final Widget? bottomInsideScreen;

  /// When false, video fills [width]×[height] with only a light clip — no fake TV shell.
  final bool useTvBezel;

  /// 0 … [HeroTvBezelFrame.styleMax] — bezel thickness / radius feel.
  final int tvFrameStyle;

  /// 0 … [HeroTvBezelFrame.finishMax] — outer shell material tint.
  final int bezelFinish;

  /// Parental lock: black screen only (no decoder, no poster).
  final bool parentalBlackout;

  @override
  State<HeroLivePreview> createState() => _HeroLivePreviewState();
}

class _HeroLivePreviewState extends State<HeroLivePreview>
    with WidgetsBindingObserver {
  static const _debounceMs = 420;

  int? _textureId;
  var _surfaceReady = false;
  var _loadFailed = false;
  Timer? _debounce;
  String? _appliedUrl;

  HeroLivePreviewDesktopController? _desktopController;
  var _desktopSurfaceReady = false;

  /// Avoid re-seeding the texture on the first [resumed] right after cold start.
  var _hadPausedLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    liveHeroPreviewAudioStore.addListener(_onHeroPreviewAudioMuteChanged);
    performanceTierStore.addListener(_onPerformanceTierChanged);
    LiveHeroPreviewCoordinator.releasedForFullscreen
        .addListener(_onCoordinatorReleasedForFullscreen);
    LiveHeroPreviewCoordinator.fullscreenRoutePopped
        .addListener(_onCoordinatorFullscreenPopped);
    if (_useAndroidTexturePreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    } else if (_useDesktopMkPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapDesktop());
    }
  }

  void _releasePreviewDecoder() {
    _debounce?.cancel();
    if (LivePreviewChannel.supported) {
      unawaited(LivePreviewChannel.dispose());
    }
    _desktopController?.dispose();
    _desktopController = null;
    if (mounted) {
      setState(() {
        _textureId = null;
        _surfaceReady = false;
        _desktopSurfaceReady = false;
        _appliedUrl = null;
        _loadFailed = false;
      });
    }
  }

  /// [openTvMatePlayer] disposed native preview — clear stale [Texture] state only.
  void _onCoordinatorReleasedForFullscreen() {
    if (!mounted) return;
    _debounce?.cancel();
    _desktopController?.dispose();
    _desktopController = null;
    setState(() {
      _textureId = null;
      _surfaceReady = false;
      _desktopSurfaceReady = false;
      _appliedUrl = null;
      _loadFailed = false;
    });
  }

  /// Fullscreen route popped; recreate single hero ExoPlayer if previews are enabled.
  void _onCoordinatorFullscreenPopped() {
    if (!mounted) return;
    if (_useAndroidTexturePreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_bootstrap());
      });
    } else if (_useDesktopMkPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_bootstrapDesktop());
      });
    }
  }

  void _onPerformanceTierChanged() {
    if (!mounted) return;
    final wantAndroid = _useAndroidTexturePreview;
    final wantDesktop = _useDesktopMkPreview;
    if (!wantAndroid && (_textureId != null || _surfaceReady)) {
      _debounce?.cancel();
      if (LivePreviewChannel.supported) {
        unawaited(LivePreviewChannel.dispose());
      }
      setState(() {
        _textureId = null;
        _surfaceReady = false;
        _appliedUrl = null;
        _loadFailed = false;
      });
    } else if (wantAndroid &&
        _textureId == null &&
        widget.streamUrl.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_bootstrap());
      });
    }
    if (!wantDesktop && _desktopController != null) {
      _debounce?.cancel();
      _desktopController!.dispose();
      _desktopController = null;
      setState(() {
        _desktopSurfaceReady = false;
        _appliedUrl = null;
        _loadFailed = false;
      });
    } else if (wantDesktop &&
        _desktopController == null &&
        widget.streamUrl.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_bootstrapDesktop());
      });
    }
  }

  void _onHeroPreviewAudioMuteChanged() {
    if (_useAndroidTexturePreview && LivePreviewChannel.supported) {
      if (_textureId == null || !_surfaceReady) return;
      unawaited(
        LivePreviewChannel.setUserMuted(liveHeroPreviewAudioStore.muted),
      );
    } else if (_useDesktopMkPreview && _desktopController != null && _desktopSurfaceReady) {
      unawaited(
        _desktopController!.setUserMuted(liveHeroPreviewAudioStore.muted),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _hadPausedLifecycle = true;
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    if (!_hadPausedLifecycle) return;
    _hadPausedLifecycle = false;
    if (!mounted) return;
    if (_useAndroidTexturePreview && LivePreviewChannel.supported) {
      // Native [MainActivity.onPause] releases ExoPlayer; old [Texture] id is invalid.
      setState(() {
        _textureId = null;
        _surfaceReady = false;
        _appliedUrl = null;
      });
      unawaited(_bootstrap());
    } else if (_useDesktopMkPreview) {
      _desktopController?.dispose();
      _desktopController = null;
      setState(() {
        _desktopSurfaceReady = false;
        _appliedUrl = null;
      });
      unawaited(_bootstrapDesktop());
    }
  }

  @override
  void didUpdateWidget(covariant HeroLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentalBlackout != widget.parentalBlackout) {
      if (widget.parentalBlackout) {
        _releasePreviewDecoder();
      } else if (widget.streamUrl.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_useAndroidTexturePreview) unawaited(_bootstrap());
          if (_useDesktopMkPreview) unawaited(_bootstrapDesktop());
        });
      }
    }
    if (_useAndroidTexturePreview) {
      if (oldWidget.streamUrl != widget.streamUrl) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
          if (!mounted) return;
          _loadCurrent();
        });
      }
    } else if (_useDesktopMkPreview) {
      if (oldWidget.streamUrl != widget.streamUrl) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
          if (!mounted) return;
          _loadCurrentDesktop();
        });
      }
    }
    if (oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.useTvBezel != widget.useTvBezel ||
        oldWidget.tvFrameStyle != widget.tvFrameStyle ||
        oldWidget.bezelFinish != widget.bezelFinish) {
      setState(() {});
    }
  }

  /// Skip hero preview only for **Optimized on non-Chromecast** TVs (e.g. Shield) to save RAM.
  /// **Chromecast always** gets the hero; [openTvMatePlayer] releases preview before fullscreen
  /// so only one decoder runs at a time.
  bool get _suppressHeavyHeroPreview =>
      performanceTierStore.isOptimizedEffective &&
      !DeviceMemoryChannel.useInAppTextPadOnly;

  bool get _useAndroidTexturePreview =>
      !kIsWeb &&
      !widget.parentalBlackout &&
      LivePreviewChannel.supported &&
      widget.streamUrl.trim().isNotEmpty &&
      !_suppressHeavyHeroPreview;

  /// Windows / macOS: live preview in hero via media_kit (separate from fullscreen player).
  bool get _useDesktopMkPreview =>
      !kIsWeb &&
      !widget.parentalBlackout &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS) &&
      widget.streamUrl.trim().isNotEmpty &&
      !_suppressHeavyHeroPreview;

  Future<void> _bootstrap() async {
    if (!_useAndroidTexturePreview || !mounted) return;
    try {
      final id = await LivePreviewChannel.ensureTexture();
      if (!mounted) return;
      setState(() {
        _textureId = id;
        _surfaceReady = true;
        _loadFailed = false;
      });
      await _loadCurrent();
    } on PlatformException catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _loadCurrent() async {
    if (!_useAndroidTexturePreview || !mounted) return;
    final url = widget.streamUrl.trim();
    if (url.isEmpty) return;
    if (_textureId == null) {
      await _bootstrap();
      return;
    }
    if (_appliedUrl == url) return;
    try {
      await LivePreviewChannel.load(url);
      if (LivePreviewChannel.supported) {
        await liveHeroPreviewAudioStore.ensureLoaded();
        await LivePreviewChannel.setUserMuted(liveHeroPreviewAudioStore.muted);
      }
      if (!mounted) return;
      setState(() {
        _appliedUrl = url;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _bootstrapDesktop() async {
    if (!_useDesktopMkPreview || !mounted) return;
    try {
      _desktopController ??= HeroLivePreviewDesktopController();
      await _loadCurrentDesktop();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _loadCurrentDesktop() async {
    if (!_useDesktopMkPreview || !mounted) return;
    final url = widget.streamUrl.trim();
    if (url.isEmpty) return;
    _desktopController ??= HeroLivePreviewDesktopController();
    if (_appliedUrl == url && _desktopSurfaceReady) return;
    try {
      await _desktopController!.load(url);
      await liveHeroPreviewAudioStore.ensureLoaded();
      await _desktopController!.setUserMuted(liveHeroPreviewAudioStore.muted);
      await _desktopController!.play();
      if (!mounted) return;
      setState(() {
        _appliedUrl = url;
        _loadFailed = false;
        _desktopSurfaceReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    LiveHeroPreviewCoordinator.releasedForFullscreen
        .removeListener(_onCoordinatorReleasedForFullscreen);
    LiveHeroPreviewCoordinator.fullscreenRoutePopped
        .removeListener(_onCoordinatorFullscreenPopped);
    performanceTierStore.removeListener(_onPerformanceTierChanged);
    liveHeroPreviewAudioStore.removeListener(_onHeroPreviewAudioMuteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    if (LivePreviewChannel.supported) {
      unawaited(LivePreviewChannel.dispose());
    }
    _desktopController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inner = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              widget.useTvBezel ? 3 : 10,
            ),
            child: _buildInner(context),
          ),
        ),
        if (widget.bottomInsideScreen != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: widget.bottomInsideScreen!,
          ),
      ],
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.useTvBezel
          ? HeroTvBezelFrame(
              style: widget.tvFrameStyle,
              finish: widget.bezelFinish,
              child: inner,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: inner,
              ),
            ),
    );
  }

  Widget _buildInner(BuildContext context) {
    if (widget.parentalBlackout) {
      return const SizedBox.expand(
        child: ColoredBox(color: Colors.black),
      );
    }
    if (_useAndroidTexturePreview &&
        _surfaceReady &&
        _textureId != null &&
        !_loadFailed) {
      // Streamer 4K: render into a native SurfaceView so SurfaceFlinger handles
      // colour conversion (the Flutter texture path would sample the MediaTek
      // vendor-private YUV format as solid green). Every other Android device
      // stays on the original [Texture] path.
      if (DeviceMemoryChannel.isGoogleTvStreamer) {
        return const SizedBox.expand(
          child: LivePreviewSurfaceViewAndroid(),
        );
      }
      return SizedBox.expand(
        child: Texture(textureId: _textureId!),
      );
    }
    if (_useDesktopMkPreview &&
        _desktopSurfaceReady &&
        _desktopController != null &&
        !_loadFailed) {
      return SizedBox.expand(
        child: mkv.Video(
          controller: _desktopController!.videoController,
          fill: Colors.black,
        ),
      );
    }
    return TvCatalogImage(
      url: liveChannelArtUrl(widget.channel),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}
