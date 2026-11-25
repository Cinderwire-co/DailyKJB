package com.dailykjb.daily_kjb

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.app.AppOpsManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class AppBlockingChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.dailykjb/app_blocking"
        private const val PREFS_NAME = "app_blocking_prefs"
        private const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        private const val KEY_BLOCKING_ENABLED = "blocking_enabled"
        private const val KEY_READING_COMPLETE_DATE = "reading_complete_date"
    }

    private var channel: MethodChannel? = null
    private val prefs: SharedPreferences by lazy {
        activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun register(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)

            "requestAuthorization" -> {
                // On Android, we need Usage Stats + Overlay permissions
                val hasUsageStats = hasUsageStatsPermission()
                val hasOverlay = Settings.canDrawOverlays(activity)

                if (!hasUsageStats) {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    activity.startActivity(intent)
                }

                if (!hasOverlay) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}")
                    )
                    activity.startActivity(intent)
                }

                // Return true if both permissions are already granted
                result.success(hasUsageStats && hasOverlay)
            }

            "isAuthorized" -> {
                val hasUsageStats = hasUsageStatsPermission()
                val hasOverlay = Settings.canDrawOverlays(activity)
                result.success(hasUsageStats && hasOverlay)
            }

            "showAppPicker" -> {
                // Return list of installed apps for Flutter to show a picker
                val apps = getBlockableApps()
                result.success(apps)
            }

            "getBlockedPackages" -> {
                result.success(getBlockedPackages().toList())
            }

            "setBlockedPackages" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                saveBlockedPackages(packages.toSet())
                result.success(packages.size)
            }

            "enableBlocking" -> {
                prefs.edit().putBoolean(KEY_BLOCKING_ENABLED, true).apply()
                startBlockingService()
                result.success(true)
            }

            "disableBlocking" -> {
                prefs.edit().putBoolean(KEY_BLOCKING_ENABLED, false).apply()
                stopBlockingService()
                result.success(true)
            }

            "markReadingComplete" -> {
                markReadingComplete()
                result.success(true)
            }

            "isReadingCompleteToday" -> {
                result.success(isReadingCompleteToday())
            }

            "checkAndReenableShields" -> {
                if (!isReadingCompleteToday() && getBlockedPackages().isNotEmpty()) {
                    startBlockingService()
                } else if (isReadingCompleteToday()) {
                    stopBlockingService()
                }
                result.success(true)
            }

            "hasSelectedApps" -> {
                result.success(getBlockedPackages().isNotEmpty())
            }

            "selectedAppCount" -> {
                result.success(getBlockedPackages().size)
            }

            else -> result.notImplemented()
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            activity.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getBlockableApps(): List<Map<String, String>> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(intent, 0)
        val myPackage = activity.packageName

        // Common social media / distraction app packages to suggest
        val suggestedPackages = setOf(
            "com.instagram.android",
            "com.twitter.android",
            "com.twitter.android.lite",
            "com.zhiliaoapp.musically", // TikTok
            "com.facebook.katana",
            "com.facebook.lite",
            "com.snapchat.android",
            "com.reddit.frontpage",
            "com.pinterest",
            "com.tumblr",
            "com.discord",
            "com.whatsapp",
            "com.google.android.youtube",
            "tv.twitch.android.app",
            "com.netflix.mediaclient",
            "com.spotify.music",
        )

        val currentlyBlocked = getBlockedPackages()

        return resolveInfos
            .filter { it.activityInfo.packageName != myPackage }
            .distinctBy { it.activityInfo.packageName }
            .map { resolveInfo ->
                val packageName = resolveInfo.activityInfo.packageName
                val appName = resolveInfo.loadLabel(pm).toString()
                val isSuggested = suggestedPackages.contains(packageName)
                val isBlocked = currentlyBlocked.contains(packageName)
                mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "isSuggested" to isSuggested.toString(),
                    "isBlocked" to isBlocked.toString(),
                )
            }
            .sortedWith(compareByDescending<Map<String, String>> {
                it["isBlocked"] == "true"
            }.thenByDescending {
                it["isSuggested"] == "true"
            }.thenBy {
                it["appName"]
            })
    }

    private fun getBlockedPackages(): Set<String> {
        val json = prefs.getString(KEY_BLOCKED_PACKAGES, "[]") ?: "[]"
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map { array.getString(it) }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun saveBlockedPackages(packages: Set<String>) {
        val array = JSONArray(packages.toList())
        prefs.edit().putString(KEY_BLOCKED_PACKAGES, array.toString()).apply()
    }

    private fun markReadingComplete() {
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date())
        prefs.edit().putString(KEY_READING_COMPLETE_DATE, today).apply()
        stopBlockingService()
    }

    private fun isReadingCompleteToday(): Boolean {
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date())
        return prefs.getString(KEY_READING_COMPLETE_DATE, "") == today
    }

    private fun startBlockingService() {
        val intent = Intent(activity, BlockingOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent)
        } else {
            activity.startService(intent)
        }
    }

    private fun stopBlockingService() {
        val intent = Intent(activity, BlockingOverlayService::class.java)
        activity.stopService(intent)
    }
}
