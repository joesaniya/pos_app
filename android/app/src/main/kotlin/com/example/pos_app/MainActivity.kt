package com.example.pos_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "android_intent_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // 🔋 Check Battery Optimization
                "isBatteryOptimizationDisabled" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val ignored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignored)
                }

                // 🔓 Open Battery Optimization Settings
                "openBatteryOptimizationSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
                            startActivity(intent)
                            result.success(false)
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
                    }
                }

                // ⏰ Open Exact Alarm Settings (Android 12+)
                "openAlarmSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                // ✅ Check Exact Alarm Permission
                "isExactAlarmGranted" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                        am.canScheduleExactAlarms()
                    } else {
                        true
                    }
                    result.success(granted)
                }

                else -> result.notImplemented()
            }
        }
    }
}

/*package com.example.pos_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
*/