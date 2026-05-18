package com.silverhair.elderly_app.platform

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.silverhair.elderly_app.service.AnnotationOverlayService

class AnnotationOverlayPlugin private constructor() {
    companion object {
        private const val CHANNEL = "annotation_overlay"

        fun registerWith(engine: FlutterEngine, activity: Activity) {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(AnnotationOverlayMethodHandler(activity))
        }
    }
}

class AnnotationOverlayMethodHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "renderAnnotation" -> {
                val type = call.argument<String>("type") ?: ""
                val payloadJson = call.argument<String>("payload") ?: "{}"
                val intent = Intent(activity, AnnotationOverlayService::class.java)
                intent.action = "RENDER"
                intent.putExtra("type", type)
                intent.putExtra("payload", payloadJson)
                activity.startService(intent)
                result.success(true)
            }
            "clearAnnotations" -> {
                val intent = Intent(activity, AnnotationOverlayService::class.java)
                intent.action = "CLEAR"
                activity.startService(intent)
                result.success(true)
            }
            "showOverlay" -> {
                val intent = Intent(activity, AnnotationOverlayService::class.java)
                intent.action = "SHOW"
                activity.startService(intent)
                result.success(true)
            }
            "hideOverlay" -> {
                val intent = Intent(activity, AnnotationOverlayService::class.java)
                intent.action = "HIDE"
                activity.startService(intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}