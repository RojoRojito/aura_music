package com.daviddev.aura_music.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.daviddev.aura_music.MainActivity
import com.daviddev.aura_music.audio.AudioSessionManager
import com.daviddev.aura_music.audio.DspPrefs
import com.daviddev.aura_music.audio.EqualizerEngine
import com.daviddev.aura_music.audio.EffectsController

/**
 * EqualizerForegroundService — Persistent DSP service that keeps the equalizer
 * engine alive independently from the Flutter UI lifecycle.
 *
 * Architecture (inspired by Flow Equalizer):
 * - Owns EqualizerEngine, AudioSessionManager, EffectsController
 * - Shows a persistent notification (required for foreground services)
 * - Survives activity recreation, app backgrounding, configuration changes
 * - NO headless FlutterEngine — communication via broadcast intents
 * - Restores DSP state from DspPrefs on creation
 * - Stores pending config for automatic session recovery
 * - Stopped explicitly by Flutter or when audio session ends
 *
 * Lifecycle:
 * 1. Started by Flutter via MethodChannel or by BootCompleteReceiver/SessionChangeService
 * 2. DSP engine initialized in onCreate(), state restored from DspPrefs
 * 3. Audio session connected via AudioSessionReceiver → SessionChangeService
 * 4. Notification with PendingIntent to reopen app
 * 5. Stopped via ACTION_STOP intent
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

        fun reinitialize(context: Context) {
            val intent = Intent(context, EqualizerForegroundService::class.java).apply {
                action = ACTION_REINITIALIZE
            }
            context.startService(intent)
            Log.i(TAG, "reinitialize: EqualizerForegroundService reinitialize requested")
        }
    }

    private lateinit var dspPrefs: DspPrefs

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate: initializing DSP engine")

        createNotificationChannel()
        dspPrefs = DspPrefs(applicationContext)

        engine = EqualizerEngine(applicationContext)
        sessionManager = AudioSessionManager()
        effectsController = EffectsController(engine!!)

        sessionManager!!.bindEngine(engine!!)

        // Restore DSP state from persistence and store as pending config
        restoreDspState()

        Log.i(TAG, "onCreate: DSP engine initialized, mode=${engine!!.getEngineMode()}")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: action=${intent?.action}")

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
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

        super.onDestroy()
    }

    /**
     * Restore DSP state from DspPrefs and store as pending config.
     * Called after engine initialization to apply saved configuration.
     * The pending config ensures automatic recovery on session changes.
     */
    private fun restoreDspState() {
        val config = dspPrefs.loadConfig()
        Log.i(TAG, "restoreDspState: preset=${config.presetName}, bands=${config.bandGains.size}, bass=${config.bassBoost}dB")

        // Store as pending config for automatic session recovery
        sessionManager?.storePendingConfig(
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

        // Apply EQ enabled state
        effectsController?.setEqEnabled(config.eqEnabled)

        // Apply band gains
        if (config.bandGains.isNotEmpty()) {
            engine?.setAllBandGains(config.bandGains)
        }

        // Apply bass
        engine?.setBassBoost(config.bassBoost)
        engine?.setBassFrequency(config.bassFrequencyHz)

        // Apply virtualizer
        engine?.setVirtualizer(config.virtualizer)

        // Apply loudness
        engine?.setLoudness(config.loudness)
        engine?.setLoudnessEnabled(config.loudnessEnabled)

        // Apply limiter
        engine?.setLimiterEnabled(config.limiterEnabled)
        engine?.setLimiterParams(
            config.limiterThreshold,
            config.limiterRatio,
            config.limiterAttack,
            config.limiterRelease,
            config.limiterPostGain
        )

        Log.i(TAG, "restoreDspState: DSP state restored and stored as pending config")
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
        // PendingIntent to reopen the app when notification is tapped
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val engineStatus = engine?.getEngineMode() ?: "inactive"
        val statusText = when (engineStatus) {
            "dynamics_processing" -> "DSP Engine active"
            "legacy" -> "EQ active (legacy mode)"
            else -> "EQ inactive"
        }

        return builder
            .setContentTitle("AURA Music — Equalizer")
            .setContentText(statusText)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }
}
