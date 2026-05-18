package com.silverhair.elderly_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.silverhair.elderly_app.platform.OverlayPlugin
import com.silverhair.elderly_app.platform.PhoneCallPlugin
import com.silverhair.elderly_app.platform.ScreenCapturePlugin
import com.silverhair.elderly_app.platform.AnnotationOverlayPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ElderlyApp.flutterEngine = flutterEngine
        OverlayPlugin.registerWith(flutterEngine, this)
        PhoneCallPlugin.registerWith(flutterEngine, this)
        ScreenCapturePlugin.registerWith(flutterEngine, this)
        AnnotationOverlayPlugin.registerWith(flutterEngine, this)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        ScreenCapturePlugin.onActivityResult(requestCode, resultCode, data)
    }
}