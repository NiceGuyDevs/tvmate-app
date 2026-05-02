package com.tvmate.app

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import java.util.Locale
import java.util.TimeZone
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal class DeviceInfoChannel(
    private val activity: android.app.Activity,
    engine: FlutterEngine,
    private val onPrepareForTextInput: () -> Unit = {},
) {
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "com.tvmate.app/device",
    )

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getTotalRamMb" -> {
                    try {
                        val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val mi = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(mi)
                        val mb = (mi.totalMem / (1024L * 1024L)).toInt()
                        result.success(mb)
                    } catch (e: Exception) {
                        result.error("ram_error", e.message, null)
                    }
                }
                "requestShowSoftInput" -> {
                    try {
                        val imm = activity.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                        val v = activity.currentFocus
                        if (v != null) {
                            imm.showSoftInput(v, InputMethodManager.SHOW_IMPLICIT)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("ime_show", e.message, null)
                    }
                }
                "prepareForTextInput" -> {
                    try {
                        onPrepareForTextInput()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("prep", e.message, null)
                    }
                }
                "getTvTextInputProfile" -> {
                    val model = Build.MODEL.lowercase(Locale.US)
                    val product = Build.PRODUCT.lowercase(Locale.US)
                    val device = Build.DEVICE.lowercase(Locale.US)
                    val chromecastLike =
                        model.contains("chromecast") ||
                            product.contains("chromecast") ||
                            device.contains("chromecast")
                    result.success(if (chromecastLike) "inAppPad" else "fullIme")
                }
                "isGoogleTvStreamer" -> {
                    // Detect the Google TV Streamer 4K (MediaTek MT8696). On this
                    // device the MediaCodec emits a vendor-private 10-bit YUV format
                    // (0x7FA30C01) that the Flutter SurfaceProducer cannot sample —
                    // the frame comes out solid green. Flutter takes a different
                    // rendering path (native SurfaceView) for VOD only when this
                    // returns true.
                    result.success(isGoogleTvStreamerDevice())
                }
                "setKeepScreenOn" -> {
                    val on = call.arguments == true
                    activity.runOnUiThread {
                        try {
                            if (on) {
                                activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("keep_screen", e.message, null)
                        }
                    }
                }
                "getAndroidId" -> {
                    try {
                        val androidId = Settings.Secure.getString(
                            activity.contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId ?: "")
                    } catch (e: Exception) {
                        result.error("android_id_error", e.message, null)
                    }
                }
                "getFullDeviceInfo" -> {
                    try {
                        val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val mi = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(mi)
                        val ramMb = (mi.totalMem / (1024L * 1024L)).toInt()

                        val dm = DisplayMetrics()
                        @Suppress("DEPRECATION")
                        (activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                            .defaultDisplay.getRealMetrics(dm)

                        val isAndroidTv = activity.packageManager
                            .hasSystemFeature(PackageManager.FEATURE_LEANBACK)

                        val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        val net = cm?.activeNetwork
                        val caps = if (net != null) cm.getNetworkCapabilities(net) else null
                        val networkType = when {
                            caps == null -> "none"
                            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                            else -> "other"
                        }

                        val pInfo = try {
                            activity.packageManager.getPackageInfo(activity.packageName, 0)
                        } catch (_: Exception) { null }

                        val info = HashMap<String, Any?>()
                        info["manufacturer"] = Build.MANUFACTURER
                        info["model"] = Build.MODEL
                        info["product"] = Build.PRODUCT
                        info["device"] = Build.DEVICE
                        info["board"] = Build.BOARD
                        info["hardware"] = Build.HARDWARE
                        info["androidVersion"] = Build.VERSION.RELEASE
                        info["apiLevel"] = Build.VERSION.SDK_INT
                        info["buildFingerprint"] = Build.FINGERPRINT
                        info["securityPatch"] = if (Build.VERSION.SDK_INT >= 23) Build.VERSION.SECURITY_PATCH else null
                        info["isAndroidTv"] = isAndroidTv
                        info["ramMb"] = ramMb
                        info["screenWidth"] = dm.widthPixels
                        info["screenHeight"] = dm.heightPixels
                        info["screenDensity"] = dm.densityDpi
                        info["locale"] = Locale.getDefault().toString()
                        info["language"] = Locale.getDefault().language
                        info["timezone"] = TimeZone.getDefault().id
                        info["networkType"] = networkType
                        info["appVersion"] = pInfo?.versionName
                        info["appBuildNumber"] = if (Build.VERSION.SDK_INT >= 28) pInfo?.longVersionCode?.toInt() else @Suppress("DEPRECATION") pInfo?.versionCode
                        info["firstInstallTime"] = pInfo?.firstInstallTime
                        info["lastUpdateTime"] = pInfo?.lastUpdateTime

                        result.success(info)
                    } catch (e: Exception) {
                        result.error("device_info_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onImeVisibilityChanged(visible: Boolean) {
        if (ImeVisibilityState.visible == visible) return
        ImeVisibilityState.visible = visible
        channel.invokeMethod("imeVisibility", visible)
    }

    companion object {
        /**
         * Conservative Google TV Streamer 4K detection: manufacturer must be Google
         * AND one of the device identifier fields must contain "streamer". Other
         * Google TV boxes (Chromecast with Google TV, etc.) are explicitly not
         * matched — the green-screen is specific to this unit's MediaTek decoder.
         */
        fun isGoogleTvStreamerDevice(): Boolean {
            val manufacturer = Build.MANUFACTURER.lowercase(Locale.US)
            val brand = Build.BRAND.lowercase(Locale.US)
            if (manufacturer != "google" && brand != "google") return false
            val model = Build.MODEL.lowercase(Locale.US)
            val product = Build.PRODUCT.lowercase(Locale.US)
            val device = Build.DEVICE.lowercase(Locale.US)
            return model.contains("streamer") ||
                product.contains("streamer") ||
                device.contains("streamer")
        }
    }
}

internal object ImeVisibilityState {
    @Volatile
    var visible: Boolean = false
}
