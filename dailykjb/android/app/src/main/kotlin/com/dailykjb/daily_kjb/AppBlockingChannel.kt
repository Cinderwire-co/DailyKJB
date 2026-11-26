package com.dailykjb.daily_kjb

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The com.dailykjb/app_blocking channel on Android, the same calls the iPhone answers (Runner/AppBlockingChannel.swift):
 * permission, the apps chosen, Focus Mode on and off, and the day's reading done.
 */
class AppBlockingChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.dailykjb/app_blocking"
    }

    private var channel: MethodChannel? = null

    fun register(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)

            // Usage access to see which app is in front, then permission to cover it: one screen at a time
            "requestAuthorization" -> {
                when {
                    !hasUsageAccess() -> activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    !Settings.canDrawOverlays(activity) -> activity.startActivity(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}"))
                    )
                }
                result.success(hasUsageAccess() && Settings.canDrawOverlays(activity))
            }

            "isAuthorized" -> result.success(hasUsageAccess() && Settings.canDrawOverlays(activity))

            "showAppPicker" -> result.success(blockableApps())

            "getBlockedPackages" -> result.success(FocusMode.blockedPackages(activity).toList())

            "setBlockedPackages" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                FocusMode.setBlockedPackages(activity, packages.toSet())
                FocusMode.start(activity)
                result.success(packages.size)
            }

            // On, and watching; idempotent, so the app calls it each time it opens
            "enableBlocking" -> {
                FocusMode.setEnabled(activity, true)
                FocusMode.start(activity)
                result.success(true)
            }

            "disableBlocking" -> {
                FocusMode.setEnabled(activity, false)
                FocusMode.stop(activity)
                result.success(true)
            }

            // Read: the apps open until midnight. Focus Mode stays on and the service keeps watching for the next day.
            "markReadingComplete" -> {
                FocusMode.markRead(activity)
                FocusMode.start(activity)
                result.success(true)
            }

            "isReadingCompleteToday" -> result.success(FocusMode.isReadToday(activity))

            "checkAndReenableShields" -> {
                FocusMode.start(activity)
                result.success(true)
            }

            "hasSelectedApps" -> result.success(FocusMode.blockedPackages(activity).isNotEmpty())

            "selectedAppCount" -> result.success(FocusMode.blockedPackages(activity).size)

            else -> result.notImplemented()
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            activity.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // The apps on the home screen (the manifest's <queries> lets these, and only these, be seen)
    private fun blockableApps(): List<Map<String, String>> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val suggested = setOf(
            "com.instagram.android", "com.twitter.android", "com.twitter.android.lite",
            "com.zhiliaoapp.musically", "com.ss.android.ugc.trill", "com.facebook.katana", "com.facebook.lite",
            "com.snapchat.android", "com.reddit.frontpage", "com.pinterest", "com.tumblr", "com.discord",
            "com.google.android.youtube", "tv.twitch.android.app", "com.netflix.mediaclient",
        )
        val blocked = FocusMode.blockedPackages(activity)
        return pm.queryIntentActivities(intent, 0)
            .filter { it.activityInfo.packageName != activity.packageName }
            .distinctBy { it.activityInfo.packageName }
            .map {
                val pkg = it.activityInfo.packageName
                mapOf(
                    "packageName" to pkg,
                    "appName" to it.loadLabel(pm).toString(),
                    "isSuggested" to (pkg in suggested).toString(),
                    "isBlocked" to (pkg in blocked).toString(),
                )
            }
            .sortedWith(
                compareByDescending<Map<String, String>> { it["isBlocked"] == "true" }
                    .thenByDescending { it["isSuggested"] == "true" }
                    .thenBy { it["appName"]?.lowercase() }
            )
    }
}
