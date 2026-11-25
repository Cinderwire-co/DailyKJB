package com.dailykjb.daily_kjb

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var appBlockingChannel: AppBlockingChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appBlockingChannel = AppBlockingChannel(this)
        appBlockingChannel.register(flutterEngine)
    }
}
