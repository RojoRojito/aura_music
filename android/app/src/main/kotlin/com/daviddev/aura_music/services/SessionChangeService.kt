package com.daviddev.aura_music.services

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.JobIntentService
import com.daviddev.aura_music.audio.DspPrefs

/**
 * SessionChangeService — JobIntentService that handles audio session lifecycle events.
 *
 * Architecture (inspired by Flow Equalizer):
 * - Receives intents from AudioSessionReceiver for session open/close events
 * - Starts/restarts the ForegroundService if it's not running
 * - Handles BOOT_COMPLETED to restore DSP state
 * - Runs as a job, so it survives Doze mode and background restrictions
 *
 * Why a separate service instead of handling in the receiver?
 * - BroadcastReceiver has a 10-second timeout; JobIntentService has more time
 * - JobIntentService holds a wakelock, ensuring the work completes
 * - Can start foreground services even when the app is in the background
 *
 * Intent actions handled:
 * - ACTION_SESSION_OPEN: New audio session available, connect DSP
 * - ACTION_SESSION_CLOSE: Audio session ended, release DSP
 * - ACTION_BOOT: Device booted, restore DSP if it was enabled
 */
class SessionChangeService : JobIntentService() {

    companion object {
        private const val TAG = "AURA_SESSION_SVC"
        private const val JOB_ID = 1002

        const val ACTION_SESSION_OPEN = "com.daviddev.aura.action.SESSION_OPEN"
        const val ACTION_SESSION_CLOSE = "com.daviddev.aura.action.SESSION_CLOSE"
        const val ACTION_BOOT = "com.daviddev.aura.action.BOOT_RESTORE"

        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_PACKAGE_NAME = "package_name"

        /**
         * Enqueue work to handle a session open event.
         */
        fun enqueueSessionOpen(context: Context, sessionId: Int, packageName: String?) {
            Log.i(TAG, "enqueueSessionOpen: sessionId=$sessionId, package=$packageName")
            val intent = Intent(context, SessionChangeService::class.java).apply {
                action = ACTION_SESSION_OPEN
                putExtra(EXTRA_SESSION_ID, sessionId)
                putExtra(EXTRA_PACKAGE_NAME, packageName)
            }
            enqueueWork(context, SessionChangeService::class.java, JOB_ID, intent)
        }

        /**
         * Enqueue work to handle a session close event.
         */
        fun enqueueSessionClose(context: Context, sessionId: Int) {
            Log.i(TAG, "enqueueSessionClose: sessionId=$sessionId")
            val intent = Intent(context, SessionChangeService::class.java).apply {
                action = ACTION_SESSION_CLOSE
                putExtra(EXTRA_SESSION_ID, sessionId)
            }
            enqueueWork(context, SessionChangeService::class.java, JOB_ID, intent)
        }

        /**
         * Enqueue work to restore DSP after boot.
         */
        fun enqueueBootRestore(context: Context) {
            Log.i(TAG, "enqueueBootRestore")
            val intent = Intent(context, SessionChangeService::class.java).apply {
                action = ACTION_BOOT
            }
            enqueueWork(context, SessionChangeService::class.java, JOB_ID, intent)
        }
    }

    override fun onHandleWork(intent: Intent) {
        Log.d(TAG, "onHandleWork: action=${intent.action}")

        when (intent.action) {
            ACTION_SESSION_OPEN -> handleSessionOpen(intent)
            ACTION_SESSION_CLOSE -> handleSessionClose(intent)
            ACTION_BOOT -> handleBootRestore()
            else -> Log.w(TAG, "onHandleWork: unknown action=${intent.action}")
        }
    }

    private fun handleSessionOpen(intent: Intent) {
        val sessionId = intent.getIntExtra(EXTRA_SESSION_ID, -1)
        val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME)

        if (sessionId <= 0) {
            Log.w(TAG, "handleSessionOpen: invalid sessionId=$sessionId")
            return
        }

        // Ensure the ForegroundService is running
        if (!isServiceRunning()) {
            Log.i(TAG, "handleSessionOpen: ForegroundService not running, starting it")
            EqualizerForegroundService.start(applicationContext)
        }

        // Wait a moment for the service to initialize, then send the session
        // The service's static fields will be available after onCreate()
        // We use a small delay to ensure the service is ready
        try {
            Thread.sleep(200)
        } catch (e: InterruptedException) {
            // Ignore
        }

        // Now send the session to the DSP engine
        EqualizerForegroundService.sessionManager?.onNewSessionId(sessionId)
            ?: Log.w(TAG, "handleSessionOpen: sessionManager not available (service may still be initializing)")

        Log.i(TAG, "handleSessionOpen: session=$sessionId connected, mode=${EqualizerForegroundService.engine?.getEngineMode()}")
    }

    private fun handleSessionClose(intent: Intent) {
        val sessionId = intent.getIntExtra(EXTRA_SESSION_ID, -1)
        val currentSession = EqualizerForegroundService.sessionManager?.getSessionId()

        if (sessionId == currentSession || currentSession == null || currentSession <= 0) {
            Log.i(TAG, "handleSessionClose: releasing DSP for session=$sessionId")
            EqualizerForegroundService.sessionManager?.onSessionClosed()
        } else {
            Log.d(TAG, "handleSessionClose: sessionId=$sessionId doesn't match current=$currentSession, ignoring")
        }
    }

    private fun handleBootRestore() {
        val prefs = DspPrefs(applicationContext)
        val shouldRestore = prefs.isRestoreAfterBoot()

        if (shouldRestore) {
            Log.i(TAG, "handleBootRestore: restoring DSP engine after boot")
            EqualizerForegroundService.start(applicationContext)
        } else {
            Log.d(TAG, "handleBootRestore: DSP not enabled, skipping restore")
        }
    }

    private fun isServiceRunning(): Boolean {
        return EqualizerForegroundService.engine != null
    }
}
