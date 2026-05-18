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
import com.daviddev.aura_music.audio.AudioSessionManager
import com.daviddev.aura_music.audio.EqualizerEngine
import com.daviddev.aura_music.audio.EffectsController
import com.daviddev.aura_music.audio.NativeEqualizerChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * EqualizerForegroundService — Persistent DSP service that keeps the equalizer
 * engine alive independently from the Flutter UI lifecycle.
 *
 * Lifecycle:
 * 1. Started by Flutter via MethodChannel or by BootCompleteReceiver
 * 2. Owns EqualizerEngine, AudioSessionManager, EffectsController
 * 3. Shows a persistent notification (required for foreground services)
 * 4. Survives activity recreation, app backgrounding, configuration changes
 * 5. Stopped explicitly by Flutter or when audio session ends
 */
class EqualizerForegroundService : Service() {

    companion object {
        private const val TAG = "AURA_EQ_SERVICE"
        private const val NOTIFICATION_CHANNEL_ID = "aura_equalizer_service"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.daviddev.aura.action.START_EQ_SERVICE"
        const val ACTION_STOP = "com.daviddev.aura.action.STOP_EQ_SERVICE"
        const val ACTION_REINITIALIZE = "com.daviddev.aura.action.REINITIALIZE_EQ"

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

        createNotificationChannel()

        engine = EqualizerEngine(applicationContext)
        sessionManager = AudioSessionManager()
        effectsController = EffectsController(engine!!)

        sessionManager!!.bindEngine(engine!!)

        setupMethodChannel()

        Log.i(TAG, "onCreate: DSP engine initialized, mode=${engine!!.getEngineMode()}")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: action=${intent?.action}")

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
                Log.d(TAG, "onStartCommand: service running")
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.i(TAG, "onDestroy: releasing DSP resources")

        engine?.release()
        engine = null

        sessionManager?.destroy()
        sessionManager = null

        effectsController = null
        methodChannel = null

        flutterEngine?.destroy()
        flutterEngine = null

        super.onDestroy()
    }

    private fun setupMethodChannel() {
        val existingEngine = FlutterEngineCache.getInstance().get("aura_main_engine")

        val dartExecutor = if (existingEngine != null) {
            Log.i(TAG, "setupMethodChannel: using cached FlutterEngine")
            flutterEngine = existingEngine as FlutterEngine
            existingEngine.dartExecutor
        } else {
            Log.i(TAG, "setupMethodChannel: creating headless FlutterEngine")
            flutterEngine = FlutterEngine(applicationContext)
            flutterEngine!!.dartExecutor
        }

        methodChannel = MethodChannel(dartExecutor.binaryMessenger, NativeEqualizerChannel.CHANNEL_NAME)
        methodChannel!!.setMethodCallHandler(
            NativeEqualizerChannel(engine!!, sessionManager!!, effectsController!!)
        )

        Log.i(TAG, "setupMethodChannel: MethodChannel registered")
    }

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
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }
}
