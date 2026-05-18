package com.silverhair.elderly_app.service

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import com.silverhair.elderly_app.MainActivity
import com.silverhair.elderly_app.R

class FloatingOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var sosView: View? = null
    private var annotationView: View? = null
    private var isShowing = false

    companion object {
        private const val TAG = "FloatingOverlay"
        var isRunning = false
            private set
        private var currentStatus = "idle"

        fun updateStatus(status: String) {
            currentStatus = status
        }

        /** Reset state — call when service is confirmed dead but static flag is stale */
        fun resetState() {
            isRunning = false
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        Log.d(TAG, "onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand action=${intent?.action}")
        when (intent?.action) {
            "SHOW" -> showSosOverlay()
            "HIDE" -> hideOverlay()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        hideOverlay()
        isRunning = false
        super.onDestroy()
        Log.d(TAG, "onDestroy")
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showSosOverlay() {
        if (isShowing) {
            Log.d(TAG, "showSosOverlay: already showing, skip")
            return
        }

        // Check overlay permission before proceeding
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!android.provider.Settings.canDrawOverlays(this)) {
                Log.e(TAG, "showSosOverlay: SYSTEM_ALERT_WINDOW permission not granted!")
                isRunning = false
                stopSelf()
                return
            }
        }

        try {
            startForeground(1, createNotification())
        } catch (e: Exception) {
            Log.e(TAG, "showSosOverlay: startForeground failed", e)
            isRunning = false
            stopSelf()
            return
        }

        isRunning = true

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER_VERTICAL or Gravity.END
            x = 0
            y = 0
        }

        try {
            // Create SOS button
            sosView = createSosButton()
            windowManager?.addView(sosView, params)
            Log.d(TAG, "showSosOverlay: SOS button added to window")
        } catch (e: Exception) {
            Log.e(TAG, "showSosOverlay: addView SOS failed", e)
            isRunning = false
            isShowing = false
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        try {
            // Create annotation overlay layer (initially hidden)
            val annotationParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            )

            annotationView = FrameLayout(this).apply { visibility = View.GONE }
            windowManager?.addView(annotationView, annotationParams)
            Log.d(TAG, "showSosOverlay: annotation overlay added")
        } catch (e: Exception) {
            Log.e(TAG, "showSosOverlay: addView annotation failed (non-fatal)", e)
            // Annotation overlay is optional, continue
        }

        isShowing = true
        setupDragBehavior(params)
    }

    private fun hideOverlay() {
        try {
            sosView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.w(TAG, "hideOverlay: removeView sosView failed", e)
        }
        try {
            annotationView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.w(TAG, "hideOverlay: removeView annotationView failed", e)
        }
        sosView = null
        annotationView = null
        isShowing = false
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.w(TAG, "hideOverlay: stopForeground failed", e)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupDragBehavior(params: WindowManager.LayoutParams) {
        val view = sosView ?: return
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        isDragging = true
                        params.x = initialX - dx.toInt()
                        params.y = initialY - dy.toInt()
                        windowManager?.updateViewLayout(view, params)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        onSosClicked()
                    }
                }
            }
            true
        }
    }

    private fun onSosClicked() {
        Log.d(TAG, "onSosClicked")
        // Notify Flutter via method channel to trigger SOS API call
        val engine = com.silverhair.elderly_app.ElderlyApp.flutterEngine
        if (engine != null) {
            val channel = io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "overlay_service")
            channel.invokeMethod("onSosClicked", null)
        } else {
            Log.w(TAG, "onSosClicked: flutterEngine is null, cannot notify Flutter")
        }

        // Visual feedback - pulse the button
        sosView?.let { view ->
            view.animate().scaleX(1.2f).scaleY(1.2f).setDuration(150)
                .withEndAction {
                    view.animate().scaleX(1f).scaleY(1f).setDuration(150).start()
                }.start()
        }
    }

    private fun createSosButton(): View {
        val container = FrameLayout(this)

        val button = TextView(this).apply {
            text = "SOS"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 18f
            gravity = Gravity.CENTER
            setBackgroundColor(android.graphics.Color.parseColor("#E53935"))
            val size = (72 * resources.displayMetrics.density).toInt()
            layoutParams = FrameLayout.LayoutParams(size, size)
        }

        // Make it circular
        button.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: View, outline: android.graphics.Outline) {
                val size = Math.min(view.width, view.height)
                outline.setOval(0, 0, size, size)
            }
        }
        button.clipToOutline = true

        // Add elevation/shadow
        button.elevation = 8f * resources.displayMetrics.density

        container.addView(button)
        val size = (80 * resources.displayMetrics.density).toInt()
        container.layoutParams = FrameLayout.LayoutParams(size, size)

        return container
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "sos_overlay_channel")
                .setContentTitle("银发陪驾")
                .setContentText("SOS守护已开启")
                .setSmallIcon(android.R.drawable.ic_menu_info_details)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("银发陪驾")
                .setContentText("SOS守护已开启")
                .setSmallIcon(android.R.drawable.ic_menu_info_details)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "sos_overlay_channel",
                "SOS守护服务",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "保持SOS浮窗按钮运行"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
