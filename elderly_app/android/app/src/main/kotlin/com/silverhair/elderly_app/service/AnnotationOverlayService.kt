package com.silverhair.elderly_app.service

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import org.json.JSONArray
import org.json.JSONObject

class AnnotationOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: AnnotationOverlayView? = null
    private var isShowing = false
    private val handler = Handler(Looper.getMainLooper())

    // Auto-fade runnable for annotations
    private var fadeRunnable: Runnable? = null

    companion object {
        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "SHOW" -> showOverlay()
            "HIDE" -> hideOverlay()
            "RENDER" -> {
                val type = intent.getStringExtra("type") ?: ""
                val payloadJson = intent.getStringExtra("payload") ?: "{}"
                if (!isShowing) showOverlay()
                renderAnnotation(type, payloadJson)
            }
            "CLEAR" -> clearAnnotations()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        hideOverlay()
        isRunning = false
        super.onDestroy()
    }

    @SuppressLint("WrongConstant")
    private fun showOverlay() {
        if (isShowing) return
        isRunning = true

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        overlayView = AnnotationOverlayView(this)
        windowManager?.addView(overlayView, params)
        isShowing = true
    }

    private fun hideOverlay() {
        overlayView?.let { windowManager?.removeView(it) }
        overlayView = null
        isShowing = false
        fadeRunnable?.let { handler.removeCallbacks(it) }
    }

    private fun renderAnnotation(type: String, payloadJson: String) {
        val view = overlayView ?: return
        try {
            val payload = JSONObject(payloadJson)

            when (type) {
                "annotation.start" -> {
                    val tool = payload.optString("tool", "arrow")
                    val color = payload.optString("color", "#FF0000")
                    view.startAnnotation(tool, color)
                }
                "annotation.stroke" -> {
                    val points = payload.optJSONArray("points") ?: JSONArray()
                    view.addStrokePoints(points)
                }
                "annotation.end" -> {
                    view.endAnnotation()
                    scheduleAutoFade()
                }
                "annotation.clear" -> {
                    view.clearAll()
                }
                "annotation.clear_all" -> {
                    view.clearAll()
                }
            }

            view.invalidate()

        } catch (e: Exception) {
            // Parse error, skip
        }
    }

    private fun clearAnnotations() {
        overlayView?.clearAll()
        overlayView?.invalidate()
    }

    private fun scheduleAutoFade() {
        fadeRunnable?.let { handler.removeCallbacks(it) }
        fadeRunnable = Runnable {
            overlayView?.fadeOut()
        }
        handler.postDelayed(fadeRunnable!!, 10000) // 10 seconds auto-fade
    }


    class AnnotationOverlayView(context: Context) : View(context) {
        private val annotations = mutableListOf<Annotation>()
        private var currentAnnotation: Annotation? = null
        private var fadeAlpha = 255

        private val arrowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 6f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        private val circlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 6f
        }

        private val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 48f
            style = Paint.Style.FILL
        }

        data class Annotation(
            val tool: String,     // arrow | circle | highlight | text
            val color: String,
            val points: MutableList<Pair<Float, Float>> = mutableListOf(),
            var isComplete: Boolean = false
        )

        fun startAnnotation(tool: String, color: String) {
            currentAnnotation = Annotation(tool = tool, color = color)
            fadeAlpha = 255
        }

        fun addStrokePoints(pointsJson: JSONArray) {
            val ann = currentAnnotation ?: return
            for (i in 0 until pointsJson.length()) {
                val point = pointsJson.getJSONObject(i)
                val x = (point.optDouble("x", 0.0) * width).toFloat()
                val y = (point.optDouble("y", 0.0) * height).toFloat()
                ann.points.add(Pair(x, y))
            }
        }

        fun endAnnotation() {
            currentAnnotation?.let {
                it.isComplete = true
                annotations.add(it)
            }
            currentAnnotation = null
        }

        fun clearAll() {
            annotations.clear()
            currentAnnotation = null
            fadeAlpha = 255
            invalidate()
        }

        fun fadeOut() {
            // Simple fade: clear after fade
            annotations.clear()
            currentAnnotation = null
            fadeAlpha = 0
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)

            // Apply fade alpha
            val alpha = fadeAlpha

            // Draw completed annotations
            for (ann in annotations) {
                drawAnnotation(canvas, ann, alpha)
            }

            // Draw current in-progress annotation
            currentAnnotation?.let { ann ->
                drawAnnotation(canvas, ann, alpha)
            }
        }

        private fun drawAnnotation(canvas: Canvas, ann: Annotation, alpha: Int) {
            if (ann.points.isEmpty()) return

            val color = parseColor(ann.color, alpha)
            when (ann.tool) {
                "arrow" -> drawArrow(canvas, ann, color)
                "circle" -> drawCircle(canvas, ann, color)
                "highlight" -> drawHighlight(canvas, ann, color)
                "text" -> drawText(canvas, ann, color)
            }
        }

        private fun drawArrow(canvas: Canvas, ann: Annotation, color: Int) {
            arrowPaint.color = color
            if (ann.points.size < 2) return

            val path = Path()
            val first = ann.points.first()
            path.moveTo(first.first, first.second)

            for (i in 1 until ann.points.size) {
                path.lineTo(ann.points[i].first, ann.points[i].second)
            }
            canvas.drawPath(path, arrowPaint)

            // Draw arrowhead at the last point
            if (ann.points.size >= 2) {
                val last = ann.points.last()
                val prev = ann.points[ann.points.size - 2]
                drawArrowHead(canvas, prev.first, prev.second, last.first, last.second, color)
            }
        }

        private fun drawArrowHead(canvas: Canvas, fromX: Float, fromY: Float, toX: Float, toY: Float, color: Int) {
            val angle = Math.atan2((toY - fromY).toDouble(), (toX - fromX).toDouble())
            val arrowLen = 30f
            val arrowAngle = Math.PI / 6

            val x1 = toX - arrowLen * Math.cos(angle - arrowAngle).toFloat()
            val y1 = toY - arrowLen * Math.sin(angle - arrowAngle).toFloat()
            val x2 = toX - arrowLen * Math.cos(angle + arrowAngle).toFloat()
            val y2 = toY - arrowLen * Math.sin(angle + arrowAngle).toFloat()

            val path = Path()
            path.moveTo(toX, toY)
            path.lineTo(x1, y1)
            path.moveTo(toX, toY)
            path.lineTo(x2, y2)

            val headPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color
                style = Paint.Style.STROKE
                strokeWidth = 6f
                strokeCap = Paint.Cap.ROUND
            }
            canvas.drawPath(path, headPaint)
        }

        private fun drawCircle(canvas: Canvas, ann: Annotation, color: Int) {
            circlePaint.color = color
            if (ann.points.size < 2) return

            // Use first point as center, calculate radius from distance to farthest point
            val center = ann.points.first()
            var maxDist = 0f
            for (point in ann.points) {
                val dist = Math.hypot(
                    (point.first - center.first).toDouble(),
                    (point.second - center.second).toDouble()
                ).toFloat()
                if (dist > maxDist) maxDist = dist
            }

            canvas.drawCircle(center.first, center.second, maxDist, circlePaint)
        }

        private fun drawHighlight(canvas: Canvas, ann: Annotation, color: Int) {
            highlightPaint.color = color
            if (ann.points.size < 2) return

            // Draw a rounded rectangle from first to last point
            val first = ann.points.first()
            val last = ann.points.last()
            val left = minOf(first.first, last.first)
            val top = minOf(first.second, last.second)
            val right = maxOf(first.first, last.first)
            val bottom = maxOf(first.second, last.second)

            canvas.drawRoundRect(left, top, right, bottom, 12f, 12f, highlightPaint)
        }

        private fun drawText(canvas: Canvas, ann: Annotation, color: Int) {
            textPaint.color = color
            if (ann.points.isEmpty()) return

            val first = ann.points.first()
            canvas.drawText("看这里", first.first, first.second, textPaint)
        }

        private fun parseColor(hexColor: String, alpha: Int): Int {
            return try {
                val color = Color.parseColor(hexColor)
                Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
            } catch (e: Exception) {
                Color.argb(alpha, 255, 0, 0) // Default red
            }
        }
    }
}