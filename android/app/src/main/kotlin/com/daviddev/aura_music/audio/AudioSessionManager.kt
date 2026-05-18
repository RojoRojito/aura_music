package com.daviddev.aura_music.audio

import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * AudioSessionManager — Manages audio session lifecycle for the DSP engine.
 *
 * Responsibilities:
 * - Track the current audio session ID from just_audio
 * - Detect session changes (new session, session released)
 * - Notify EqualizerEngine when session changes occur
 * - Handle invalid/released session IDs gracefully
 *
 * Session flow:
 * 1. just_audio creates a new AudioTrack → gets new sessionId
 * 2. Flutter receives sessionId via androidAudioSessionId stream
 * 3. Flutter calls initSession via MethodChannel
 * 4. AudioSessionManager validates and forwards to EqualizerEngine
 * 5. On session release, AudioSessionManager triggers cleanup
 *
 * Thread safety:
 * - All state changes are synchronized
 * - StateFlow provides reactive observation
 */
class AudioSessionManager {

    companion object {
        private const val TAG = "AURA_SESSION_MGR"
        const val INVALID_SESSION_ID = -1
        const val UNINITIALIZED_SESSION_ID = 0
    }

    private var _currentSessionId = MutableStateFlow(INVALID_SESSION_ID)
    val currentSessionId: StateFlow<Int> = _currentSessionId.asStateFlow()

    private var _isSessionValid = MutableStateFlow(false)
    val isSessionValid: StateFlow<Boolean> = _isSessionValid.asStateFlow()

    private var engine: EqualizerEngine? = null

    /**
     * Bind the session manager to an EqualizerEngine instance.
     * Must be called before any session operations.
     */
    fun bindEngine(engine: EqualizerEngine) {
        this.engine = engine
        Log.i(TAG, "Engine bound to AudioSessionManager")
    }

    /**
     * Handle a new session ID from Flutter/just_audio.
     *
     * Validates the session ID and triggers engine reconnection if needed.
     *
     * @param sessionId The audio session ID from just_audio's androidAudioSessionId
     * @return true if the session was accepted and engine was initialized
     */
    @Synchronized
    fun onNewSessionId(sessionId: Int): Boolean {
        Log.i(TAG, "onNewSessionId: sessionId=$sessionId")

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

        val previousSessionId = _currentSessionId.value

        // If session changed, the engine will handle reconnection internally
        if (sessionId != previousSessionId) {
            Log.i(TAG, "Session changed: $previousSessionId → $sessionId")
            _currentSessionId.value = sessionId
            _isSessionValid.value = true

            // Forward to engine
            engine?.initSession(sessionId)
            return true
        }

        // Same session — engine is already configured
        Log.d(TAG, "Session unchanged: $sessionId")
        return true
    }

    /**
     * Handle session closure.
     * Called when the audio session is released or becomes invalid.
     */
    @Synchronized
    fun onSessionClosed() {
        Log.i(TAG, "onSessionClosed: releasing DSP engine")
        _isSessionValid.value = false

        engine?.release()
        _currentSessionId.value = INVALID_SESSION_ID
    }

    /**
     * Check if the current session is still valid.
     * Returns false if no session has been established or session was closed.
     */
    fun hasValidSession(): Boolean = _isSessionValid.value

    /**
     * Get the current session ID (may be INVALID_SESSION_ID if no session).
     */
    fun getSessionId(): Int = _currentSessionId.value

    /**
     * Force reinitialize the current session.
     * Useful after app recreation or configuration changes.
     */
    @Synchronized
    fun reinitializeCurrentSession() {
        val sessionId = _currentSessionId.value
        if (sessionId > 0) {
            Log.i(TAG, "reinitializeCurrentSession: sessionId=$sessionId")
            engine?.initSession(sessionId)
        } else {
            Log.w(TAG, "reinitializeCurrentSession: no valid session to reinitialize")
        }
    }

    /**
     * Clean up the session manager.
     */
    fun destroy() {
        Log.i(TAG, "destroy: cleaning up AudioSessionManager")
        onSessionClosed()
        engine = null
    }
}
