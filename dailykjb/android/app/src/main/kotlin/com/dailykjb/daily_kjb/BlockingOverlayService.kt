package com.dailykjb.daily_kjb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Focus Mode on Android: while it's on, this watches which app is in front and covers the chosen ones with the
 * app's shield until today's reading is done. It keeps running after the reading, checking less often, so at
 * midnight the apps lock again on their own, as on iPhone. "Read now" opens Daily KJB at today's reading.
 */
class BlockingOverlayService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 9001
        private const val CHANNEL_ID = "app_blocking_channel"
        private const val LOCKED_CHECK_MS = 1000L // while the apps should be locked
        private const val READ_CHECK_MS = 30_000L // once today is read, until midnight
        private val PAGE = Color.parseColor("#F3E9D7")
        private val INK = Color.parseColor("#2A1E15")
        private val FADED = Color.parseColor("#7C6852")
        private val ACCENT = Color.parseColor("#C0632B")
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayFor: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private var lastRead: Boolean? = null

    private val tick = object : Runnable {
        override fun run() {
            val wait = check()
            handler.postDelayed(this, wait)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        val n = buildNotification(FocusMode.isReadToday(this))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!FocusMode.isEnabled(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        hideOverlay()
        super.onDestroy()
    }

    /** One look at the phone; returns how long until the next. */
    private fun check(): Long {
        if (!FocusMode.isEnabled(this)) {
            stopSelf()
            return READ_CHECK_MS
        }
        val read = FocusMode.isReadToday(this)
        if (read != lastRead) {
            lastRead = read
            getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, buildNotification(read))
        }
        if (read) {
            hideOverlay()
            return READ_CHECK_MS
        }
        val front = foregroundPackage() ?: return LOCKED_CHECK_MS
        val blocked = FocusMode.blockedPackages(this)
        if (front in blocked) {
            if (overlayFor != front) showOverlay(front)
        } else if (front != packageName) {
            hideOverlay()
        } else {
            hideOverlay() // Daily KJB itself is in front
        }
        return LOCKED_CHECK_MS
    }

    private fun foregroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val end = System.currentTimeMillis()
        val events = usm.queryEvents(end - 10_000, end)
        var last: String? = null
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            if (e.eventType == UsageEvents.Event.ACTIVITY_RESUMED) last = e.packageName
        }
        return last
    }

    private fun appName(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) {
        "This app"
    }

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics).toInt()

    // The shield, as the iPhone's: parchment, the book, the Word first, Read now
    private fun showOverlay(pkg: String) {
        if (!Settings.canDrawOverlays(this)) return
        hideOverlay()

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(PAGE)
            setPadding(dp(32f), dp(48f), dp(32f), dp(40f))
            isClickable = true // nothing gets through to the app underneath
        }
        val top = View(this)
        layout.addView(top, LinearLayout.LayoutParams(1, 0, 1f))

        layout.addView(ImageView(this).apply {
            setImageResource(R.mipmap.ic_launcher)
        }, LinearLayout.LayoutParams(dp(88f), dp(88f)))

        layout.addView(TextView(this).apply {
            text = "The Word first"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            setTextColor(INK)
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dp(22f), 0, dp(12f))
        })

        layout.addView(TextView(this).apply {
            text = "${appName(pkg)} opens once today's reading is done in Daily KJB.\n\n" +
                "“Seek ye first the kingdom of God.” Matthew 6:33"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(FADED)
            typeface = Typeface.SERIF
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.15f)
        })

        layout.addView(View(this), LinearLayout.LayoutParams(1, 0, 1f))

        layout.addView(TextView(this).apply {
            text = "Read now"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                setColor(ACCENT)
                cornerRadius = dp(14f).toFloat()
            }
            setOnClickListener { readNow() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52f)))

        layout.addView(TextView(this).apply {
            text = "Close"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(FADED)
            gravity = Gravity.CENTER
            setPadding(0, dp(14f), 0, dp(4f))
            setOnClickListener { goHome() }
        })

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE
        )
        try {
            windowManager?.addView(layout, params)
            overlayView = layout
            overlayFor = pkg
        } catch (_: Exception) {
            // The overlay permission was taken away
        }
    }

    private fun hideOverlay() {
        overlayView?.let { v ->
            try {
                windowManager?.removeView(v)
            } catch (_: Exception) {}
        }
        overlayView = null
        overlayFor = null
    }

    private fun readIntent(): Intent = Intent(Intent.ACTION_VIEW, Uri.parse("dailykjb://read"), this, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    private fun readNow() {
        hideOverlay()
        startActivity(readIntent())
    }

    private fun goHome() {
        hideOverlay()
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Focus Mode", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Keeps your chosen apps locked until the day's reading is done"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(read: Boolean): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        val open = PendingIntent.getActivity(this, 0, readIntent(), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return builder
            .setContentTitle("Focus Mode is on")
            .setContentText(if (read) "Today is read. Your apps are open until midnight." else "Your chosen apps open once today's reading is done.")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }
}
