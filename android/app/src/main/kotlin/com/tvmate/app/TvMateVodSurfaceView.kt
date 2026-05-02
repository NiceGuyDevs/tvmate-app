package com.tvmate.app

import android.content.Context
import android.graphics.Color
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Native [SurfaceView] host, exposed to Flutter as a platform view.
 *
 * Used **only** on the Google TV Streamer 4K (see
 * [DeviceInfoChannel.isGoogleTvStreamerDevice]). Its MediaTek decoder emits a
 * vendor-private 10-bit YUV format (0x7FA30C01) that Flutter's
 * [io.flutter.view.TextureRegistry.SurfaceProducer] cannot sample, so frames come
 * out solid green. A real [SurfaceView] is composited by SurfaceFlinger /
 * HWComposer, which colour-converts the private format in hardware.
 *
 * Every other Android device (Shield, FireTV, Chromecast, etc.) continues to use
 * the unchanged Flutter [Texture] path — this factory is registered globally but
 * only mounted by Dart when the Streamer 4K is detected.
 *
 * Implementation notes:
 *  - [getView] returns a [FrameLayout] wrapper rather than the raw [SurfaceView];
 *    Flutter's PlatformView embedding expects a container as the root view so it
 *    can manage layout insertion.
 *  - [SurfaceView.setZOrderMediaOverlay] is enabled so the video layer is
 *    composited above the host window's background fill but still below any
 *    Flutter overlay widgets drawn on top (player controls, subtitles, etc.) —
 *    without this flag the Flutter compositor's black paint hides the decoded
 *    frames and the user sees audio-only "black screen" playback.
 *
 *  The same primitive is reused for the main VOD player ([NativeExoPlayerSession])
 *  and the hero live preview ([NativeLivePreviewSession]) via two view factories
 *  that differ only in the `bindSurface` callback they hand to Flutter.
 */
class TvMateExternalSurfaceView(
    context: Context,
    private val bindSurface: (Surface?) -> Unit,
) : PlatformView, SurfaceHolder.Callback {

    private val surfaceView = SurfaceView(context).apply {
        setZOrderMediaOverlay(true)
    }

    private val root = FrameLayout(context).apply {
        setBackgroundColor(Color.BLACK)
        addView(
            surfaceView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    init {
        surfaceView.holder.addCallback(this)
    }

    override fun getView(): View = root

    override fun dispose() {
        surfaceView.holder.removeCallback(this)
        bindSurface(null)
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        bindSurface(holder.surface)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        bindSurface(holder.surface)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        bindSurface(null)
    }
}

/** Main VOD player PlatformView factory. */
class TvMateVodSurfaceViewFactory(
    private val session: NativeExoPlayerSession,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return TvMateExternalSurfaceView(context) { session.bindExternalSurface(it) }
    }

    companion object {
        const val VIEW_TYPE: String = "com.tvmate.app/vod_surface"
    }
}

/** Hero live preview PlatformView factory. */
class TvMateLivePreviewSurfaceViewFactory(
    private val session: NativeLivePreviewSession,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return TvMateExternalSurfaceView(context) { session.bindExternalSurface(it) }
    }

    companion object {
        const val VIEW_TYPE: String = "com.tvmate.app/live_preview_surface"
    }
}
