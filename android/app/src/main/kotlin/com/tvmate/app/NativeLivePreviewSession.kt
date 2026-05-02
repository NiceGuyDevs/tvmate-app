package com.tvmate.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.TextureRegistry
import io.flutter.view.TextureRegistry.SurfaceProducer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Second [ExoPlayer] for Live TV hero preview (with audio).
 * Paused while fullscreen [NativeExoPlayerSession] is active (Flutter calls [pauseForFullscreen]).
 */
class NativeLivePreviewSession(
    private val context: Context,
    private val flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var player: ExoPlayer? = null
    private var surfaceProducer: SurfaceProducer? = null
    private var lastProducerWidth = -1
    private var lastProducerHeight = -1

    /** See [NativeExoPlayerSession.externalSurface] — same rationale, hero live preview. */
    private var externalSurface: Surface? = null

    private val surfaceProducerCallback = object : TextureRegistry.SurfaceProducer.Callback {
        override fun onSurfaceAvailable() {
            mainHandler.post {
                if (externalSurface != null) return@post
                val prod = surfaceProducer ?: return@post
                player?.setVideoSurface(prod.surface)
            }
        }

        override fun onSurfaceCleanup() {
            mainHandler.post {
                if (externalSurface != null) return@post
                player?.clearVideoSurface()
            }
        }
    }
    private var pendingLoadUrl: String? = null
    private var previewMutedForFullscreen = false
    /** User preference (Flutter); video keeps playing, volume 0 when true. */
    private var userPreviewMuted = false

    private val applyLoadRunnable = Runnable {
        val url = pendingLoadUrl ?: return@Runnable
        pendingLoadUrl = null
        // Do NOT clear [previewMutedForFullscreen] here. A [load] can be queued/debounced
        // on the Flutter side and run *after* [pauseForFullscreen]; resetting the flag
        // would unmute the hero on top of fullscreen playback (double audio). Fullscreen
        // handoff is cleared only in [resumeAfterFullscreen].
        val p = ensurePlayer()
        p.setMediaItem(MediaItem.fromUri(url), true)
        p.setVolume(previewVolume())
        p.playWhenReady = true
        p.prepare()
    }

    private val playerListener = object : Player.Listener {
        override fun onPlayerError(error: PlaybackException) {
            player?.playWhenReady = false
        }

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            val w = videoSize.width
            val h = videoSize.height
            if (w <= 0 || h <= 0) return
            mainHandler.post { maybeUpdateSurfaceProducerSize(w, h) }
        }
    }

    fun registerChannels(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
    }

    /** See [NativeExoPlayerSession.bindExternalSurface]. */
    fun bindExternalSurface(surface: Surface?) {
        mainHandler.post {
            externalSurface = surface
            val p = player
            if (p != null) {
                if (surface != null) {
                    p.setVideoSurface(surface)
                } else {
                    val prod = surfaceProducer
                    if (prod != null) p.setVideoSurface(prod.surface)
                    else p.clearVideoSurface()
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureTexture" -> {
                try {
                    result.success(ensureTextureInternal())
                } catch (e: Exception) {
                    result.error("texture", e.message, null)
                }
            }

            "load" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("bad_args", "url required", null)
                    return
                }
                pendingLoadUrl = url
                mainHandler.removeCallbacks(applyLoadRunnable)
                mainHandler.post(applyLoadRunnable)
                result.success(null)
            }

            "pauseForFullscreen" -> {
                // Complete the Future only after pause + mute so Dart does not start
                // fullscreen ExoPlayer while hero preview audio is still active.
                mainHandler.post {
                    val p = player
                    if (p != null) {
                        previewMutedForFullscreen = true
                        p.playWhenReady = false
                        p.pause()
                        p.setVolume(0f)
                    }
                    result.success(null)
                }
            }

            "resumeAfterFullscreen" -> {
                mainHandler.post {
                    previewMutedForFullscreen = false
                    player?.setVolume(previewVolume())
                    player?.playWhenReady = true
                    player?.play()
                    result.success(null)
                }
            }

            "setUserMuted" -> {
                val m = call.argument<Boolean>("muted") ?: false
                mainHandler.post {
                    userPreviewMuted = m
                    if (!previewMutedForFullscreen) {
                        player?.setVolume(previewVolume())
                    }
                }
                result.success(null)
            }

            /** After [load], ensure playback runs (e.g. multiview second pane while fullscreen). */
            "play" -> {
                mainHandler.post {
                    val p = player ?: return@post
                    p.playWhenReady = true
                    p.play()
                }
                result.success(null)
            }

            "dispose" -> {
                disposeInternal()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun ensureTextureInternal(): Long {
        surfaceProducer?.let {
            return it.id()
        }
        val producer = flutterEngine.renderer.createSurfaceProducer()
        surfaceProducer = producer
        lastProducerWidth = -1
        lastProducerHeight = -1
        producer.setCallback(surfaceProducerCallback)
        producer.setSize(DEFAULT_SURFACE_WIDTH, DEFAULT_SURFACE_HEIGHT)
        val p = ensurePlayer()
        // Don't stomp on a SurfaceView (Streamer 4K) already bound.
        if (externalSurface == null) {
            p.setVideoSurface(producer.surface)
        }
        return producer.id()
    }

    private fun maybeUpdateSurfaceProducerSize(width: Int, height: Int) {
        if (width == lastProducerWidth && height == lastProducerHeight) return
        lastProducerWidth = width
        lastProducerHeight = height
        val prod = surfaceProducer ?: return
        prod.setSize(width, height)
        if (externalSurface == null) {
            player?.setVideoSurface(prod.surface)
        }
    }

    /** When the activity leaves the foreground; same as Flutter `dispose` method channel. */
    fun stopForActivityPause() {
        disposeInternal()
    }

    private fun disposeInternal() {
        mainHandler.removeCallbacks(applyLoadRunnable)
        pendingLoadUrl = null
        previewMutedForFullscreen = false
        player?.playWhenReady = false
        player?.pause()
        player?.stop()
        player?.clearVideoSurface()
        surfaceProducer?.setCallback(null)
        surfaceProducer?.release()
        surfaceProducer = null
        lastProducerWidth = -1
        lastProducerHeight = -1
        player?.removeListener(playerListener)
        player?.release()
        player = null
    }

    private fun previewVolume(): Float =
        if (previewMutedForFullscreen || userPreviewMuted) 0f else 1f

    private fun ensurePlayer(): ExoPlayer {
        if (player == null) {
            // Do not participate in audio focus: fullscreen main ExoPlayer must keep
            // playback/audio when this preview decodes a second multiview stream (volume 0).
            player = ExoPlayer.Builder(context)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_MEDIA)
                        .setContentType(C.CONTENT_TYPE_MOVIE)
                        .build(),
                    /* handleAudioFocus= */ false,
                )
                .build()
                .apply {
                    addListener(playerListener)
                    setVolume(previewVolume())
                    // Match fullscreen player: fit video inside preview Surface (no stretch).
                    setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)
                }
        }
        return player!!
    }

    companion object {
        const val METHOD_CHANNEL = "com.tvmate.app/live_preview"
        private const val DEFAULT_SURFACE_WIDTH = 1920
        private const val DEFAULT_SURFACE_HEIGHT = 1080
    }
}
