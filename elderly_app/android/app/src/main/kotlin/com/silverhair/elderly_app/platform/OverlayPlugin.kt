package com.silverhair.elderly_app.platform

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class OverlayPlugin private constructor() {
    companion object {
        internal const val TAG = "OverlayPlugin"
        private const val CHANNEL = "overlay_service"
        const val OVERLAY_REQUEST_CODE = 1001
        internal var pendingResult: MethodChannel.Result? = null

        fun registerWith(engine: FlutterEngine, activity: Activity) {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(OverlayMethodHandler(activity))
        }
    }
}

class OverlayMethodHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> {
                val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(activity)
                } else {
                    true
                }
                result.success(hasPermission)
            }
            "requestPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (!Settings.canDrawOverlays(activity)) {
                        OverlayPlugin.pendingResult = result
                        // Use app details page instead of ACTION_MANAGE_OVERLAY_PERMISSION
                        // MIUI doesn't properly handle the standard overlay permission intent
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:${activity.packageName}")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            activity.startActivity(intent)
                        } catch (e: Exception) {
                            Log.e(OverlayPlugin.TAG, "Failed to open app settings", e)
                            // Fallback to standard overlay permission page
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:${activity.packageName}")
                                )
                                activity.startActivity(intent)
                            } catch (e2: Exception) {
                                Log.e(OverlayPlugin.TAG, "Failed to open overlay settings", e2)
                                result.success(false)
                                OverlayPlugin.pendingResult = null
                            }
                        }
                    } else {
                        result.success(true)
                    }
                } else {
                    result.success(true)
                }
            }
            "showOverlay" -> {
                val intent = Intent(activity, com.silverhair.elderly_app.service.FloatingOverlayService::class.java)
                intent.action = "SHOW"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }
                result.success(true)
            }
            "hideOverlay" -> {
                val intent = Intent(activity, com.silverhair.elderly_app.service.FloatingOverlayService::class.java)
                intent.action = "HIDE"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }
                result.success(true)
            }
            "isOverlayActive" -> {
                result.success(com.silverhair.elderly_app.service.FloatingOverlayService.isRunning)
            }
            "updateSosStatus" -> {
                val status = call.argument<String>("status") ?: "idle"
                com.silverhair.elderly_app.service.FloatingOverlayService.updateStatus(status)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
