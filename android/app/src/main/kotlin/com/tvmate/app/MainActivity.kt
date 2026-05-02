package com.tvmate.app

import android.graphics.Rect
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var nativePlayer: NativeExoPlayerSession? = null
    private var livePreview: NativeLivePreviewSession? = null
    private var playerPool: NativePlayerPool? = null
    private var backupStorage: BackupStorageChannel? = null
    private var deviceInfoChannel: DeviceInfoChannel? = null

    /** IME from [WindowInsetsCompat] — reliable on many devices, not all (e.g. some Chromecast builds). */
    private var imeVisibleFromInsets: Boolean = false

    /**
     * IME from visible display frame vs root height — catches on-screen keyboards that do not
     * set IME insets (common on Google TV / Chromecast when Flutter still steals D-pad).
     */
    private var imeVisibleFromLayout: Boolean = false

    override fun onPause() {
        nativePlayer?.stopForActivityPause()
        livePreview?.stopForActivityPause()
        playerPool?.stopForActivityPause()
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativePlayer = NativeExoPlayerSession(this, flutterEngine).also {
            it.registerChannels(flutterEngine.dartExecutor.binaryMessenger)
        }
        // SurfaceView platform view for VOD — mounted by Dart only on the Google
        // TV Streamer 4K (see DeviceInfoChannel.isGoogleTvStreamerDevice). Registered
        // on every device since registration alone is inert.
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                TvMateVodSurfaceViewFactory.VIEW_TYPE,
                TvMateVodSurfaceViewFactory(nativePlayer!!),
            )
        livePreview = NativeLivePreviewSession(this, flutterEngine).also {
            it.registerChannels(flutterEngine.dartExecutor.binaryMessenger)
        }
        // Same SurfaceView fix wired to the hero live preview session (also
        // Streamer 4K only — see Dart HeroLivePreview widget).
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                TvMateLivePreviewSurfaceViewFactory.VIEW_TYPE,
                TvMateLivePreviewSurfaceViewFactory(livePreview!!),
            )
        playerPool = NativePlayerPool(this, flutterEngine).also {
            it.registerChannels(flutterEngine.dartExecutor.binaryMessenger)
        }
        backupStorage = BackupStorageChannel(this).also {
            it.register(flutterEngine.dartExecutor.binaryMessenger)
        }
        deviceInfoChannel = DeviceInfoChannel(this, flutterEngine) {
            nativePlayer?.stopForActivityPause()
            livePreview?.stopForActivityPause()
            playerPool?.stopForActivityPause()
        }
        installImeVisibilityTracking()
    }

    /**
     * Notifies Dart when the soft keyboard is likely shown so [HardwareKeyboard] handlers can
     * yield D-pad to the IME. Uses **two** signals: window IME insets + layout height delta
     * ([getWindowVisibleDisplayFrame] vs root height) for devices where insets lie.
     */
    private fun installImeVisibilityTracking() {
        val decor = window.decorView

        // AndroidX passes [WindowInsetsCompat] here, not [android.view.WindowInsets].
        ViewCompat.setOnApplyWindowInsetsListener(decor) { v, insets ->
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            imeVisibleFromInsets =
                insets.isVisible(WindowInsetsCompat.Type.ime()) || ime.bottom > 0
            pushCombinedImeVisibleToFlutter()
            ViewCompat.onApplyWindowInsets(v, insets)
        }

        decor.viewTreeObserver.addOnGlobalLayoutListener {
            val rect = Rect()
            decor.getWindowVisibleDisplayFrame(rect)
            val screenH = decor.rootView.height
            if (screenH <= 0) return@addOnGlobalLayoutListener
            val heightDiff = screenH - rect.bottom
            val threshold = (screenH * 0.12f).toInt().coerceIn(80, 480)
            imeVisibleFromLayout = heightDiff > threshold
            pushCombinedImeVisibleToFlutter()
        }
    }

    private fun pushCombinedImeVisibleToFlutter() {
        val open = imeVisibleFromInsets || imeVisibleFromLayout
        deviceInfoChannel?.onImeVisibilityChanged(open)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        backupStorage?.onPermissionsResult(requestCode, grantResults)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        backupStorage?.onActivityResult(requestCode)
    }
}
