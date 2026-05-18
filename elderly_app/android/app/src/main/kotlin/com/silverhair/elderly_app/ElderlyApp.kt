package com.silverhair.elderly_app

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine

class ElderlyApp : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    companion object {
        private var instance: ElderlyApp? = null
        var flutterEngine: FlutterEngine? = null

        fun applicationContext(): android.content.Context {
            return instance!!.applicationContext
        }
    }
}
