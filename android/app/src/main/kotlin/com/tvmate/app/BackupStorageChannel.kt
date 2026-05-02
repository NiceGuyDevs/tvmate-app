package com.tvmate.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Platform channel that gives Flutter access to the real public external
 * storage path for backups, surviving app uninstalls.
 *
 * Channel: `com.tvmate.app/backup_storage`
 *
 * Methods:
 *  - `getPublicBackupDir`  → String (absolute path to Download/TVMatePro)
 *  - `ensureStoragePermission` → bool (true if granted)
 */
class BackupStorageChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "com.tvmate.app/backup_storage"
        private const val REQ_STORAGE = 9001
        private const val BACKUP_FOLDER = "TVMatePro"
    }

    private var pendingResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPublicBackupDir" -> {
                val dir = resolvePublicDir()
                if (dir != null) {
                    result.success(dir.absolutePath)
                } else {
                    result.error("NO_DIR", "Cannot resolve public Downloads", null)
                }
            }
            "ensureStoragePermission" -> {
                if (hasStorageAccess()) {
                    result.success(true)
                } else {
                    pendingResult = result
                    requestStorageAccess()
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Called from Activity.onRequestPermissionsResult */
    fun onPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode == REQ_STORAGE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            pendingResult = null
        }
    }

    /** Called from Activity.onActivityResult for MANAGE_EXTERNAL_STORAGE flow */
    fun onActivityResult(requestCode: Int) {
        if (requestCode == REQ_STORAGE) {
            pendingResult?.success(hasStorageAccess())
            pendingResult = null
        }
    }

    private fun resolvePublicDir(): File? {
        return try {
            @Suppress("DEPRECATION")
            val dl = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val dir = File(dl, BACKUP_FOLDER)
            if (!dir.exists()) dir.mkdirs()
            if (dir.exists() && dir.canWrite()) dir else null
        } catch (_: Exception) {
            null
        }
    }

    private fun hasStorageAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                activity, Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStorageAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                    data = Uri.parse("package:${activity.packageName}")
                }
                activity.startActivityForResult(intent, REQ_STORAGE)
            } catch (_: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                activity.startActivityForResult(intent, REQ_STORAGE)
            }
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ),
                REQ_STORAGE
            )
        }
    }
}
