package com.dailymotion.training.daily_motion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.content.pm.ApplicationInfo
import java.util.UUID
import java.io.File

class MainActivity : FlutterActivity() {
    private val processContinuity = "process:" + UUID.randomUUID().toString()
    private val installationContinuity by lazy {
        try {
            val file = File(noBackupFilesDir, "timer-installation")
            if (file.exists()) UUID.fromString(file.readText().trim()).toString() else {
                UUID.randomUUID().toString().also { file.writeText(it) }
            }
        } catch (_: Exception) { processContinuity }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val continuity = installationContinuity // Resolve storage before any set-save call.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily_motion/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clock" -> {
                        val boot = Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1)
                        result.success(mapOf(
                            "wall_ms" to System.currentTimeMillis(),
                            "elapsed_us" to SystemClock.elapsedRealtimeNanos() / 1000,
                            "continuity_id" to if (boot >= 0) "android:$continuity:$boot" else processContinuity
                        ))
                    }
                    "device" -> {
                        val emulator = Build.FINGERPRINT.startsWith("generic") ||
                            Build.FINGERPRINT.contains("emulator") || Build.MODEL.contains("Emulator") ||
                            Build.MODEL.contains("sdk_gphone") || Build.PRODUCT.contains("sdk") ||
                            Build.HARDWARE in listOf("goldfish", "ranchu")
                        result.success(mapOf(
                            "platform" to "android", "model" to Build.MODEL,
                            "os" to Build.VERSION.RELEASE, "api" to Build.VERSION.SDK_INT,
                            "physical" to !emulator, "source" to "android-native",
                            "backup_allowed" to (applicationInfo.flags and ApplicationInfo.FLAG_ALLOW_BACKUP != 0)
                        ))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
