package com.daviddev.aura_music.audio

import android.util.Log

/**
 * AudioSessionManager — Manages audio session lifecycle for the DSP engine.
 *
 * Architecture (inspired by Flow Equalizer):
 * - Tracks the current audio session ID from just_audio
 * - Detects session changes and triggers automatic DSP reconnection
 * - Stores pending configuration to reapply on new sessions
 * - Handles session release, recreation, and recovery gracefully
 *
 * Session lifecycle:
 * 1. onNewSessionId(sessionId) — called when just_audio provides a valid session
 * 2. Engine initSession(sessionId) — DSP engine connects to the session
 * 3. onSessionClosed() — called when session ends (optional, DSP auto-reconnects)
 * 4. Recovery — if session changes, DSP automatically reconnects and reapplies config
 *
 * Thread safety: all public methods are synchronized.
 */
class AudioSessionManager {

    companion object {
        private const val TAG = "AURA_SESSION_MGR"
        const val INVALID_SESSION_ID = -1
        const val UNINITIALIZED_SESSION_ID = 0
    }

    interface SessionListener {
        fun onSessionConnected(sessionId: Int)
        fun onSessionDisconnected(sessionId: Int)
        fun onSessionError(sessionId: Int, error: String)
    }

    private var currentSessionId: Int = INVALID_SESSION_ID
    private var isSessionValid: Boolean = false
    private var engine: EqualizerEngine? = null
    private var listener: SessionListener? = null

    // Pending configuration — stored to reapply on session changes
    private var pendingConfig: PendingConfig? = null

    data class PendingConfig(
        val enabled: Boolean = true,
        val bandGains: List<Double> = emptyList(),
        val bassBoost: Double = 0.0,
        val bassFrequencyHz: Int = 80,
        val virtualizer: Double = 0.0,
        val loudness: Double = 0.0,
        val loudnessEnabled: Boolean = false,
        val limiterEnabled: Boolean = false,
        val limiterThreshold: Double = -3.0,
        val limiterRatio: Double = 20.0,
        val limiterAttack: Double = 5.0,
        val limiterRelease: Double = 100.0,
        val limiterPostGain: Double = 0.0
    )

    fun bindEngine(engine: EqualizerEngine) {
        this.engine = engine
        Log.i(TAG, "Engine bound to AudioSessionManager")
    }

    fun setListener(listener: SessionListener?) {
        this.listener = listener
    }

    /**
     * Store pending configuration to reapply on session changes.
     * Called whenever DSP state changes so it survives session transitions.
     */
    @Synchronized
    fun storePendingConfig(config: PendingConfig) {
        pendingConfig = config
        Log.d(TAG, "storePendingConfig: enabled=${config.enabled}, bands=${config.bandGains.size}")
    }

    @Synchronized
    fun getPendingConfig(): PendingConfig? = pendingConfig

    /**
     * Handle a new audio session ID from just_audio.
     * This is called every time the session changes (new song, player recreation, etc).
     *
     * Returns true if the session was successfully connected, false otherwise.
     */
    @Synchronized
    fun onNewSessionId(sessionId: Int): Boolean {
        Log.i(TAG, "onNewSessionId: sessionId=$sessionId (previous=$currentSessionId)")

        when {
            sessionId == UNINITIALIZED_SESSION_ID -> {
                Log.w(TAG, "onNewSessionId: sessionId=0 (uninitialized), ignoring")
                return false
            }
            sessionId < 0 -> {
                Log.w(TAG, "onNewSessionId: sessionId=$sessionId (invalid), ignoring")
                return false
            }
        }

        val previousSessionId = currentSessionId

        // If session changed, release old session first
        if (sessionId != previousSessionId) {
            Log.i(TAG, "Session changed: $previousSessionId → $sessionId")
            if (previousSessionId > 0) {
                listener?.onSessionDisconnected(previousSessionId)
            }
            currentSessionId = sessionId
            isSessionValid = false
        }

        // Initialize DSP engine with new session
        val engineRef = engine
        if (engineRef == null) {
            Log.e(TAG, "onNewSessionId: engine not bound")
            listener?.onSessionError(sessionId, "Engine not bound")
            return false
        }

        try {
            engineRef.initSession(sessionId)
            isSessionValid = engineRef.isReady()

            if (isSessionValid) {
                Log.i(TAG, "Session connected: $sessionId, mode=${engineRef.getEngineMode()}")
                listener?.onSessionConnected(sessionId)

                // Reapply pending configuration if available
                pendingConfig?.let { config ->
                    Log.i(TAG, "Reapplying pending config on session $sessionId")
                    reapplyConfig(engineRef, config)
                }
            } else {
                Log.w(TAG, "Session connected but engine not ready: $sessionId")
                listener?.onSessionError(sessionId, "Engine not ready after init")
            }
        } catch (e: Exception) {
            Log.e(TAG, "onNewSessionId: exception during init", e)
            isSessionValid = false
            listener?.onSessionError(sessionId, e.message ?: "Unknown error")
            return false
        }

        return isSessionValid
    }

    /**
     * Handle session closure.
     * The DSP engine will be released, but pending config is preserved for recovery.
     */
    @Synchronized
    fun onSessionClosed() {
        val oldSessionId = currentSessionId
        Log.i(TAG, "onSessionClosed: sessionId=$oldSessionId")
        isSessionValid = false

        engine?.release()
        currentSessionId = INVALID_SESSION_ID

        listener?.onSessionDisconnected(oldSessionId)
    }

    /**
     * Reinitialize the current session without changing the session ID.
     * Useful after app recreation or configuration changes.
     */
    @Synchronized
    fun reinitializeCurrentSession() {
        val sessionId = currentSessionId
        if (sessionId > 0) {
            Log.i(TAG, "reinitializeCurrentSession: sessionId=$sessionId")
            engine?.release()
            engine?.initSession(sessionId)
            isSessionValid = engine?.isReady() == true

            if (isSessionValid) {
                pendingConfig?.let { config ->
                    Log.i(TAG, "Reapplying pending config after reinit")
                    reapplyConfig(engine!!, config)
                }
            }
        } else {
            Log.w(TAG, "reinitializeCurrentSession: no valid session to reinitialize")
        }
    }

    /**
     * Check if the current session is valid and the engine is ready.
     */
    fun hasValidSession(): Boolean = isSessionValid

    /**
     * Get the current session ID.
     */
    fun getSessionId(): Int = currentSessionId

    /**
     * Clean up resources.
     */
    fun destroy() {
        Log.i(TAG, "destroy: cleaning up AudioSessionManager")
        onSessionClosed()
        engine = null
        listener = null
    }

    /**
     * Reapply stored configuration to the DSP engine.
     */
    private fun reapplyConfig(engine: EqualizerEngine, config: PendingConfig) {
        try {
            engine.setEnabled(config.enabled)

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

            Log.i(TAG, "Config reapplied successfully")
        } catch (e: Exception) {
            Log.e(TAG, "reapplyConfig ERROR", e)
        }
    }
}
