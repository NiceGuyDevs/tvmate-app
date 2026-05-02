package com.tvmate.app

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.Surface
import kotlin.math.roundToInt
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.text.CueGroup
import androidx.media3.common.util.Util
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.TextureRegistry
import io.flutter.view.TextureRegistry.SurfaceProducer
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.charset.StandardCharsets

/**
 * Single [ExoPlayer] instance bound to an optional Flutter [SurfaceProducer].
 * Uses the embedding surface-producer path (Skia GL or Impeller); not legacy [SurfaceTexture].
 * Survives stream switches; surface is recreated when Flutter releases it.
 */
class NativeExoPlayerSession(
    private val context: Context,
    private val flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var player: ExoPlayer? = null
    private var surfaceProducer: SurfaceProducer? = null
    private var lastProducerWidth = -1
    private var lastProducerHeight = -1
    private var isLiveMode = false

    /**
     * External [Surface] supplied by [TvMateVodSurfaceView] (a native SurfaceView
     * platform view). Only used on Google TV Streamer 4K and only for VOD — on that
     * hardware the MediaCodec emits a vendor-private YUV format that Flutter's
     * [SurfaceProducer] cannot sample, so the frame renders solid green. Routing
     * decoder output through a real SurfaceView lets SurfaceFlinger / HWComposer
     * perform the colour conversion instead. On every other device this stays null
     * and the original SurfaceProducer path is unchanged.
     */
    private var externalSurface: Surface? = null

    /** Live manual max decode height (0 = full ladder). Controlled from Flutter; cleared when zapping. */
    private var userQualityMaxHeight: Int = 0

    /**
     * [SurfaceProducer] surfaces must not be cached; call [SurfaceProducer.getSurface] again after
     * [SurfaceProducer.setSize] and implement [TextureRegistry.SurfaceProducer.Callback] for lifecycle.
     */
    private val surfaceProducerCallback = object : TextureRegistry.SurfaceProducer.Callback {
        override fun onSurfaceAvailable() {
            mainHandler.post {
                // External SurfaceView wins when bound (Streamer 4K VOD path).
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
    private var eventSink: EventChannel.EventSink? = null

    private var currentUri: String? = null
    private var retryCount = 0
    private var pendingLoadUrl: String? = null
    private var pendingLoadIsLive: Boolean = false
    /** Live + Dart weak-device path: smaller buffers for faster channel switches. */
    private var pendingLiveFastSwitch: Boolean = false
    private var bufferProfileFastLive: Boolean = false
    private var pendingAudioDelayMs: Int = 0
    private var pendingPlaybackSpeed: Float = 1f
    private var pendingSubtitlePath: String? = null
    private var pendingSubtitleDelayMs: Int = 0

    /** Last loaded external SRT path (session); cleared on new [load] URL. */
    private var currentSubtitlePath: String? = null

    /** Mirrors active A/V sync + speed so subtitle reload preserves them. */
    private var sessionAudioDelayMs: Int = 0
    private var sessionPlaybackSpeed: Float = 1f
    /** VOD: subtitle time offset in ms (positive = cues later). [MediaItem.SubtitleConfiguration] has no offset API; we apply by rewriting SRT. */
    private var sessionSubtitleDelayMs: Int = 0

    private val leadingSilence = TvMateLeadingSilenceAudioProcessor()
    private val trimming = TvMateTrimmingAudioProcessor()

    private val applyLoadRunnable = Runnable {
        val url = pendingLoadUrl ?: return@Runnable
        val live = pendingLoadIsLive
        val fastLive = live && pendingLiveFastSwitch
        val delayMs = pendingAudioDelayMs
        val speed = pendingPlaybackSpeed
        pendingLoadUrl = null
        retryCount = 0
        cancelPendingRetry()

        if (player != null && fastLive != bufferProfileFastLive) {
            releasePlayerKeepSurface()
        }
        bufferProfileFastLive = fastLive

        val switching = currentUri != null
        currentUri = url
        isLiveMode = live
        sessionAudioDelayMs = delayMs
        sessionPlaybackSpeed = speed
        sessionSubtitleDelayMs = pendingSubtitleDelayMs
        currentSubtitlePath = pendingSubtitlePath
        pendingSubtitlePath = null
        pendingSubtitleDelayMs = 0

        val p = ensurePlayer()
        applyPlaybackAndAudioSync(speed, delayMs)
        applyUserVideoQualityCap(p)

        // Apply seek parameters based on stream type.
        // VOD/catch-up: snap to nearest keyframe for faster seeks.
        // Live: use default (exact) seek — not used in practice for live.
        p.setSeekParameters(
            if (live) SeekParameters.DEFAULT else SeekParameters.CLOSEST_SYNC
        )

        // Direct media swap — no stop() call. ExoPlayer handles the transition
        // internally, which is faster and keeps the last frame visible until
        // the new stream renders its first frame.
        p.setMediaItem(buildMediaItem(url, currentSubtitlePath), true)
        p.playWhenReady = true
        p.prepare()
        // [prepare] / new timeline often resets [PlaybackParameters] to 1× — re-apply after Exo finishes
        // (post so this runs after internal state updates). Without this, VOD speed stays 1× until
        // another call that runs [applyPlaybackAndAudioSync] (e.g. subtitle attach).
        mainHandler.post { applySessionPlaybackParametersOnly() }

        // Tell Flutter this is a channel switch so it can suppress the spinner
        if (switching && live) {
            safeEmit(mapOf("type" to "channelSwitch"))
        }
    }

    private val retryLoadRunnable = Runnable { retryLoadSameUri() }

    private val progressRunnable = object : Runnable {
        override fun run() {
            val sink = eventSink ?: return
            emitProgress(sink)
            mainHandler.postDelayed(this, PROGRESS_MS)
        }
    }

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_READY) {
                retryCount = 0
            }
            safeEmit(
                mapOf(
                    "type" to "state",
                    "playbackState" to playbackStateToString(playbackState),
                    "playbackStateRaw" to playbackState,
                ),
            )
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            safeEmit(mapOf("type" to "isPlaying", "isPlaying" to isPlaying))
        }

        override fun onPlayerError(error: PlaybackException) {
            if (retryCount < MAX_RETRIES) {
                retryCount++
                safeEmit(
                    mapOf(
                        "type" to "retrying",
                        "attempt" to retryCount,
                        "maxAttempts" to MAX_RETRIES,
                    ),
                )
                cancelPendingRetry()
                mainHandler.postDelayed(retryLoadRunnable, RETRY_DELAY_MS)
            } else {
                safeEmit(
                    mapOf(
                        "type" to "error",
                        "message" to (error.message ?: "Playback error"),
                    ),
                )
            }
        }

        override fun onCues(cueGroup: CueGroup) {
            safeEmit(buildCuesPayload(cueGroup))
        }
    }

    fun registerChannels(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
    }

    /**
     * Called by [TvMateVodSurfaceView] when its native [android.view.SurfaceView]
     * [Surface] is created / destroyed. While set this surface replaces the Flutter
     * [SurfaceProducer] for ExoPlayer output — see [externalSurface] for rationale.
     */
    fun bindExternalSurface(surface: Surface?) {
        mainHandler.post {
            externalSurface = surface
            val p = player
            if (p != null) {
                if (surface != null) {
                    p.setVideoSurface(surface)
                } else {
                    // Drop to the SurfaceProducer fallback if it exists; otherwise
                    // clear — ExoPlayer will buffer until a surface is re-attached.
                    val prod = surfaceProducer
                    if (prod != null) p.setVideoSurface(prod.surface)
                    else p.clearVideoSurface()
                }
            }
        }
    }

    /** Activity left foreground — stop audio (live preview is handled separately). */
    fun stopForActivityPause() {
        mainHandler.post {
            val p = player ?: return@post
            p.playWhenReady = false
            p.pause()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureTexture" -> {
                try {
                    val id = ensureTextureInternal()
                    result.success(id)
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
                pendingLoadIsLive = call.argument<Boolean>("isLive") ?: false
                pendingLiveFastSwitch = call.argument<Boolean>("liveFastSwitch") ?: false
                pendingAudioDelayMs = call.argument<Int>("audioDelayMs") ?: 0
                pendingPlaybackSpeed = floatArg(call, "playbackSpeed", 1f)
                pendingSubtitleDelayMs =
                    (call.argument<Int>("subtitleDelayMs") ?: 0).coerceIn(-10_000, 10_000)
                val sub = call.argument<String>("subtitlePath")?.trim()
                pendingSubtitlePath = if (sub.isNullOrEmpty()) null else sub
                mainHandler.removeCallbacks(applyLoadRunnable)
                mainHandler.post(applyLoadRunnable)
                result.success(null)
            }

            "setExternalSubtitle" -> {
                val path = call.argument<String>("path")?.trim()
                val delayArg = call.argument<Int>("subtitleDelayMs")
                if (delayArg != null) {
                    sessionSubtitleDelayMs = delayArg.coerceIn(-10_000, 10_000)
                }
                mainHandler.post {
                    val p = player ?: return@post
                    val uri = currentUri ?: return@post
                    val pos = p.currentPosition
                    currentSubtitlePath = if (path.isNullOrEmpty()) null else path
                    // [replaceMediaItem] was dropping sidecar text for some Exo versions — use [setMediaItem].
                    p.setMediaItem(buildMediaItem(uri, currentSubtitlePath), /* resetPosition= */ false)
                    p.seekTo(pos)
                    p.prepare()
                    p.playWhenReady = true
                    applyPlaybackAndAudioSync(sessionPlaybackSpeed, sessionAudioDelayMs)
                    // Exo may clear PlaybackParameters after prepare() on its internal thread;
                    // re-apply in the next message to guarantee speed survives the reload.
                    mainHandler.post { applySessionPlaybackParametersOnly() }
                }
                result.success(null)
            }

            "setPlaybackSpeed" -> {
                val s = floatArg(call, "speed", 1f)
                val clamped = s.coerceIn(0.25f, 4f)
                sessionPlaybackSpeed = clamped
                mainHandler.post {
                    val pl = player ?: return@post
                    pl.playbackParameters = PlaybackParameters(clamped, 1f)
                }
                result.success(null)
            }

            "setAudioDelayMs" -> {
                val ms = call.argument<Int>("audioDelayMs") ?: 0
                val d = ms.coerceIn(-10_000, 10_000)
                sessionAudioDelayMs = d
                mainHandler.post {
                    applyAudioDelayMsInternal(d)
                }
                result.success(null)
            }

            "setSubtitleDelayMs" -> {
                val ms = (call.argument<Int>("subtitleDelayMs") ?: 0)
                    .coerceIn(-10_000, 10_000)
                sessionSubtitleDelayMs = ms
                mainHandler.post {
                    val uri = currentUri ?: return@post
                    val p = player ?: return@post
                    val pos = p.currentPosition
                    p.setMediaItem(buildMediaItem(uri, currentSubtitlePath), false)
                    p.seekTo(pos)
                    p.prepare()
                    p.playWhenReady = true
                    applyPlaybackAndAudioSync(sessionPlaybackSpeed, sessionAudioDelayMs)
                    // Exo may clear PlaybackParameters after prepare(); re-apply in the next
                    // message so speed is never reset by a subtitle delay change.
                    mainHandler.post { applySessionPlaybackParametersOnly() }
                }
                result.success(null)
            }

            "getTracksSnapshot" -> {
                result.success(buildTracksSnapshot())
            }

            "setLiveVideoMaxHeight" -> {
                val h = call.argument<Int>("maxHeight") ?: 0
                userQualityMaxHeight = h.coerceAtLeast(0)
                mainHandler.post {
                    player?.let { applyUserVideoQualityCap(it) }
                }
                result.success(null)
            }

            "play" -> {
                ensurePlayer().play()
                result.success(null)
            }

            "pause" -> {
                player?.pause()
                result.success(null)
            }

            "setVolume" -> {
                val vol = (call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                mainHandler.post { player?.volume = vol }
                result.success(null)
            }

            "seekTo" -> {
                val ms = positionMsFromCall(call)
                ensurePlayer().seekTo(ms)
                result.success(null)
            }

            "releaseTexture" -> {
                releaseTextureInternal()
                result.success(null)
            }

            "dispose" -> {
                releaseAllInternal()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        mainHandler.removeCallbacks(progressRunnable)
        mainHandler.post(progressRunnable)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        mainHandler.removeCallbacks(progressRunnable)
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
        // Default TV-sized buffers before format is known; refined in [emitProgress].
        producer.setSize(DEFAULT_SURFACE_WIDTH, DEFAULT_SURFACE_HEIGHT)
        val p = ensurePlayer()
        // Don't stomp on a SurfaceView (Streamer 4K VOD path) already bound.
        if (externalSurface == null) {
            p.setVideoSurface(producer.surface)
        }
        return producer.id()
    }

    private fun cancelPendingRetry() {
        mainHandler.removeCallbacks(retryLoadRunnable)
    }

    private fun releaseTextureInternal() {
        mainHandler.removeCallbacks(applyLoadRunnable)
        cancelPendingRetry()
        pendingLoadUrl = null
        leadingSilence.setDelayMs(0)
        trimming.setTrimFrameCount(0, 0)
        player?.playbackParameters = PlaybackParameters(1f, 1f)
        // Stop decoding + audio — releasing the surface alone leaves audio playing.
        player?.playWhenReady = false
        player?.pause()
        player?.stop()
        player?.clearVideoSurface()
        surfaceProducer?.setCallback(null)
        surfaceProducer?.release()
        surfaceProducer = null
        lastProducerWidth = -1
        lastProducerHeight = -1
    }

    private fun releaseAllInternal() {
        mainHandler.removeCallbacks(progressRunnable)
        releaseTextureInternal()
        player?.removeListener(playerListener)
        player?.release()
        player = null
        bufferProfileFastLive = false
        currentUri = null
        currentSubtitlePath = null
        userQualityMaxHeight = 0
        retryCount = 0
        leadingSilence.setDelayMs(0)
        trimming.setTrimFrameCount(0, 0)
    }

    private fun buildLoadControl(fastLive: Boolean): DefaultLoadControl {
        return if (fastLive) {
            // Weak TV / Chromecast: prioritize time-to-first-frame on live channel switches.
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    LIVE_FAST_MIN_BUFFER_MS,
                    LIVE_FAST_MAX_BUFFER_MS,
                    LIVE_FAST_PLAYBACK_START_MS,
                    LIVE_FAST_REBUFFER_MS,
                )
                .setPrioritizeTimeOverSizeThresholds(true)
                .build()
        } else {
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    VOD_MIN_BUFFER_MS,
                    VOD_MAX_BUFFER_MS,
                    PLAYBACK_START_MS,
                    VOD_REBUFFER_MS,
                )
                .setPrioritizeTimeOverSizeThresholds(true)
                .build()
        }
    }

    /** Release decoder only; keep [surfaceProducer] so Flutter texture id stays valid. */
    private fun releasePlayerKeepSurface() {
        cancelPendingRetry()
        player?.removeListener(playerListener)
        player?.release()
        player = null
    }

    private fun ensurePlayer(): ExoPlayer {
        if (player == null) {
            val loadControl = buildLoadControl(bufferProfileFastLive)
            val renderersFactory = TvMateRenderersFactory(context, leadingSilence, trimming)

            player = ExoPlayer.Builder(context)
                .setLoadControl(loadControl)
                .setRenderersFactory(renderersFactory)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_MEDIA)
                        .setContentType(C.CONTENT_TYPE_MOVIE)
                        .build(),
                    /* handleAudioFocus= */ true,
                )
                .setSeekBackIncrementMs(30_000)
                .setSeekForwardIncrementMs(30_000)
                .build()
                .apply {
                    addListener(playerListener)
                    setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)
                    // Prefer SurfaceView (Streamer 4K VOD path) if already bound;
                    // otherwise fall back to the Flutter SurfaceProducer.
                    val s = externalSurface ?: surfaceProducer?.surface
                    if (s != null) setVideoSurface(s)
                }
        }
        return player!!
    }

    /**
     * [Cue] has no start/end times in Media3 — timing is on [CueGroup.presentationTimeUs];
     * [Player.Listener.onCues] fires when active lines change; we forward plain text lines.
     */
    private fun buildCuesPayload(group: CueGroup): Map<String, Any?> {
        val lines = mutableListOf<String>()
        for (i in 0 until group.cues.size) {
            val cue = group.cues[i]
            val text = cue.text?.toString()?.trim()
            if (!text.isNullOrEmpty()) {
                lines.add(text)
            }
        }
        return mapOf("type" to "cues", "lines" to lines)
    }

    /**
     * [delayMs] positive = audio late (prepend silence); negative = audio early (trim start).
     * Uses 48 kHz to convert ms → trim frames before the decoder reports sample rate.
     */
    private fun applyAudioDelayMsInternal(delayMs: Int) {
        val d = delayMs.coerceIn(-10_000, 10_000)
        val trimFrames = if (d < 0) {
            Util.durationUsToSampleCount((-d).toLong() * 1000L, 48_000).toInt()
        } else {
            0
        }
        leadingSilence.setDelayMs(if (d > 0) d else 0)
        trimming.setTrimFrameCount(trimFrames, 0)
        // No offset change vs current routing — skip seek nudge (saves a double seek on every live zap).
        if (d == 0 && trimFrames == 0) return
        // seekTo(currentPosition) is often a no-op — processors won't reconfigure. Nudge + undo to flush.
        player?.let { pl ->
            if (pl.playbackState == Player.STATE_IDLE) return@let
            val pos = pl.currentPosition
            val dur = pl.duration
            val canForward = dur == C.TIME_UNSET || pos < dur - 15
            if (canForward) {
                pl.seekTo(pos + 10)
                mainHandler.post { pl.seekTo(pos) }
            } else if (pos > 15) {
                pl.seekTo(pos - 10)
                mainHandler.post { pl.seekTo(pos) }
            } else {
                pl.seekTo(pos)
            }
        }
    }

    private fun applyPlaybackAndAudioSync(speed: Float, delayMs: Int) {
        applyAudioDelayMsInternal(delayMs)
        val pl = player ?: return
        val clamped = speed.coerceIn(0.25f, 4f)
        pl.playbackParameters = PlaybackParameters(clamped, 1f)
    }

    /**
     * Re-apply [sessionPlaybackSpeed] without touching A/V [applyAudioDelayMsInternal] (avoids a
     * second seek nudge). Used after [Player.prepare] because Exo often clears parameters then.
     */
    private fun applySessionPlaybackParametersOnly() {
        val pl = player ?: return
        val s = sessionPlaybackSpeed.coerceIn(0.25f, 4f)
        pl.playbackParameters = PlaybackParameters(s, 1f)
    }

    private fun retryLoadSameUri() {
        val uri = currentUri ?: return
        val p = player ?: return
        p.setMediaItem(buildMediaItem(uri, currentSubtitlePath), true)
        p.playWhenReady = true
        p.prepare()
        mainHandler.post { applySessionPlaybackParametersOnly() }
    }

    private fun buildMediaItem(url: String, subtitlePath: String?): MediaItem {
        val trimmed = subtitlePath?.trim().orEmpty()
        if (trimmed.isEmpty()) {
            return MediaItem.fromUri(url)
        }
        val file = File(trimmed)
        if (!file.exists()) {
            return MediaItem.fromUri(url)
        }
        val pathForExo = pathForSideloadedSubtitleWithOffset(file, sessionSubtitleDelayMs)
        val subFile = File(pathForExo)
        if (!subFile.exists()) {
            return MediaItem.fromUri(url)
        }
        val subUri = Uri.fromFile(subFile)
        // Unique id so ExoPlayer always treats a new offset as a new text track.
        val subId = "tvmate_ext_sub_${sessionSubtitleDelayMs}_${subFile.absolutePath.hashCode()}"
        return MediaItem.Builder()
            .setUri(url)
            .setSubtitleConfigurations(
                listOf(
                    MediaItem.SubtitleConfiguration.Builder(subUri)
                        .setMimeType(MimeTypes.APPLICATION_SUBRIP)
                        .setLanguage("und")
                        .setId(subId)
                        .setSelectionFlags(C.SELECTION_FLAG_DEFAULT or C.SELECTION_FLAG_AUTOSELECT)
                        .build(),
                ),
            )
            .build()
    }

    /**
     * Media3 1.4 [MediaItem.SubtitleConfiguration.Builder] has no subtitle offset. For external SRT,
     * shift all cue times by [offsetMs] into a cache file and load that. Positive = show cues later.
     */
    private fun pathForSideloadedSubtitleWithOffset(source: File, offsetMs: Int): String {
        if (offsetMs == 0) return source.absolutePath
        val out = File(
            context.cacheDir,
            "tvmate_srt_off_${source.absolutePath.hashCode()}_$offsetMs.srt",
        )
        return try {
            var raw = source.readText(StandardCharsets.UTF_8)
            if (raw.isNotEmpty() && raw[0] == '\uFEFF') {
                raw = raw.substring(1)
            }
            out.writeText(shiftSrtTimestampsInPlace(raw, offsetMs), StandardCharsets.UTF_8)
            out.absolutePath
        } catch (_: Exception) {
            source.absolutePath
        }
    }

    private fun shiftSrtTimestampsInPlace(content: String, offsetMs: Int): String {
        if (offsetMs == 0) return content
        val lineSep = when {
            content.contains("\r\n") -> "\r\n"
            content.contains("\r") -> "\r"
            else -> "\n"
        }
        return content.split(Regex("\r\n|\n|\r")).joinToString(lineSep) { line ->
            shiftOneSrtTimingLineIfPresent(line, offsetMs)
        }
    }

    /**
     * SRT times may use [.,] before ms; some files use 1–3 digit ms. VTT settings may follow the end time.
     */
    private fun shiftOneSrtTimingLineIfPresent(line: String, offsetMs: Int): String {
        if (!line.contains("-->")) return line
        val parts = line.split(Regex("\\s*-->\\s*"), limit = 2)
        if (parts.size != 2) return line
        val left = parts[0].trim()
        val rightAll = parts[1].trim()
        val timeEnd = rightAll.indexOfFirst { it.isWhitespace() }
        val rightTime = if (timeEnd < 0) rightAll else rightAll.substring(0, timeEnd)
        val rightSuffix = if (timeEnd < 0) "" else rightAll.substring(timeEnd)
        val a = parseSrtTimeToMs(left) ?: return line
        val b = parseSrtTimeToMs(rightTime) ?: return line
        var sa = a + offsetMs.toLong()
        var sb = b + offsetMs.toLong()
        if (sa < 0L) sa = 0L
        if (sb < 0L) sb = 0L
        if (sb <= sa) sb = sa + 1L
        return "${msToSrtTimestamp(sa)} --> ${msToSrtTimestamp(sb)}$rightSuffix"
    }

    private val srtTimeToken = Regex("""^(\d{1,2}):(\d{2}):(\d{2})[.,](\d{1,3})$""")

    private fun parseSrtTimeToMs(token: String): Long? {
        val m = srtTimeToken.matchEntire(token.trim()) ?: return null
        val hh = m.groupValues[1].toLong()
        val mm = m.groupValues[2].toLong()
        val ss = m.groupValues[3].toLong()
        var frac = m.groupValues[4]
        if (frac.length < 3) {
            frac = frac.padEnd(3, '0')
        } else if (frac.length > 3) {
            frac = frac.substring(0, 3)
        }
        val msp = frac.toLong().coerceIn(0L, 999L)
        return hh * 3_600_000L + mm * 60_000L + ss * 1_000L + msp
    }

    private fun msToSrtTimestamp(totalMs: Long): String {
        var t = totalMs.coerceAtLeast(0L)
        val h = t / 3_600_000L
        t %= 3_600_000L
        val m = t / 60_000L
        t %= 60_000L
        val s = t / 1_000L
        val mil = t % 1_000L
        return String.format("%02d:%02d:%02d,%03d", h, m, s, mil)
    }

    private fun buildTracksSnapshot(): Map<String, Any> {
        val p = player
        if (p == null) {
            return mapOf(
                "audioTracks" to emptyList<Map<String, Any?>>(),
                "subtitleTracks" to emptyList<Map<String, Any?>>(),
                "videoHeights" to emptyList<Int>(),
            )
        }
        val tracks = p.currentTracks
        val audio = mutableListOf<Map<String, Any?>>()
        val subs = mutableListOf<Map<String, Any?>>()
        val videoHeights = mutableSetOf<Int>()
        for (gi in 0 until tracks.groups.size) {
            val group = tracks.groups[gi]
            when (group.type) {
                C.TRACK_TYPE_AUDIO -> addTrackFormats(audio, gi, "a", group)
                C.TRACK_TYPE_TEXT -> addTrackFormats(subs, gi, "t", group)
                C.TRACK_TYPE_VIDEO -> {
                    for (ti in 0 until group.length) {
                        val hh = group.getTrackFormat(ti).height
                        if (hh > 0) videoHeights.add(hh)
                    }
                }
            }
        }
        return mapOf(
            "audioTracks" to audio,
            "subtitleTracks" to subs,
            "videoHeights" to videoHeights.sortedDescending().toList(),
        )
    }

    private fun applyUserVideoQualityCap(p: ExoPlayer) {
        val b = p.trackSelectionParameters.buildUpon()
        if (userQualityMaxHeight > 0) {
            b.setMaxVideoSize(4096, userQualityMaxHeight)
                .setMaxVideoBitrate(Int.MAX_VALUE)
                .setMaxVideoFrameRate(Int.MAX_VALUE)
                .setForceLowestBitrate(false)
        } else {
            b.clearVideoSizeConstraints()
                .setMaxVideoBitrate(Int.MAX_VALUE)
                .setMaxVideoFrameRate(Int.MAX_VALUE)
                .setForceLowestBitrate(false)
        }
        p.trackSelectionParameters = b.build()
    }

    private fun addTrackFormats(
        out: MutableList<Map<String, Any?>>,
        groupIndex: Int,
        prefix: String,
        group: Tracks.Group,
    ) {
        for (ti in 0 until group.length) {
            val f = group.getTrackFormat(ti)
            out.add(trackMap("${prefix}_${groupIndex}_$ti", f))
        }
    }

    private fun trackMap(id: String, f: Format): Map<String, Any?> = mapOf(
        "id" to id,
        "label" to f.label,
        "language" to f.language,
    )

    /**
     * Size for aspect-ratio layout on Flutter: anamorphic PAR, then rotation (90/270 swap).
     */
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

    private fun maybeUpdateSurfaceProducerSize(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        if (width == lastProducerWidth && height == lastProducerHeight) return
        lastProducerWidth = width
        lastProducerHeight = height
        val prod = surfaceProducer ?: return
        prod.setSize(width, height)
        // Producer may replace the surface after resize; always re-attach for ExoPlayer
        // — unless the SurfaceView (Streamer 4K VOD) currently owns playback.
        if (externalSurface == null) {
            player?.setVideoSurface(prod.surface)
        }
    }

    private fun emitProgress(sink: EventChannel.EventSink) {
        val p = player ?: return
        val dur = p.duration
        val vf = p.videoFormat
        val (vw, vh) = displayVideoWidthHeight(vf)
        maybeUpdateSurfaceProducerSize(vw, vh)
        val br = vf?.bitrate?.takeIf { it > 0 } ?: -1
        sink.success(
            mapOf(
                "type" to "progress",
                "positionMs" to p.currentPosition,
                "bufferedMs" to p.bufferedPosition,
                "durationMs" to if (dur == C.TIME_UNSET) -1L else dur,
                "isPlaying" to p.isPlaying,
                "videoWidth" to vw,
                "videoHeight" to vh,
                "bitrate" to br,
            ),
        )
    }

    private fun safeEmit(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post {
            if (eventSink != null) {
                sink.success(payload)
            }
        }
    }

    private fun playbackStateToString(state: Int): String = when (state) {
        Player.STATE_IDLE -> "idle"
        Player.STATE_BUFFERING -> "buffering"
        Player.STATE_READY -> "ready"
        Player.STATE_ENDED -> "ended"
        else -> "unknown"
    }

    private fun positionMsFromCall(call: MethodCall): Long {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<*, *>
        val v = args?.get("positionMs") ?: return 0L
        return when (v) {
            is Int -> v.toLong()
            is Long -> v
            else -> 0L
        }
    }

    /**
     * Flutter [StandardMessageCodec] may send doubles as [Double] or whole numbers as [Int]; the
     * typed [MethodCall.argument] for [Double] returns null if the value was encoded as an int.
     */
    private fun floatArg(call: MethodCall, key: String, default: Float): Float {
        @Suppress("UNCHECKED_CAST")
        val m = call.arguments as? Map<*, *> ?: return default
        return when (val v = m[key]) {
            is Double -> v.toFloat()
            is Float -> v
            is Int -> v.toFloat()
            is Long -> v.toFloat()
            else -> default
        }
    }

    companion object {
        const val METHOD_CHANNEL = "com.tvmate.app/player"
        const val EVENT_CHANNEL = "com.tvmate.app/player_events"
        /** Stop after this many consecutive errors (3 playback attempts total). */
        private const val MAX_RETRIES = 3
        private const val RETRY_DELAY_MS = 900L
        private const val PROGRESS_MS = 250L
        private const val DEFAULT_SURFACE_WIDTH = 1920
        private const val DEFAULT_SURFACE_HEIGHT = 1080

        // Shared default: start playback after this much media is buffered.
        private const val PLAYBACK_START_MS = 250

        // Live fast-switch profile (weak / optimized / Chromecast): smaller targets → quicker zaps.
        // (Lower playback-start = faster first frame; slightly higher rebuffer risk on bad networks.)
        private const val LIVE_FAST_MIN_BUFFER_MS = 350
        private const val LIVE_FAST_MAX_BUFFER_MS = 10_000
        private const val LIVE_FAST_PLAYBACK_START_MS = 50
        private const val LIVE_FAST_REBUFFER_MS = 220

        // VOD / catch-up buffer profile — larger max buffer so forward seeks
        // within already-buffered data are instant (no network round-trip).
        private const val VOD_MIN_BUFFER_MS = 5_000    // 5s minimum rolling buffer
        private const val VOD_MAX_BUFFER_MS = 30_000   // buffer up to 30s ahead
        private const val VOD_REBUFFER_MS = 1_000      // resume after rebuffer at 1s
    }
}
