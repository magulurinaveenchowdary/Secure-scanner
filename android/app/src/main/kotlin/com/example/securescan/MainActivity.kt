package com.securescan.securescan

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.securescan.securescan/app"
    private val TAG = "SecureScanMainActivity"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> {
                    val route = call.argument<String>("route")
                    openApp(route)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getInitialRoute(): String? {
        return intent.getStringExtra("route") ?: super.getInitialRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        try {
            val route = intent.getStringExtra("route")
             android.util.Log.d("StartApp", "onNewIntent received route: $route")
            if (route != null) {
                flutterEngine?.navigationChannel?.pushRoute(route)
            }
        } catch (e: Exception) {
             android.util.Log.e("StartApp", "Error in onNewIntent: ${e.message}")
        }
    }

    private fun openApp(route: String?) {
        try {
             android.util.Log.d("StartApp", "openApp called with route: $route")
            val intent = Intent(this, MainActivity::class.java).apply {
                // REORDER_TO_FRONT brings the activity to top without killing it
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
                route?.let { putExtra("route", it) }
            }
            startActivity(intent)
        } catch (e: Exception) {
             android.util.Log.e("StartApp", "Error in openApp: ${e.message}")
        }
    }
}
