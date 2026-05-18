package com.daviddev.aura_music.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log
import com.daviddev.aura_music.audio.AudioSessionManager
import com.daviddev.aura_music.services.EqualizerForegroundService

/**
 * AudioSessionReceiver — Listens for audio effect control session events.
 *
 * Receives broadcasts from Android's audio framework when:
 * - OPEN_AUDIO_EFFECT_CONTROL_SESSION: A new audio session is available for effects
 * - CLOSE_AUDIO_EFFECT_CONTROL_SESSION: An audio session is being closed
 *
 * This receiver bridges Android's audio session lifecycle to our DSP engine.
 * When a session opens, we notify AudioSessionManager to reconnect the DSP chain.
 * When a session closes, we release DSP resources safely.
 *
 * Registration:
 * - Must be registered dynamically (not in manifest) with the correct intent filter
 * - Registered in MainActivity.onCreate() or EqualizerForegroundService.onCreate()
 */
class AudioSessionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AURA_SESSION_RX"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val sessionId = intent.getIntExtra(AudioManager.EXTRA_AUDIO_SESSION, -1)
        val packageName = intent.getStringExtra(AudioManager.EXTRA_PACKAGE_NAME)

        Log.d(TAG, "onReceive: action=$action, sessionId=$sessionId, package=$packageName")

        // Only handle sessions from our own app
        if (packageName != context.packageName) {
            Log.d(TAG, "onReceive: ignoring session from different package")
            return
        }

        when (action) {
            AudioManager.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION -> {
                Log.i(TAG, "ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION: sessionId=$sessionId")
                handleSessionOpen(context, sessionId)
            }
            AudioManager.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION -> {
                Log.i(TAG, "ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION: sessionId=$sessionId")
                handleSessionClose(context, sessionId)
            }
        }
    }

    private fun handleSessionOpen(context: Context, sessionId: Int) {
        if (sessionId <= 0) {
            Log.w(TAG, "handleSessionOpen: invalid sessionId=$sessionId")
            return
        }

        // Notify the session manager
        EqualizerForegroundService.sessionManager?.onNewSessionId(sessionId)
            ?: Log.w(TAG, "handleSessionOpen: sessionManager not available")
    }

    private fun handleSessionClose(context: Context, sessionId: Int) {
        val currentSession = EqualizerForegroundService.sessionManager?.getSessionId()

        // Only close if it matches our current session
        if (sessionId == currentSession || currentSession == null || currentSession <= 0) {
            Log.i(TAG, "handleSessionClose: releasing DSP for session=$sessionId")
            EqualizerForegroundService.sessionManager?.onSessionClosed()
        } else {
            Log.d(TAG, "handleSessionClose: sessionId=$sessionId doesn't match current=$currentSession, ignoring")
        }
    }
}
