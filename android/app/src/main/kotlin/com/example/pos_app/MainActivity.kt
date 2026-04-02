package com.example.pos_app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "android_intent_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // � Save file to public Downloads folder (Android 10+)
                "saveFileToPublicDownloads" -> {
                    try {
                        val fileName = call.argument<String>("fileName") ?: ""
                        val fileBytes = call.argument<ByteArray>("fileBytes") ?: ByteArray(0)

                        if (fileName.isEmpty() || fileBytes.isEmpty()) {
                            result.error("INVALID_ARGS", "File name and content are required", null)
                            return@setMethodCallHandler
                        }

                        // For Android 10+ (API 29+), use MediaStore API
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val uri = saveToMediaStore(fileName, fileBytes)
                            if (uri != null) {
                                // Return the URI path for the saved file
                                val downloadDir = "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}"
                                val filePath = "$downloadDir/$fileName"
                                result.success(filePath)
                            } else {
                                result.error("SAVE_FAILED", "Failed to save file to Downloads", null)
                            }
                        } else {
                            // For older API levels, try direct file writing
                            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                            if (!downloadsDir.exists()) {
                                downloadsDir.mkdirs()
                            }

                            val file = File(downloadsDir, fileName)
                            try {
                                FileOutputStream(file).use {
                                    it.write(fileBytes)
                                    it.flush()
                                }
                                result.success(file.absolutePath)
                            } catch (e: Exception) {
                                result.error("SAVE_FAILED", "Failed to save file: ${e.message}", null)
                            }
                        }
                    } catch (e: Exception) {
                        result.error("EXCEPTION", "Error saving file: ${e.message}", e.toString())
                    }
                }
                // 📋 Check if app has permission to access Downloads folder
                "hasDownloadsFolderPermission" -> {
                    try {
                        // Try to test write access to Downloads
                        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        val testFile = File(downloadsDir, ".permission_test")
                        
                        val hasPermission = try {
                            // Try to create and delete a test file
                            if (!downloadsDir.exists()) {
                                downloadsDir.mkdirs()
                            }
                            testFile.createNewFile()
                            testFile.delete()
                            true
                        } catch (e: Exception) {
                            false
                        }
                        
                        result.success(hasPermission)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", "Error checking permission: ${e.message}", null)
                    }
                }

                // ⚙️ Open Settings to grant MANAGE_EXTERNAL_STORAGE permission
                "openStoragePermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            // Android 11+: Open app permissions settings
                            val intent = Intent(
                                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            // Android 6.0 - 10: Open app permissions settings
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", "Error opening settings: ${e.message}", null)
                    }
                }
                // �🔋 Check Battery Optimization
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

    /// Save file to MediaStore (Android 10+)
    /// This properly handles scoped storage and grants persistent access to Downloads folder
    private fun saveToMediaStore(fileName: String, fileBytes: ByteArray): Uri? {
        return try {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                // Mark as pending to hide while writing
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }

            val uri = contentResolver.insert(MediaStore.Files.getContentUri("external"), contentValues)
            if (uri != null) {
                try {
                    contentResolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(fileBytes)
                        outputStream.flush()
                    }

                    // Mark as complete (no longer pending)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val updateValues = ContentValues().apply {
                            put(MediaStore.MediaColumns.IS_PENDING, 0)
                        }
                        contentResolver.update(uri, updateValues, null, null)
                    }

                    return uri
                } catch (e: Exception) {
                    // Clean up failed file
                    try {
                        contentResolver.delete(uri, null, null)
                    } catch (e2: Exception) {
                        // Ignore cleanup errors
                    }
                    throw e
                }
            }
            null
        } catch (e: Exception) {
            println("MediaStore Error: ${e.message}")
            null
        }
    }
}

/*package com.example.pos_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
*/