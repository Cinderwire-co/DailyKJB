package com.dailykjb.daily_kjb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray

class BlockingOverlayService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 9001
        private const val CHANNEL_ID = "app_blocking_channel"
        private const val CHECK_INTERVAL_MS = 1000L
        private const val PREFS_NAME = "app_blocking_prefs"
        private const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        private const val KEY_READING_COMPLETE_DATE = "reading_complete_date"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isOverlayShowing = false
    private lateinit var prefs: SharedPreferences

    private val checkRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.post(checkRunnable)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(checkRunnable)
        hideOverlay()
        super.onDestroy()
    }

    private fun checkForegroundApp() {
        // If reading is complete today, stop the service
        if (isReadingCompleteToday()) {
            hideOverlay()
            stopSelf()
            return
        }

        val foregroundPackage = getForegroundPackage() ?: return
        val blockedPackages = getBlockedPackages()

        if (blockedPackages.contains(foregroundPackage) && !isOverlayShowing) {
            showOverlay()
        } else if (!blockedPackages.contains(foregroundPackage) && isOverlayShowing) {
            hideOverlay()
        }
    }

    private fun getForegroundPackage(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null

        val endTime = System.currentTimeMillis()
        val beginTime = endTime - 5000

        val usageEvents = usageStatsManager.queryEvents(beginTime, endTime)
        var lastPackage: String? = null

        val event = android.app.usage.UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED) {
                lastPackage = event.packageName
            }
        }

        return lastPackage
    }

    private fun showOverlay() {
        if (!Settings.canDrawOverlays(this)) return
        if (isOverlayShowing) return

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F0121212"))
            setPadding(48, 48, 48, 48)
        }

        // Icon
        val iconText = TextView(this).apply {
            text = "\uD83D\uDCD6" // 📖
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 64f)
            gravity = Gravity.CENTER
        }
        layout.addView(iconText)

        // Title
        val titleText = TextView(this).apply {
            text = "Time to Read First"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 16)
        }
        layout.addView(titleText)

        // Subtitle
        val subtitleText = TextView(this).apply {
            text = "Complete your daily Bible reading\nin DailyKJB to unlock this app."
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }
        layout.addView(subtitleText)

        // Open DailyKJB button
        val openButton = TextView(this).apply {
            text = "Open DailyKJB"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1E3A5F"))
            setPadding(64, 24, 64, 24)
            setOnClickListener {
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launchIntent)
                }
                hideOverlay()
            }
        }
        layout.addView(openButton)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        // Make the overlay touchable for the button
        params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()

        try {
            windowManager?.addView(layout, params)
            overlayView = layout
            isOverlayShowing = true
        } catch (_: Exception) {
            // Overlay permission may have been revoked
        }
    }

    private fun hideOverlay() {
        if (overlayView != null && isOverlayShowing) {
            try {
                windowManager?.removeView(overlayView)
            } catch (_: Exception) {}
            overlayView = null
            isOverlayShowing = false
        }
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

    private fun isReadingCompleteToday(): Boolean {
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date())
        return prefs.getString(KEY_READING_COMPLETE_DATE, "") == today
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors apps to enforce daily reading"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("Focus Mode Active")
            .setContentText("Complete your daily reading to unlock blocked apps")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }
}
