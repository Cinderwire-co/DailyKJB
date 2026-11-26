package com.dailykjb.daily_kjb

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app, its Focus Mode channel, and com.dailykjb/home: the link the app was opened with (dailykjb://read from
 * Focus Mode's "Read now" or its notification), as the iPhone's HomeScreenBridge gives it.
 */
class MainActivity : FlutterActivity() {
    private lateinit var appBlockingChannel: AppBlockingChannel
    private var home: MethodChannel? = null
    private var pending: String? = null
    private var listening = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appBlockingChannel = AppBlockingChannel(this)
        appBlockingChannel.register(flutterEngine)
        pending = linkOf(intent)
        home = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dailykjb/home").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialLink" -> {
                        listening = true
                        result.success(pending)
                        pending = null
                    }
                    "shieldReadNow" -> result.success(false) // Android's "Read now" arrives as a link
                    "update" -> result.success(null) // no home screen widgets on Android yet
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = linkOf(intent) ?: return
        if (listening) home?.invokeMethod("link", link) else pending = link
    }

    private fun linkOf(i: Intent?): String? = i?.data?.takeIf { it.scheme == "dailykjb" }?.toString()
}
