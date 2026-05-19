package com.daviddev.aura_music.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.audiofx.AudioEffect
import android.util.Log
import com.daviddev.aura_music.services.SessionChangeService

/**
 * AudioSessionReceiver — Lightweight broadcast receiver for audio session events.
 *
 * Architecture (inspired by Flow Equalizer):
 * - Receives OPEN/CLOSE_AUDIO_EFFECT_CONTROL_SESSION broadcasts from Android
 * - Delegates work to SessionChangeService (JobIntentService) for reliable processing
 * - Does NOT do heavy work directly (avoids BroadcastReceiver 10-second timeout)
 * - Registered in AndroidManifest.xml (survives Activity destruction)
 *
 * Why delegate to SessionChangeService?
 * - BroadcastReceiver has a strict 10-second execution limit
 * - JobIntentService holds a wakelock and can run longer
 * - JobIntentService can start foreground services from background
 * - Survives Doze mode and background restrictions
 *
 * Flow pattern:
 * - Flow's SessionReceiver enqueues work to SessionChangeService
 * - SessionChangeService then starts/communicates with ForegroundService
 * - This decouples the receiver from the DSP engine lifecycle
 */
class AudioSessionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AURA_SESSION_RX"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val sessionId = intent.getIntExtra(AudioEffect.EXTRA_AUDIO_SESSION, -1)
        val packageName = intent.getStringExtra(AudioEffect.EXTRA_PACKAGE_NAME)

        Log.d(TAG, "onReceive: action=$action, sessionId=$sessionId, package=$packageName")

        when (action) {
            AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION -> {
                if (sessionId <= 0) {
                    Log.w(TAG, "onReceive: invalid sessionId=$sessionId")
                    return
                }
                Log.i(TAG, "ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION: sessionId=$sessionId")
                SessionChangeService.enqueueSessionOpen(context, sessionId, packageName)
            }
            AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION -> {
                Log.i(TAG, "ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION: sessionId=$sessionId")
                SessionChangeService.enqueueSessionClose(context, sessionId)
            }
        }
    }
}
