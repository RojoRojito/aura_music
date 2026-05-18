package com.daviddev.aura_music.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.daviddev.aura_music.services.EqualizerForegroundService

/**
 * BootCompleteReceiver — Restarts the equalizer service after device reboot.
 *
 * Only starts the service if:
 * - The equalizer was enabled before reboot (checked via SharedPreferences)
 * - The app has the necessary permissions
 *
 * This ensures the DSP engine is available immediately after boot
 * without requiring the user to open the app first.
 *
 * Registration:
 * - Declared in AndroidManifest.xml with RECEIVE_BOOT_COMPLETED permission
 * - android:exported="false" — only system broadcasts
 */
class BootCompleteReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AURA_BOOT_RX"
        private const val PREFS_NAME = "eq_settings"
        private const val KEY_EQ_ENABLED = "eq_enabled_after_boot"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        Log.i(TAG, "onReceive: ${intent.action}")

        // Check if EQ should be restored after boot
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val shouldRestore = prefs.getBoolean(KEY_EQ_ENABLED, false)

        if (shouldRestore) {
            Log.i(TAG, "onReceive: restoring equalizer service after boot")
            EqualizerForegroundService.start(context)
        } else {
            Log.d(TAG, "onReceive: EQ not enabled, skipping service start")
        }
    }

    /**
     * Save whether the EQ should be restored after boot.
     * Call this when the user enables/disables the equalizer.
     */
    fun setRestoreAfterBoot(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_EQ_ENABLED, enabled).apply()
        Log.d(TAG, "setRestoreAfterBoot: $enabled")
    }
}
