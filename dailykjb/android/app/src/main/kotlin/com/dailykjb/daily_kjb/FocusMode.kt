package com.dailykjb.daily_kjb

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Focus Mode's state on Android, shared by the app's channel, the blocking service and the boot receiver: the
 * apps chosen, whether Focus Mode is on, and the day the reading was last done. As on iPhone, "enabled" is the
 * reader's choice and only changes when they turn Focus Mode on or off; reading the day only opens the apps until
 * midnight.
 */
object FocusMode {
    private const val PREFS = "app_blocking_prefs"
    private const val KEY_BLOCKED_PACKAGES = "blocked_packages"
    private const val KEY_ENABLED = "blocking_enabled"
    private const val KEY_READ_ON = "reading_complete_date"

    private fun prefs(c: Context): SharedPreferences = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    fun isEnabled(c: Context) = prefs(c).getBoolean(KEY_ENABLED, false)
    fun setEnabled(c: Context, on: Boolean) = prefs(c).edit().putBoolean(KEY_ENABLED, on).apply()

    fun isReadToday(c: Context) = prefs(c).getString(KEY_READ_ON, "") == today()
    fun markRead(c: Context) = prefs(c).edit().putString(KEY_READ_ON, today()).apply()

    fun blockedPackages(c: Context): Set<String> {
        val json = prefs(c).getString(KEY_BLOCKED_PACKAGES, "[]") ?: "[]"
        return try {
            val a = JSONArray(json)
            (0 until a.length()).map { a.getString(it) }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    fun setBlockedPackages(c: Context, packages: Set<String>) =
        prefs(c).edit().putString(KEY_BLOCKED_PACKAGES, JSONArray(packages.toList()).toString()).apply()

    /** The watching service, if Focus Mode is on and there's something to watch. */
    fun start(c: Context) {
        if (!isEnabled(c) || blockedPackages(c).isEmpty()) return
        val i = Intent(c, BlockingOverlayService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) c.startForegroundService(i) else c.startService(i)
        } catch (_: Exception) {
            // Not allowed to start from here just now; the app starts it when it next opens
        }
    }

    fun stop(c: Context) {
        c.stopService(Intent(c, BlockingOverlayService::class.java))
    }
}
