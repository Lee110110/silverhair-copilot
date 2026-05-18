package com.silverhair.elderly_app.platform

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.silverhair.elderly_app.service.ScreenCaptureService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ScreenCapturePlugin private constructor() {
    companion object {
        private const val TAG = "ScreenCapture"
        private const val METHOD_CHANNEL = "screen_capture"
        private const val EVENT_CHANNEL = "screen_capture_frames"
        const val SCREEN_CAPTURE_REQUEST_CODE = 2001

        internal var eventSink: EventChannel.EventSink? = null
        internal var pendingResult: MethodChannel.Result? = null
        private var handler: Handler? = null
        private var frameRunnable: Runnable? = null

        fun registerWith(engine: FlutterEngine, activity: Activity) {
            MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
                .setMethodCallHandler(ScreenCaptureMethodHandler(activity))

            EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
                .setStreamHandler(FrameStreamHandler())
        }

        fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
            if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    Log.d(TAG, "MediaProjection permission granted")
                    ScreenCaptureService.setProjectionParams(resultCode, data)
                    val startIntent = Intent(
                        com.silverhair.elderly_app.ElderlyApp.applicationContext(),
                        ScreenCaptureService::class.java
                    )
                    startIntent.action = "START"
                    val context = com.silverhair.elderly_app.ElderlyApp.applicationContext()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(startIntent)
                    } else {
                        context.startService(startIntent)
                    }
                    pendingResult?.success(true)
                } else {
                    Log.w(TAG, "MediaProjection permission denied")
                    pendingResult?.success(false)
                }
                pendingResult = null
            }
        }

        fun startFramePolling() {
            handler = Handler(Looper.getMainLooper())
            frameRunnable = object : Runnable {
                override fun run() {
                    val frame = ScreenCaptureService.latestFrame
                    if (frame != null && eventSink != null) {
                        try {
                            eventSink!!.success(frame)
                        } catch (e: Exception) {
                            Log.w(TAG, "EventSink error", e)
                        }
                    }
                    handler?.postDelayed(this, 500) // 2 fps polling
                }
            }
            handler?.post(frameRunnable!!)
            Log.d(TAG, "Frame polling started")
        }

        fun stopFramePolling() {
            frameRunnable?.let { handler?.removeCallbacks(it) }
            handler = null
            frameRunnable = null
            Log.d(TAG, "Frame polling stopped")
        }
    }
}

class ScreenCaptureMethodHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startCapture" -> {
                // If capture service is already running, return true immediately
                if (ScreenCaptureService.isRunning) {
                    result.success(true)
                } else {
                    ScreenCapturePlugin.pendingResult = result
                    requestScreenCapturePermission()
                }
            }
            "stopCapture" -> {
                val intent = Intent(activity, ScreenCaptureService::class.java)
                intent.action = "STOP"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }
                ScreenCapturePlugin.stopFramePolling()
                result.success(true)
            }
            "isCapturing" -> {
                result.success(ScreenCaptureService.isRunning)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestScreenCapturePermission() {
        val projectionManager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = projectionManager.createScreenCaptureIntent()
        activity.startActivityForResult(intent, ScreenCapturePlugin.SCREEN_CAPTURE_REQUEST_CODE)
    }
}

class FrameStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        ScreenCapturePlugin.eventSink = sink
        ScreenCapturePlugin.startFramePolling()
    }

    override fun onCancel(arguments: Any?) {
        ScreenCapturePlugin.eventSink = null
        ScreenCapturePlugin.stopFramePolling()
    }
}
