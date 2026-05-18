package com.daviddev.aura_music

import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Bundle
import android.util.Log
import com.daviddev.aura_music.audio.AudioSessionManager
import com.daviddev.aura_music.audio.EqualizerEngine
import com.daviddev.aura_music.audio.EffectsController
import com.daviddev.aura_music.audio.NativeEqualizerChannel
import com.daviddev.aura_music.receivers.AudioSessionReceiver
import com.daviddev.aura_music.services.EqualizerForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Entry point for AURA Music Flutter app.
 *
 * REFACTORED: This class no longer owns DSP logic.
 * It only:
 * - Registers the MethodChannel (delegating to NativeEqualizerChannel)
 * - Creates and manages DSP components (engine, session manager, effects controller)
 * - Registers broadcast receivers for audio session events
 * - Starts the foreground service for persistent DSP
 *
 * All DSP operations are delegated to:
 * - EqualizerEngine (core DSP processing)
 * - AudioSessionManager (session lifecycle)
 * - EffectsController (module enable/disable)
 * - NativeEqualizerChannel (Flutter bridge)
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "AURA_MAIN"
    }

    // DSP components
    private lateinit var engine: EqualizerEngine
    private lateinit var sessionManager: AudioSessionManager
    private lateinit var effectsController: EffectsController
    private lateinit var nativeChannel: NativeEqualizerChannel

    // Broadcast receiver for audio session events
    private val audioSessionReceiver = AudioSessionReceiver()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "onCreate: initializing AURA Music")

        // Initialize DSP components
        engine = EqualizerEngine(applicationContext)
        sessionManager = AudioSessionManager()
        effectsController = EffectsController(engine)

        // Bind session manager to engine
        sessionManager.bindEngine(engine)

        // Store in foreground service for cross-component access
        EqualizerForegroundService.engine = engine
        EqualizerForegroundService.sessionManager = sessionManager
        EqualizerForegroundService.effectsController = effectsController

        // Create the MethodChannel handler
        nativeChannel = NativeEqualizerChannel(engine, sessionManager, effectsController)

        // Register MethodChannel on the Flutter engine
        registerMethodChannel()

        // Cache the FlutterEngine for the foreground service to reuse
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

        // Unregister broadcast receiver
        try {
            unregisterReceiver(audioSessionReceiver)
            Log.d(TAG, "onDestroy: audio session receiver unregistered")
        } catch (e: Exception) {
            Log.w(TAG, "onDestroy: receiver already unregistered", e)
        }

        // Release DSP engine
        engine.release()

        super.onDestroy()
    }

    // ─── Internal: MethodChannel Registration ─────────────────

    private fun registerMethodChannel() {
        val flutterEngine = flutterEngine
        if (flutterEngine == null) {
            Log.e(TAG, "registerMethodChannel: flutterEngine is NULL!")
            return
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NativeEqualizerChannel.CHANNEL_NAME
        ).setMethodCallHandler(nativeChannel)

        Log.i(TAG, "registerMethodChannel: registered on ${NativeEqualizerChannel.CHANNEL_NAME}")
    }

    // ─── Internal: Broadcast Receiver Registration ────────────

    private fun registerAudioSessionReceiver() {
        val filter = IntentFilter().apply {
            addAction(AudioManager.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION)
            addAction(AudioManager.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION)
        }

        // Register with RECEIVER_EXPORTED for Android 13+ compatibility
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(audioSessionReceiver, filter, android.content.Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(audioSessionReceiver, filter)
        }

        Log.i(TAG, "registerAudioSessionReceiver: registered")
    }

    // ─── Internal: Foreground Service ─────────────────────────

    private fun startEqualizerService() {
        Log.i(TAG, "startEqualizerService: starting foreground service")
        EqualizerForegroundService.start(this)
    }
}
