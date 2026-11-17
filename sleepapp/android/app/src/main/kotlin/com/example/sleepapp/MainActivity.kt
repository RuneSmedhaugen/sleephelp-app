package com.example.sleepapp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rest/alarms")
            .setMethodCallHandler { call, result ->
                val alarms = WakeAlarms(this)
                try {
                    when (call.method) {
                        "status" -> result.success(alarms.status())
                        "save" -> {
                            alarms.save(
                                call.argument<String>("id"),
                                requireNotNull(call.argument<Int>("hour")),
                                requireNotNull(call.argument<Int>("minute")),
                                requireNotNull(call.argument<List<Int>>("days")),
                                requireNotNull(call.argument<Boolean>("enabled")),
                                call.argument<Int>("finishBeforeMinutes"),
                                call.argument<Int>("fadeMinutes")
                            )
                            result.success(null)
                        }
                        "delete", "stop", "snooze" -> {
                            val id = requireNotNull(call.argument<String>("id"))
                            when (call.method) {
                                "delete" -> alarms.delete(id)
                                "stop" -> alarms.stop(id)
                                "snooze" -> alarms.snooze(id)
                            }
                            result.success(null)
                        }
                        "allow" -> {
                            val packageUri = Uri.parse("package:$packageName")
                            when (call.argument<String>("permission")) {
                                "exact" -> if (Build.VERSION.SDK_INT >= 31) {
                                    startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri))
                                }
                                "notifications" -> if (Build.VERSION.SDK_INT >= 33 &&
                                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                                ) {
                                    if (!getPreferences(MODE_PRIVATE).getBoolean("askedForAlarmNotifications", false) ||
                                        shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
                                    ) {
                                        getPreferences(MODE_PRIVATE).edit()
                                            .putBoolean("askedForAlarmNotifications", true).apply()
                                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                                    } else {
                                        openAlarmNotifications()
                                    }
                                } else {
                                    openAlarmNotifications()
                                }
                                "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) {
                                    startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, packageUri))
                                }
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("alarm", error.message ?: "Could not update the alarm.", null)
                }
            }
    }

    private fun openAlarmNotifications() {
        if (Build.VERSION.SDK_INT >= 26) {
            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
        } else {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        }
    }
}
