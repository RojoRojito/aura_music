package com.daviddev.aura_music

import android.content.Context
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.PlaybackParameters
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.Renderer
import com.google.android.exoplayer2.audio.AudioRendererEventListener
import com.google.android.exoplayer2.audio.AudioSink
import com.google.android.exoplayer2.audio.DefaultAudioSink
import com.google.android.exoplayer2.audio.MediaCodecAudioRenderer
import com.google.android.exoplayer2.mediacodec.MediaCodecSelector
import com.google.android.exoplayer2.DefaultRenderersFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCallHandler

class MainActivity : FlutterActivity(), MethodCallHandler {
    private val TAG = "AuraEQ"

    // Equalizer channel
    private val eqChannelName = "com.daviddev.aura/equalizer"
    private lateinit var equalizerEngine: EqualizerEngine
    private lateinit var eqMethodChannel: MethodChannel
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId = -1
    private var isEnabled = true
    private var currentBassBoostGain = 0f
    private var currentVirtualizerStrength = 0f
    private val currentBandGains = FloatArray(12) { 0f }

    // Player channel
    private val playerChannelName = "com.daviddev.aura/player"
    private val playerEventsName = "com.daviddev.aura/player_events"
    private lateinit var playerMethodChannel: MethodChannel
    private lateinit var playerEventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var exoPlayer: ExoPlayer? = null
    private lateinit var auraAudioProcessor: AuraAudioProcessor
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d(TAG, "configureFlutterEngine: initializing")
        super.configureFlutterEngine(flutterEngine)

        // Initialize equalizer engine
        equalizerEngine = EqualizerEngine()
        auraAudioProcessor = AuraAudioProcessor(equalizerEngine)

        // Equalizer MethodChannel
        eqMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, eqChannelName)
        eqMethodChannel.setMethodCallHandler(this)

        // Player MethodChannel
        playerMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, playerChannelName)
        playerMethodChannel.setMethodCallHandler { call, result ->
            handlePlayerCall(call, result)
        }

        // Player EventChannel
        playerEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, playerEventsName)
        playerEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "EventChannel: listener attached")
                sendPlayerState()
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d(TAG, "EventChannel: listener detached")
            }
        })

        // Create ExoPlayer with custom audio processor
        initExoPlayer()

        Log.d(TAG, "All channels registered")
    }

    private fun initExoPlayer() {
        val renderersFactory = object : DefaultRenderersFactory(this) {
            override fun buildAudioRenderers(
                context: Context,
                extensionRendererMode: Int,
                mediaCodecSelector: MediaCodecSelector,
                enableDecoderFallback: Boolean,
                audioSink: AudioSink,
                eventHandler: Handler,
                eventListener: AudioRendererEventListener,
                out: ArrayList<Renderer>
            ) {
                val customSink = DefaultAudioSink.Builder()
                    .setAudioProcessors(arrayOf(auraAudioProcessor))
                    .build()
                val renderer = MediaCodecAudioRenderer(
                    context,
                    mediaCodecSelector,
                    enableDecoderFallback,
                    eventHandler,
                    eventListener,
                    customSink
                )
                out.add(renderer)
            }
        }

        exoPlayer = ExoPlayer.Builder(this)
            .setRenderersFactory(renderersFactory)
            .build()

        exoPlayer?.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                sendPlayerState()
            }
            override fun onPlaybackStateChanged(playbackState: Int) {
                sendPlayerState()
                if (playbackState == Player.STATE_READY) {
                    val sessionId = getAudioSessionId()
                    if (sessionId != null && sessionId != 0 && sessionId != currentSessionId) {
                        currentSessionId = sessionId
                        initAudioEffects(sessionId)
                    }
                }
            }
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                sendPlayerState()
            }
            override fun onEvents(player: Player, events: Player.Events) {
                sendPlayerState()
            }
        })

        // Position updater
        val positionRunnable = object : Runnable {
            override fun run() {
                if (exoPlayer?.isPlaying == true) {
                    sendPlayerState()
                }
                handler.postDelayed(this, 200)
            }
        }
        handler.postDelayed(positionRunnable, 200)

        Log.d(TAG, "ExoPlayer initialized with AuraAudioProcessor")
    }

    private fun getAudioSessionId(): Int? {
        return try {
            val player = exoPlayer ?: return null
            // ExoPlayer 2.x audio session ID
            val field = player.javaClass.superclass?.declaredFields?.find {
                it.name == "audioSessionId" || it.name == "auxEffectInfo"
            }
            // Try to get it from the audio renderer
            for (i in 0 until player.rendererCount) {
                val renderer = player.getRenderer(i)
                if (renderer.javaClass.simpleName.contains("Audio", ignoreCase = true)) {
                    try {
                        val sinkField = renderer.javaClass.declaredFields.find {
                            it.type.name.contains("AudioSink") || it.name.contains("sink")
                        }
                        if (sinkField != null) {
                            sinkField.isAccessible = true
                            val sink = sinkField.get(renderer)
                            val sessionMethod = sink?.javaClass?.methods?.find {
                                it.name == "getAudioSessionId" && it.parameterCount == 0
                            }
                            if (sessionMethod != null) {
                                return sessionMethod.invoke(sink) as? Int
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not get session ID from renderer: $e")
                    }
                }
            }
            // Fallback: return 0 for default session
            0
        } catch (e: Exception) {
            Log.w(TAG, "getAudioSessionId error: $e")
            0
        }
    }

    private fun sendPlayerState() {
        val player = exoPlayer ?: return
        val sink = eventSink ?: return

        val state = mapOf(
            "position" to player.currentPosition,
            "duration" to player.duration.coerceAtLeast(0),
            "playing" to player.isPlaying,
            "processingState" to mapProcessingState(player.playbackState),
            "sessionId" to currentSessionId,
            "loopMode" to mapLoopMode(player.repeatMode),
            "speed" to player.playbackParameters.speed
        )

        handler.post {
            try {
                sink.success(state)
            } catch (e: Exception) {
                Log.w(TAG, "sendPlayerState error: $e")
            }
        }
    }

    private fun mapProcessingState(state: Int): Int {
        return when (state) {
            Player.STATE_IDLE -> 0
            Player.STATE_BUFFERING -> 2
            Player.STATE_READY -> 3
            Player.STATE_ENDED -> 4
            else -> 0
        }
    }

    private fun mapLoopMode(mode: Int): Int {
        return when (mode) {
            Player.REPEAT_MODE_OFF -> 0
            Player.REPEAT_MODE_ONE -> 1
            Player.REPEAT_MODE_ALL -> 2
            else -> 0
        }
    }

    // ---- Player MethodChannel handler ----

    private fun handlePlayerCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setAudioSource" -> {
                val uri = call.argument<String>("uri") ?: ""
                Log.d(TAG, "setAudioSource: $uri")
                try {
                    exoPlayer?.setMediaItem(MediaItem.fromUri(uri))
                    exoPlayer?.prepare()
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "setAudioSource error: $e")
                    result.error("SET_SOURCE_ERROR", e.message, null)
                }
            }
            "play" -> {
                exoPlayer?.play()
                result.success(null)
            }
            "pause" -> {
                exoPlayer?.pause()
                result.success(null)
            }
            "seek" -> {
                val positionMs = call.argument<Int>("position") ?: 0
                exoPlayer?.seekTo(positionMs.toLong())
                result.success(null)
            }
            "setLoopMode" -> {
                val mode = call.argument<Int>("mode") ?: 0
                exoPlayer?.repeatMode = when (mode) {
                    1 -> Player.REPEAT_MODE_ONE
                    2 -> Player.REPEAT_MODE_ALL
                    else -> Player.REPEAT_MODE_OFF
                }
                result.success(null)
            }
            "setSpeed" -> {
                val speed = call.argument<Double>("speed") ?: 1.0
                exoPlayer?.playbackParameters = PlaybackParameters(speed.toFloat())
                result.success(null)
            }
            "setShuffleMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                exoPlayer?.shuffleModeEnabled = enabled
                result.success(null)
            }
            "dispose" -> {
                exoPlayer?.release()
                exoPlayer = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- Equalizer MethodChannel handler (existing) ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initSession" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                Log.d(TAG, "initSession: $sessionId")
                initAudioEffects(sessionId)
                result.success(null)
            }
            "setBandGain" -> {
                val index = call.argument<Int>("index") ?: 0
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                applyBandGain(index, gainDb.toFloat())
                equalizerEngine.setBandGain(index, gainDb.toFloat())
                result.success(null)
            }
            "setBassBoost" -> {
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                applyBassBoost(gainDb.toFloat())
                equalizerEngine.setBassBoost(gainDb.toFloat())
                result.success(null)
            }
            "setVirtualizer" -> {
                val strength = call.argument<Double>("strength") ?: 0.0
                applyVirtualizer(strength.toFloat())
                equalizerEngine.setVirtualizerStrength(strength.toFloat())
                result.success(null)
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                isEnabled = enabled
                try {
                    equalizer?.enabled = enabled
                    bassBoost?.enabled = enabled
                    virtualizer?.enabled = enabled
                    equalizerEngine.setEnabled(enabled)
                } catch (e: Exception) {
                    Log.e(TAG, "setEnabled error: $e")
                }
                result.success(null)
            }
            "reset" -> {
                for (i in 0 until 12) {
                    currentBandGains[i] = 0f
                    try { equalizer?.setBandLevel(i.toShort(), 0) } catch (_: Exception) {}
                    equalizerEngine.setBandGain(i, 0f)
                }
                currentBassBoostGain = 0f
                currentVirtualizerStrength = 0f
                try {
                    bassBoost?.setStrength(0.toShort())
                    virtualizer?.setStrength(0.toShort())
                } catch (_: Exception) {}
                equalizerEngine.setBassBoost(0f)
                equalizerEngine.setVirtualizerStrength(0f)
                result.success(null)
            }
            "getState" -> {
                result.success(mapOf(
                    "enabled" to isEnabled,
                    "bandCount" to 12,
                    "frequencies" to intArrayOf(31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000).toList()
                ))
            }
            else -> result.notImplemented()
        }
    }

    // ---- Audio effects (existing logic) ----

    private fun initAudioEffects(sessionId: Int) {
        if (sessionId == currentSessionId && equalizer != null) {
            Log.d(TAG, "initAudioEffects: same sessionId=$sessionId, skipping")
            return
        }
        Log.d(TAG, "initAudioEffects: sessionId=$sessionId")
        try { equalizer?.release() } catch (_: Exception) {}
        try { bassBoost?.release() } catch (_: Exception) {}
        try { virtualizer?.release() } catch (_: Exception) {}

        try {
            equalizer = Equalizer(0, sessionId)
            equalizer?.enabled = isEnabled
            for (i in 0 until 12) {
                applyBandGain(i, currentBandGains[i])
            }
            Log.d(TAG, "Equalizer created OK")
        } catch (e: Exception) {
            Log.e(TAG, "Equalizer error: $e")
        }

        try {
            bassBoost = BassBoost(0, sessionId)
            bassBoost?.enabled = isEnabled
            applyBassBoost(currentBassBoostGain)
            Log.d(TAG, "BassBoost created OK")
        } catch (e: Exception) {
            Log.e(TAG, "BassBoost error: $e")
        }

        try {
            virtualizer = Virtualizer(0, sessionId)
            virtualizer?.enabled = isEnabled
            applyVirtualizer(currentVirtualizerStrength)
            Log.d(TAG, "Virtualizer created OK")
        } catch (e: Exception) {
            Log.e(TAG, "Virtualizer error: $e")
        }
        currentSessionId = sessionId
    }

    private fun applyBandGain(index: Int, gainDb: Float) {
        currentBandGains[index] = gainDb
        try {
            val eq = equalizer ?: return
            val band = index.toShort()
            val range = eq.bandLevelRange
            val minLevel = range[0]
            val maxLevel = range[1]
            val actualBands = eq.numberOfBands
            if (actualBands <= 0) return
            val mappedBand = ((index.toFloat() / 12f) * actualBands).toInt().coerceIn(0, actualBands - 1)
            val level = ((gainDb / 12f) * maxLevel).toInt().coerceIn(minLevel.toInt(), maxLevel.toInt())
            eq.setBandLevel(mappedBand.toShort(), level.toShort())
        } catch (e: Exception) {
            Log.e(TAG, "applyBandGain error: $e")
        }
    }

    private fun applyBassBoost(gainDb: Float) {
        currentBassBoostGain = gainDb
        try {
            bassBoost?.setStrength(((gainDb / 15f) * 1000).toInt().coerceIn(0, 1000).toShort())
        } catch (e: Exception) {
            Log.e(TAG, "applyBassBoost error: $e")
        }
    }

    private fun applyVirtualizer(strength: Float) {
        currentVirtualizerStrength = strength
        try {
            virtualizer?.setStrength((strength * 1000).toInt().coerceIn(0, 1000).toShort())
        } catch (e: Exception) {
            Log.e(TAG, "applyVirtualizer error: $e")
        }
    }

    override fun onDestroy() {
        try { equalizer?.release() } catch (_: Exception) {}
        try { bassBoost?.release() } catch (_: Exception) {}
        try { virtualizer?.release() } catch (_: Exception) {}
        exoPlayer?.release()
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
