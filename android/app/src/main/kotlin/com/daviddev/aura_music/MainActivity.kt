package com.daviddev.aura_music

import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.util.Log
import com.daviddev.aura_music.audio.NativeEqualizerChannel
import com.daviddev.aura_music.services.EqualizerForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Entry point for AURA Music Flutter app.
 *
 * Responsibilities:
 * - Start the foreground service (which owns all DSP logic)
 * - Register MethodChannel for Flutter ↔ Native DSP communication
 * - AudioSessionReceiver is registered in AndroidManifest.xml (not dynamically)
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "AURA_MAIN"
    }

    private var methodChannel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "onCreate: initializing AURA Music")

        // Start the foreground service for persistent DSP
        startEqualizerService()

        // Register MethodChannel for DSP communication
        registerEqualizerChannel()

        Log.i(TAG, "onCreate: initialization complete")
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy: cleaning up")
        handler.removeCallbacksAndMessages(null)
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        super.onDestroy()
    }

    private fun startEqualizerService() {
        Log.i(TAG, "startEqualizerService: starting foreground service")
        EqualizerForegroundService.start(this)
    }

    private fun registerEqualizerChannel() {
        registerChannelWithRetry(5)
    }

    private fun registerChannelWithRetry(maxRetries: Int, retryCount: Int = 0) {
        val engine = EqualizerForegroundService.engine
        val sessionManager = EqualizerForegroundService.sessionManager
        val effectsController = EqualizerForegroundService.effectsController

        if (engine != null && sessionManager != null && effectsController != null) {
            methodChannel = MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                NativeEqualizerChannel.CHANNEL_NAME
            )
            methodChannel!!.setMethodCallHandler(
                NativeEqualizerChannel(
                    applicationContext,
                    engine,
                    sessionManager,
                    effectsController
                )
            )
            Log.i(TAG, "registerEqualizerChannel: MethodChannel registered")
        } else if (retryCount < maxRetries) {
            Log.d(TAG, "registerEqualizerChannel: service not ready, retrying in 200ms (attempt ${retryCount + 1}/$maxRetries)")
            handler.postDelayed({
                registerChannelWithRetry(maxRetries, retryCount + 1)
            }, 200)
        } else {
            Log.w(TAG, "registerEqualizerChannel: service not ready after $maxRetries retries")
        }
    }
}
