package com.tvmate.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlin.math.roundToInt
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.Tracks
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.TextureRegistry
import io.flutter.view.TextureRegistry.SurfaceProducer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pool of up to [MAX_SLOTS] independent ExoPlayer instances, each with its
 * own Flutter [SurfaceProducer] texture.
 *
 * Used for:
 *  • **Multiview** – up to 4 channels playing simultaneously.
 *  • **Zero-delay channel switching** – two slots leapfrog so the next
 *    channel is pre-buffered before the user even presses a button.
 *
 * Flutter talks to the pool through a single [MethodChannel]
 * (`com.tvmate.app/player_pool`).  Every call includes a `slot` (0-based index)
 * to address the correct player.
 */
class NativePlayerPool(
    private val context: Context,
    private val flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "PlayerPool"
        const val METHOD_CHANNEL = "com.tvmate.app/player_pool"
        const val MAX_SLOTS = 4
        private const val DEFAULT_SURFACE_W = 1920
        private const val DEFAULT_SURFACE_H = 1080
        private const val SD_SURFACE_W = 640
        private const val SD_SURFACE_H = 360
        private const val PLAYBACK_START_MS = 250
        private const val LIVE_MIN_BUFFER_MS = 2_000
        private const val LIVE_MAX_BUFFER_MS = 8_000
        private const val LIVE_REBUFFER_MS = 500
        private const val BG_MIN_BUFFER_MS = 1_500
        private const val BG_MAX_BUFFER_MS = 3_000
        private const val BG_REBUFFER_MS = 500
        private const val FREEZE_WATCHDOG_MS = 8_000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /** One entry per slot; created lazily on first `ensureTexture`. */
    private val slots = arrayOfNulls<Slot>(MAX_SLOTS)

    // ────────────────────────────────────────────────────────────────
    //  Slot – one ExoPlayer + one SurfaceProducer + state
    // ────────────────────────────────────────────────────────────────
    private inner class Slot(val index: Int) {
        var player: ExoPlayer? = null
        var surfaceProducer: SurfaceProducer? = null
        var lastW = -1; var lastH = -1
        var currentUrl: String? = null
        var backgroundMode = false
        /** Live TV manual cap (0 = off). Does not apply when [backgroundMode] is true. */
        var userQualityMaxH: Int = 0
        private var freezeWatchdog: Runnable? = null
        private var recoveryCount = 0

        val surfaceCb = object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                mainHandler.post {
                    val prod = surfaceProducer ?: return@post
                    player?.setVideoSurface(prod.surface)
                }
            }
            override fun onSurfaceCleanup() {
                mainHandler.post { player?.clearVideoSurface() }
            }
        }

        var retryCount = 0

        private fun cancelWatchdog() {
            freezeWatchdog?.let { mainHandler.removeCallbacks(it) }
            freezeWatchdog = null
        }

        private fun scheduleWatchdog() {
            cancelWatchdog()
            if (recoveryCount >= 3) return
            val r = Runnable {
                val url = currentUrl ?: return@Runnable
                val p = player ?: return@Runnable
                val state = p.playbackState
                if (state != Player.STATE_BUFFERING && state != Player.STATE_IDLE) return@Runnable
                recoveryCount++
                Log.w(TAG, "Slot $index: frozen in ${if (state == Player.STATE_BUFFERING) "BUFFERING" else "IDLE"} — recovery #$recoveryCount, destroying player")
                p.removeListener(listener)
                p.clearVideoSurface()
                p.release()
                player = null
                val newP = ensurePlayer()
                val prod = surfaceProducer
                if (prod != null) {
                    newP.setVideoSurface(prod.surface)
                }
                applyTrackConstraints(newP)
                newP.setMediaItem(MediaItem.fromUri(url), true)
                newP.playWhenReady = true
                newP.prepare()
            }
            freezeWatchdog = r
            mainHandler.postDelayed(r, FREEZE_WATCHDOG_MS)
        }

        val listener = object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                Log.w(TAG, "Slot $index error (code=${error.errorCode}): ${error.message}", error)
                cancelWatchdog()
                if (retryCount < 3 && currentUrl != null) {
                    retryCount++
                    val delayMs = retryCount * 1000L
                    Log.i(TAG, "Slot $index retry $retryCount in ${delayMs}ms (bg=$backgroundMode)")
                    mainHandler.postDelayed({
                        val url = currentUrl ?: return@postDelayed
                        val p = player ?: return@postDelayed
                        val prod = surfaceProducer
                        if (prod != null) {
                            p.clearVideoSurface()
                            p.setVideoSurface(prod.surface)
                        }
                        applyTrackConstraints(p)
                        p.setMediaItem(MediaItem.fromUri(url), true)
                        p.playWhenReady = true
                        p.prepare()
                    }, delayMs)
                }
            }
            override fun onPlaybackStateChanged(state: Int) {
                val label = when (state) {
                    Player.STATE_IDLE -> "IDLE"
                    Player.STATE_BUFFERING -> "BUFFERING"
                    Player.STATE_READY -> "READY"
                    Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN($state)"
                }
                Log.d(TAG, "Slot $index state -> $label")
                when (state) {
                    Player.STATE_READY -> {
                        retryCount = 0
                        recoveryCount = 0
                        cancelWatchdog()
                    }
                    Player.STATE_BUFFERING -> {
                        scheduleWatchdog()
                    }
                    Player.STATE_ENDED -> {
                        cancelWatchdog()
                        val url = currentUrl
                        if (url != null) {
                            Log.i(TAG, "Slot $index: stream ENDED, reloading in 1s")
                            mainHandler.postDelayed({
                                val u = currentUrl ?: return@postDelayed
                                val p = player ?: return@postDelayed
                                applyTrackConstraints(p)
                                p.setMediaItem(MediaItem.fromUri(u), true)
                                p.playWhenReady = true
                                p.prepare()
                            }, 1000L)
                        }
                    }
                }
            }
            override fun onVideoSizeChanged(videoSize: VideoSize) {
                val w = videoSize.width; val h = videoSize.height
                Log.d(TAG, "Slot $index videoSize ${w}x${h}")
                if (w <= 0 || h <= 0) return
                mainHandler.post { maybeResizeSurface(w, h) }
            }
        }

        fun ensureTexture(bg: Boolean): Long {
            backgroundMode = bg
            surfaceProducer?.let { return it.id() }
            val prod = flutterEngine.renderer.createSurfaceProducer()
            surfaceProducer = prod
            lastW = -1; lastH = -1
            prod.setCallback(surfaceCb)
            val sw = if (bg) SD_SURFACE_W else DEFAULT_SURFACE_W
            val sh = if (bg) SD_SURFACE_H else DEFAULT_SURFACE_H
            prod.setSize(sw, sh)
            ensurePlayer().setVideoSurface(prod.surface)
            return prod.id()
        }

        fun ensurePlayer(): ExoPlayer {
            player?.let { return it }
            Log.i(TAG, "Slot $index: creating player (bg=$backgroundMode)")
            val minBuf = if (backgroundMode) BG_MIN_BUFFER_MS else LIVE_MIN_BUFFER_MS
            val maxBuf = if (backgroundMode) BG_MAX_BUFFER_MS else LIVE_MAX_BUFFER_MS
            val rebuf  = if (backgroundMode) BG_REBUFFER_MS   else LIVE_REBUFFER_MS
            val lc = DefaultLoadControl.Builder()
                .setBufferDurationsMs(minBuf, maxBuf, PLAYBACK_START_MS, rebuf)
                .setPrioritizeTimeOverSizeThresholds(true)
                .build()
            val rf = DefaultRenderersFactory(context)
                .setExtensionRendererMode(
                    DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER
                )
                .setEnableDecoderFallback(true)
            val p = ExoPlayer.Builder(context)
                .setLoadControl(lc)
                .setRenderersFactory(rf)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_MEDIA)
                        .setContentType(C.CONTENT_TYPE_MOVIE)
                        .build(),
                    /* handleAudioFocus= */ index == 0,
                )
                .build()
                .apply {
                    addListener(listener)
                    volume = 0f
                    setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)
                }
            player = p
            return p
        }

        fun load(url: String) {
            Log.i(TAG, "Slot $index: load ${url.take(60)}... (bg=$backgroundMode)")
            currentUrl = url
            retryCount = 0
            userQualityMaxH = 0
            val p = ensurePlayer()
            applyTrackConstraints(p)
            p.setMediaItem(MediaItem.fromUri(url), true)
            p.playWhenReady = true
            p.prepare()
        }

        private fun applyTrackConstraints(p: ExoPlayer) {
            val builder = p.trackSelectionParameters.buildUpon()
            if (backgroundMode) {
                builder.setMaxVideoSize(SD_SURFACE_W, SD_SURFACE_H)
                    .setMaxVideoBitrate(500_000)
                    .setMaxVideoFrameRate(20)
                    .setForceLowestBitrate(true)
            } else if (userQualityMaxH > 0) {
                builder.setMaxVideoSize(4096, userQualityMaxH)
                    .setMaxVideoBitrate(Int.MAX_VALUE)
                    .setMaxVideoFrameRate(Int.MAX_VALUE)
                    .setForceLowestBitrate(false)
            } else {
                builder.clearVideoSizeConstraints()
                    .setMaxVideoBitrate(Int.MAX_VALUE)
                    .setMaxVideoFrameRate(Int.MAX_VALUE)
                    .setForceLowestBitrate(false)
            }
            p.trackSelectionParameters = builder.build()
        }

        fun setUserQualityMaxHeight(maxH: Int) {
            userQualityMaxH = maxH.coerceAtLeast(0)
            player?.let { applyTrackConstraints(it) }
        }

        fun setVolume(vol: Float) {
            player?.volume = vol.coerceIn(0f, 1f)
        }

        fun setMaxVideoSize(maxW: Int, maxH: Int) {
            val p = player ?: return
            val isBg = maxW < DEFAULT_SURFACE_W
            backgroundMode = isBg
            if (isBg) {
                userQualityMaxH = 0
            }
            applyTrackConstraints(p)
            val prod = surfaceProducer
            if (prod != null) {
                val sw = if (isBg) SD_SURFACE_W else DEFAULT_SURFACE_W
                val sh = if (isBg) SD_SURFACE_H else DEFAULT_SURFACE_H
                prod.setSize(sw, sh)
                lastW = sw; lastH = sh
                p.setVideoSurface(prod.surface)
            }
            Log.d(TAG, "Slot $index: maxVideoSize ${maxW}x${maxH} bg=$isBg")
        }

        fun play()  { player?.let { it.playWhenReady = true; it.play() } }
        fun pause() { player?.pause() }
        fun stop()  { player?.let { it.playWhenReady = false; it.stop() } }

        fun maybeResizeSurface(w: Int, h: Int) {
            val capW = if (backgroundMode) w.coerceAtMost(SD_SURFACE_W) else w
            val capH = if (backgroundMode) h.coerceAtMost(SD_SURFACE_H) else h
            if (capW == lastW && capH == lastH) return
            lastW = capW; lastH = capH
            val prod = surfaceProducer ?: return
            prod.setSize(capW, capH)
            player?.setVideoSurface(prod.surface)
        }

        fun releaseTexture() {
            player?.playWhenReady = false
            player?.pause()
            player?.stop()
            player?.clearVideoSurface()
            surfaceProducer?.setCallback(null)
            surfaceProducer?.release()
            surfaceProducer = null
            lastW = -1; lastH = -1
        }

        fun dispose() {
            cancelWatchdog()
            releaseTexture()
            player?.removeListener(listener)
            player?.release()
            player = null
            currentUrl = null
        }
    }

    // ────────────────────────────────────────────────────────────────
    //  Channel registration
    // ────────────────────────────────────────────────────────────────
    fun registerChannels(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
    }

    fun stopForActivityPause() {
        mainHandler.post {
            for (s in slots) {
                s?.player?.let { it.playWhenReady = false; it.pause() }
            }
        }
    }

    // ────────────────────────────────────────────────────────────────
    //  Method dispatch
    // ────────────────────────────────────────────────────────────────
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val slot = call.argument<Int>("slot") ?: -1

        when (call.method) {
            "ensureTexture" -> {
                if (slot < 0 || slot >= MAX_SLOTS) {
                    result.error("bad_slot", "slot must be 0..${MAX_SLOTS - 1}", null)
                    return
                }
                val bg = call.argument<Boolean>("bg") ?: false
                try {
                    val s = slots[slot] ?: Slot(slot).also { slots[slot] = it }
                    mainHandler.post {
                        try {
                            val texId = s.ensureTexture(bg)
                            result.success(texId)
                        } catch (e: Exception) {
                            result.error("texture", e.message, null)
                        }
                    }
                } catch (e: Exception) {
                    result.error("texture", e.message, null)
                }
            }

            "load" -> {
                val url = call.argument<String>("url")
                if (slot < 0 || slot >= MAX_SLOTS || url.isNullOrBlank()) {
                    result.error("bad_args", "slot + url required", null)
                    return
                }
                val s = slots[slot]
                if (s == null) { result.error("no_slot", "call ensureTexture first", null); return }
                mainHandler.post { s.load(url) }
                result.success(null)
            }

            "play" -> {
                val s = slotOrNull(slot)
                if (s != null) mainHandler.post { s.play() }
                result.success(null)
            }

            "pause" -> {
                val s = slotOrNull(slot)
                if (s != null) mainHandler.post { s.pause() }
                result.success(null)
            }

            "stop" -> {
                val s = slotOrNull(slot)
                if (s != null) mainHandler.post { s.stop() }
                result.success(null)
            }

            "setVolume" -> {
                val vol = (call.argument<Double>("volume") ?: 0.0).toFloat()
                val s = slotOrNull(slot)
                if (s != null) mainHandler.post { s.setVolume(vol) }
                result.success(null)
            }

            "setMaxVideoSize" -> {
                val maxW = call.argument<Int>("maxWidth") ?: Int.MAX_VALUE
                val maxH = call.argument<Int>("maxHeight") ?: Int.MAX_VALUE
                val s = slotOrNull(slot)
                if (s != null) mainHandler.post { s.setMaxVideoSize(maxW, maxH) }
                result.success(null)
            }

            "setUserQualityMaxHeight" -> {
                val maxH = call.argument<Int>("maxHeight") ?: 0
                val s = slotOrNull(slot)
                if (s != null) mainHandler.post { s.setUserQualityMaxHeight(maxH) }
                result.success(null)
            }

            "getPlaybackMetrics" -> {
                val s = slotOrNull(slot)
                if (s == null) {
                    result.success(
                        mapOf("videoWidth" to -1, "videoHeight" to -1),
                    )
                    return
                }
                mainHandler.post {
                    val p = s.player
                    val f = p?.videoFormat
                    val (vw, vh) = displayVideoWidthHeight(f)
                    result.success(
                        mapOf("videoWidth" to vw, "videoHeight" to vh),
                    )
                }
            }

            "getVideoVariantHeights" -> {
                val s = slotOrNull(slot)
                if (s == null) {
                    result.success(emptyList<Int>())
                    return
                }
                mainHandler.post {
                    val p = s.player
                    if (p == null) {
                        result.success(emptyList<Int>())
                        return@post
                    }
                    result.success(collectVideoHeights(p.currentTracks))
                }
            }

            "releaseSlot" -> {
                val s = slotOrNull(slot)
                if (s != null) mainHandler.post { s.dispose(); slots[slot] = null }
                result.success(null)
            }

            "releaseAll" -> {
                mainHandler.post {
                    for (i in slots.indices) {
                        slots[i]?.dispose()
                        slots[i] = null
                    }
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun slotOrNull(i: Int): Slot? =
        if (i in 0 until MAX_SLOTS) slots[i] else null

    private fun displayVideoWidthHeight(vf: Format?): Pair<Int, Int> {
        if (vf == null) return Pair(-1, -1)
        var w = vf.width.toFloat()
        var h = vf.height.toFloat()
        if (w <= 0f || h <= 0f) return Pair(-1, -1)
        val par = vf.pixelWidthHeightRatio.takeIf { it > 0f } ?: 1f
        w *= par
        when (vf.rotationDegrees) {
            90, 270 -> {
                val t = w
                w = h
                h = t
            }
        }
        return Pair(w.roundToInt().coerceAtLeast(1), h.roundToInt().coerceAtLeast(1))
    }

    private fun collectVideoHeights(tracks: Tracks): List<Int> {
        val set = mutableSetOf<Int>()
        for (gi in 0 until tracks.groups.size) {
            val group = tracks.groups[gi]
            if (group.type != C.TRACK_TYPE_VIDEO) continue
            for (ti in 0 until group.length) {
                val f = group.getTrackFormat(ti)
                val h = f.height
                if (h > 0) set.add(h)
            }
        }
        return set.sortedDescending()
    }
}
