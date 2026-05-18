package com.daviddev.aura_music

import android.content.IntentFilter
import android.media.AudioManager
import android.os.Bundle
import android.util.Log
import com.daviddev.aura_music.receivers.AudioSessionReceiver
import com.daviddev.aura_music.services.EqualizerForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * MainActivity — Entry point for AURA Music Flutter app.
 *
 * Minimal responsibilities:
 * - Cache FlutterEngine for the foreground service
 * - Register broadcast receiver for audio session events
 * - Start the foreground service (which owns all DSP logic)
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "AURA_MAIN"
    }

    private val audioSessionReceiver = AudioSessionReceiver()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "onCreate: initializing AURA Music")

        // Cache FlutterEngine for the foreground service to reuse
        flutterEngine?.let { fe ->
            FlutterEngineCache.getInstance().put("aura_main_engine", fe)
            Log.i(TAG, "onCreate: FlutterEngine cached")
        }

        // Register audio session broadcast receiver
        registerAudioSessionReceiver()

        // Start the foreground service for persistent DSP
        startEqualizerService()

        Log.i(TAG, "onCreate: initialization complete")
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy: cleaning up")

        try {
            unregisterReceiver(audioSessionReceiver)
            Log.d(TAG, "onDestroy: audio session receiver unregistered")
        } catch (e: Exception) {
            Log.w(TAG, "onDestroy: receiver already unregistered", e)
        }

        super.onDestroy()
    }

    private fun registerAudioSessionReceiver() {
        val filter = IntentFilter().apply {
            addAction(AudioManager.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION)
            addAction(AudioManager.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION)
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(audioSessionReceiver, filter, android.content.Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(audioSessionReceiver, filter)
        }

        Log.i(TAG, "registerAudioSessionReceiver: registered")
    }

    private fun startEqualizerService() {
        Log.i(TAG, "startEqualizerService: starting foreground service")
        EqualizerForegroundService.start(this)
    }
}
