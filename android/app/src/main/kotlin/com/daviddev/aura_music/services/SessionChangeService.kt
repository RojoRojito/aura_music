package com.daviddev.aura_music.services

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.JobIntentService
import com.daviddev.aura_music.audio.AudioSessionManager
import com.daviddev.aura_music.audio.DspPrefs

/**
 * SessionChangeService — JobIntentService that handles audio session lifecycle events.
 *
 * Architecture (inspired by Flow Equalizer):
 * - Receives intents from AudioSessionReceiver for session open/close events
 * - Starts the ForegroundService if it's not running
 * - Sends session ID to the DSP engine via the service's static references
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

        fun enqueueSessionOpen(context: Context, sessionId: Int, packageName: String?) {
            Log.i(TAG, "enqueueSessionOpen: sessionId=$sessionId, package=$packageName")
            val intent = Intent(context, SessionChangeService::class.java).apply {
                action = ACTION_SESSION_OPEN
                putExtra(EXTRA_SESSION_ID, sessionId)
                putExtra(EXTRA_PACKAGE_NAME, packageName)
            }
            enqueueWork(context, SessionChangeService::class.java, JOB_ID, intent)
        }

        fun enqueueSessionClose(context: Context, sessionId: Int) {
            Log.i(TAG, "enqueueSessionClose: sessionId=$sessionId")
            val intent = Intent(context, SessionChangeService::class.java).apply {
                action = ACTION_SESSION_CLOSE
                putExtra(EXTRA_SESSION_ID, sessionId)
            }
            enqueueWork(context, SessionChangeService::class.java, JOB_ID, intent)
        }

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

        // Check if this session is for our app (just_audio sessions)
        // If packageName is null or matches our app, process it
        if (packageName != null && packageName != "com.daviddev.aura_music") {
            Log.d(TAG, "handleSessionOpen: ignoring session from other app: $packageName")
            return
        }

        // Ensure the ForegroundService is running
        if (!isServiceRunning()) {
            Log.i(TAG, "handleSessionOpen: ForegroundService not running, starting it")
            EqualizerForegroundService.start(applicationContext)
            // Wait for service to initialize its static fields
            waitForServiceReady()
        }

        // Send the session to the DSP engine
        val sessionManager = EqualizerForegroundService.sessionManager
        if (sessionManager != null) {
            val success = sessionManager.onNewSessionId(sessionId)
            Log.i(TAG, "handleSessionOpen: session=$sessionId, success=$success, mode=${EqualizerForegroundService.engine?.getEngineMode()}")
        } else {
            Log.w(TAG, "handleSessionOpen: sessionManager not available")
        }
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
            // Wait for service to initialize
            waitForServiceReady()

            // Restore DSP state from prefs
            val engine = EqualizerForegroundService.engine
            val sessionManager = EqualizerForegroundService.sessionManager
            val effectsController = EqualizerForegroundService.effectsController

            if (engine != null && sessionManager != null && effectsController != null) {
                val config = prefs.loadConfig()
                Log.i(TAG, "handleBootRestore: restoring config preset=${config.presetName}")

                // Store pending config for session recovery
                sessionManager.storePendingConfig(
                    AudioSessionManager.PendingConfig(
                        enabled = config.eqEnabled,
                        bandGains = config.bandGains,
                        bassBoost = config.bassBoost,
                        bassFrequencyHz = config.bassFrequencyHz,
                        virtualizer = config.virtualizer,
                        loudness = config.loudness,
                        loudnessEnabled = config.loudnessEnabled,
                        limiterEnabled = config.limiterEnabled,
                        limiterThreshold = config.limiterThreshold,
                        limiterRatio = config.limiterRatio,
                        limiterAttack = config.limiterAttack,
                        limiterRelease = config.limiterRelease,
                        limiterPostGain = config.limiterPostGain
                    )
                )

                effectsController.setEqEnabled(config.eqEnabled)
                if (config.bandGains.isNotEmpty()) {
                    engine.setAllBandGains(config.bandGains)
                }
                engine.setBassBoost(config.bassBoost)
                engine.setBassFrequency(config.bassFrequencyHz)
                engine.setVirtualizer(config.virtualizer)
                engine.setLoudness(config.loudness)
                engine.setLoudnessEnabled(config.loudnessEnabled)
                engine.setLimiterEnabled(config.limiterEnabled)
                engine.setLimiterParams(
                    config.limiterThreshold,
                    config.limiterRatio,
                    config.limiterAttack,
                    config.limiterRelease,
                    config.limiterPostGain
                )

                Log.i(TAG, "handleBootRestore: DSP state restored successfully")
            } else {
                Log.e(TAG, "handleBootRestore: service components not available")
            }
        } else {
            Log.d(TAG, "handleBootRestore: DSP not enabled, skipping restore")
        }
    }

    private fun isServiceRunning(): Boolean {
        return EqualizerForegroundService.engine != null
    }

    private fun waitForServiceReady() {
        var retries = 0
        val maxRetries = 10
        while (retries < maxRetries) {
            if (EqualizerForegroundService.sessionManager != null) {
                Log.d(TAG, "waitForServiceReady: service ready after ${retries * 100}ms")
                return
            }
            try {
                Thread.sleep(100)
            } catch (e: InterruptedException) {
                return
            }
            retries++
        }
        Log.w(TAG, "waitForServiceReady: service not ready after ${maxRetries * 100}ms")
    }
}
