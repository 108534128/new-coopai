package com.example.food_recommendation_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "native_voice_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> result.error("NOT_AVAILABLE", "Native voice service not implemented", null)
                "startListening" -> result.error("NOT_AVAILABLE", "Native voice service not implemented", null)
                "stopListening" -> result.error("NOT_AVAILABLE", "Native voice service not implemented", null)
                "speak" -> result.error("NOT_AVAILABLE", "Native voice service not implemented", null)
                "dispose" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }
}
