package com.daviddev.aura_music.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.daviddev.aura_music.R
import com.daviddev.aura_music.audio.AudioSessionManager
import com.daviddev.aura_music.audio.EqualizerEngine
import com.daviddev.aura_music.audio.EffectsController
import com.daviddev.aura_music.audio.NativeEqualizerChannel
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * EqualizerForegroundService — Persistent DSP service that keeps the equalizer
 * engine alive independently from the Flutter UI lifecycle.
 *
 * Why a foreground service?
 * - Android may kill background processes under memory pressure
 * - DSP effects (audiofx) are tied to the process that created them
 * - If the process is killed, all effects are lost
 * - A foreground service with mediaPlayback type has higher priority
 *
 * Lifecycle:
 * 1. Started by Flutter via MethodChannel or by BootCompleteReceiver
 * 2. Creates its own FlutterEngine for MethodChannel communication
 * 3. Owns EqualizerEngine, AudioSessionManager, EffectsController
 * 4. Shows a persistent notification (required for foreground services)
 * 5. Survives activity recreation, app backgrounding, configuration changes
 * 6. Stopped explicitly by Flutter or when audio session ends
 *
 * Android requirements:
 * - FOREGROUND_SERVICE permission (already declared)
 * - FOREGROUND_SERVICE_MEDIA_PLAYBACK type (Android 14+)
 * - Notification channel and notification (required)
 */
class EqualizerForegroundService : Service() {

    companion object {
        private const val TAG = "AURA_EQ_SERVICE"
        private const val NOTIFICATION_CHANNEL_ID = "aura_equalizer_service"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.daviddev.aura.action.START_EQ_SERVICE"
        const val ACTION_STOP = "com.daviddev.aura.action.STOP_EQ_SERVICE"
        const val ACTION_REINITIALIZE = "com.daviddev.aura.action.REINITIALIZE_EQ"

        // Shared engine instance — accessible from MainActivity
        @Volatile
        var engine: EqualizerEngine? = null
            private set

        @Volatile
        var sessionManager: AudioSessionManager? = null
            private set

        @Volatile
        var effectsController: EffectsController? = null
            private set

        @Volatile
        var methodChannel: MethodChannel? = null
            private set

        private var flutterEngine: FlutterEngine? = null

        /**
         * Start the equalizer foreground service.
         * Call this from Flutter or MainActivity when DSP engine is needed.
         */
        fun start(context: Context) {
            val intent = Intent(context, EqualizerForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.i(TAG, "start: EqualizerForegroundService started")
        }

        /**
         * Stop the equalizer foreground service.
         * This will release all DSP resources.
         */
        fun stop(context: Context) {
            val intent = Intent(context, EqualizerForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
            Log.i(TAG, "stop: EqualizerForegroundService stop requested")
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate: initializing DSP engine")

        // Create notification channel (required for foreground service)
        createNotificationChannel()

        // Initialize DSP components
        engine = EqualizerEngine(applicationContext)
        sessionManager = AudioSessionManager()
        effectsController = EffectsController(engine!!)

        // Bind session manager to engine
        sessionManager!!.bindEngine(engine!!)

        // Set up MethodChannel for communication with Flutter
        setupMethodChannel()

        Log.i(TAG, "onCreate: DSP engine initialized, mode=${engine!!.engineMode.value}")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: action=${intent?.action}")

        // Start as foreground service (required)
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        when (intent?.action) {
            ACTION_STOP -> {
                Log.i(TAG, "onStartCommand: stopping service")
                stopSelf()
            }
            ACTION_REINITIALIZE -> {
                Log.i(TAG, "onStartCommand: reinitializing session")
                sessionManager?.reinitializeCurrentSession()
            }
            else -> {
                // Default: keep service running
                Log.d(TAG, "onStartCommand: service running")
            }
        }

        // Sticky: restart if killed by system (DSP state will be reinitialized)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.i(TAG, "onDestroy: releasing DSP resources")

        // Release DSP engine
        engine?.release()
        engine = null

        // Destroy session manager
        sessionManager?.destroy()
        sessionManager = null

        effectsController = null
        methodChannel = null

        // Clean up Flutter engine if we created one
        flutterEngine?.destroy()
        flutterEngine = null

        super.onDestroy()
    }

    // ─── Internal: MethodChannel Setup ────────────────────────

    /**
     * Set up a MethodChannel for Flutter ↔ Native communication.
     *
     * If a FlutterEngine already exists (from MainActivity), we reuse it.
     * Otherwise, we create a headless FlutterEngine for channel communication.
     */
    private fun setupMethodChannel() {
        // Try to get existing engine from cache first
        val existingEngine = FlutterEngineCache.getInstance().get("aura_main_engine")

        val dartExecutor = if (existingEngine != null) {
            Log.i(TAG, "setupMethodChannel: using cached FlutterEngine")
            flutterEngine = existingEngine as FlutterEngine
            existingEngine.dartExecutor
        } else {
            // Create a headless engine for channel communication
            Log.i(TAG, "setupMethodChannel: creating headless FlutterEngine")
            flutterEngine = FlutterEngine(applicationContext)
            flutterEngine!!.dartExecutor
        }

        methodChannel = MethodChannel(dartExecutor.binaryMessenger, NativeEqualizerChannel.CHANNEL_NAME)
        methodChannel!!.setMethodCallHandler(
            NativeEqualizerChannel(engine!!, sessionManager!!, effectsController!!)
        )

        Log.i(TAG, "setupMethodChannel: MethodChannel registered on ${NativeEqualizerChannel.CHANNEL_NAME}")
    }

    // ─── Internal: Notification ───────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "AURA DSP Engine",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps the equalizer engine running"
            setShowBadge(false)
            enableVibration(false)
            enableLights(false)
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("AURA Music — DSP Engine")
            .setContentText("Equalizer active")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }
}
