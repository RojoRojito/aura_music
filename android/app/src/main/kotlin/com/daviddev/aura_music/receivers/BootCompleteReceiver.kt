package com.daviddev.aura_music.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.daviddev.aura_music.services.SessionChangeService

/**
 * BootCompleteReceiver — Restarts the DSP engine after device reboot.
 *
 * Architecture (inspired by Flow Equalizer):
 * - Receives BOOT_COMPLETED and QUICKBOOT_POWERON broadcasts
 * - Delegates work to SessionChangeService (JobIntentService)
 * - SessionChangeService checks DspPrefs to determine if DSP should be restored
 *
 * Why delegate to SessionChangeService?
 * - BroadcastReceiver has a strict 10-second execution limit
 * - JobIntentService holds a wakelock and can run longer
 * - Centralizes all boot/session handling logic in one place
 *
 * Registration:
 * - Declared in AndroidManifest.xml with RECEIVE_BOOT_COMPLETED permission
 * - android:exported="false" — only system broadcasts
 */
class BootCompleteReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AURA_BOOT_RX"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        Log.i(TAG, "onReceive: ${intent.action}")
        SessionChangeService.enqueueBootRestore(context)
    }
}
