import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android-only widget that embeds a native [SurfaceView] for playback.
///
/// Mounted **only** on the Google TV Streamer 4K (gated by
/// `DeviceMemoryChannel.isGoogleTvStreamer`). Every other Android device, and
/// every desktop platform, keeps the unchanged Flutter [Texture] path.
///
/// The native side (`TvMateExternalSurfaceView`) forwards its
/// [android.view.Surface] to whichever ExoPlayer session matches [viewType]:
///  * [vodViewType] → `NativeExoPlayerSession.bindExternalSurface` (main VOD)
///  * [livePreviewViewType] → `NativeLivePreviewSession.bindExternalSurface`
///    (hero live TV preview).
///
/// ExoPlayer then renders decoder output into a real SurfaceView composited by
/// SurfaceFlinger, which colour-converts the MediaTek private YUV format that
/// Flutter's [io.flutter.view.TextureRegistry.SurfaceProducer] cannot sample
/// (the source of the green-screen bug).
///
/// Uses [PlatformViewLink] + [PlatformViewsService.initSurfaceAndroidView] —
/// Flutter's Hybrid Composition path for SurfaceView-backed native views.
class AndroidExternalSurfaceView extends StatelessWidget {
  const AndroidExternalSurfaceView({super.key, required this.viewType});

  final String viewType;

  /// Main VOD (`NativeExoPlayerSession`).
  static const String vodViewType = 'com.tvmate.app/vod_surface';

  /// Hero live TV preview (`NativeLivePreviewSession`).
  static const String livePreviewViewType = 'com.tvmate.app/live_preview_surface';

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: const <String, dynamic>{},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}

/// Main VOD SurfaceView (Streamer 4K only).
class VodSurfaceViewAndroid extends StatelessWidget {
  const VodSurfaceViewAndroid({super.key});

  @override
  Widget build(BuildContext context) {
    return const AndroidExternalSurfaceView(
      viewType: AndroidExternalSurfaceView.vodViewType,
    );
  }
}

/// Hero live preview SurfaceView (Streamer 4K only).
class LivePreviewSurfaceViewAndroid extends StatelessWidget {
  const LivePreviewSurfaceViewAndroid({super.key});

  @override
  Widget build(BuildContext context) {
    return const AndroidExternalSurfaceView(
      viewType: AndroidExternalSurfaceView.livePreviewViewType,
    );
  }
}
