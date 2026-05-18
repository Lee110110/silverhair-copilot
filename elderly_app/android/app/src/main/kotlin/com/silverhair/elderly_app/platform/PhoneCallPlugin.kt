package com.silverhair.elderly_app.platform

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PhoneCallPlugin private constructor() {
    companion object {
        private const val CHANNEL = "phone_call"

        fun registerWith(engine: FlutterEngine, activity: Activity) {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(PhoneCallMethodHandler(activity))
        }
    }
}

class PhoneCallMethodHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "makeCall" -> {
                val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                if (phoneNumber.isNotEmpty()) {
                    val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phoneNumber"))
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (e: SecurityException) {
                        // Fallback to dialer if CALL_PHONE not granted
                        val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phoneNumber"))
                        activity.startActivity(dialIntent)
                        result.success(true)
                    }
                } else {
                    result.error("INVALID_PHONE", "Phone number is empty", null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
