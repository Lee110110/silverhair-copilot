package com.silverhair.elderly_app.service

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class ScreenCaptureService : Service() {
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var isCapturing = false

    private val handler = Handler(Looper.getMainLooper())

    companion object {
        var isRunning = false
            private set
        var latestFrame: ByteArray? = null
            private set
        var resultCode: Int = 0
        var resultData: Intent? = null

        fun setProjectionParams(code: Int, data: Intent) {
            resultCode = code
            resultData = data
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> startCapture()
            "STOP" -> stopCapture()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopCapture()
        isRunning = false
        super.onDestroy()
    }

    @SuppressLint("WrongConstant")
    private fun startCapture() {
        if (isCapturing) return

        if (resultData == null) {
            stopSelf()
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(2, createNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(2, createNotification())
        }
        isRunning = true

        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        try {
            mediaProjection = projectionManager.getMediaProjection(resultCode, resultData!!)
        } catch (e: Exception) {
            stopSelf()
            return
        }

        // Android 14+ requires registering a callback before createVirtualDisplay
        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                if (isCapturing) {
                    stopCapture()
                    isRunning = false
                }
            }
        }, handler)

        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getMetrics(metrics)

        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null, handler
        )

        imageReader?.setOnImageAvailableListener({ reader ->
            val image: Image? = reader.acquireLatestImage()
            if (image != null) {
                try {
                    val frame = processImage(image, width, height)
                    if (frame != null) {
                        latestFrame = frame
                    }
                } catch (e: Exception) {
                    // Skip frame
                } finally {
                    image.close()
                }
            }
        }, handler)

        isCapturing = true
    }

    private fun processImage(image: Image, width: Int, height: Int): ByteArray? {
        val planes = image.planes
        if (planes.isEmpty()) return null

        val plane = planes[0]
        val buffer: ByteBuffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)

        if (rowStride == width * pixelStride) {
            buffer.rewind()
            bitmap.copyPixelsFromBuffer(buffer)
        } else {
            for (row in 0 until height) {
                buffer.position(row * rowStride)
                val rowBuffer = buffer.slice()
                rowBuffer.limit(width * pixelStride)
                bitmap.copyPixelsFromBuffer(rowBuffer)
            }
        }

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 60, outputStream)
        val jpegBytes = outputStream.toByteArray()
        bitmap.recycle()

        return jpegBytes
    }

    private fun stopCapture() {
        if (!isCapturing) return
        isCapturing = false
        virtualDisplay?.release()
        imageReader?.close()
        imageReader = null
        virtualDisplay = null
        latestFrame = null
        mediaProjection?.stop()
        mediaProjection = null
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun createNotification(): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "screen_capture_channel")
                .setContentTitle("银发陪驾")
                .setContentText("正在共享屏幕给子女")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("银发陪驾")
                .setContentText("正在共享屏幕给子女")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setOngoing(true)
                .build()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "screen_capture_channel",
                "屏幕共享服务",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "保持屏幕共享运行"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}