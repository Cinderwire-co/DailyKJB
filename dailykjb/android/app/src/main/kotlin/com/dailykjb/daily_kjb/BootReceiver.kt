package com.dailykjb.daily_kjb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Focus Mode back on after the phone restarts or the app is updated, without waiting for the app to be opened. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                FocusMode.start(context)
        }
    }
}
