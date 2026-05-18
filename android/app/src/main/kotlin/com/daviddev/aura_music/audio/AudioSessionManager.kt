package com.daviddev.aura_music.audio

import android.util.Log

/**
 * AudioSessionManager — Manages audio session lifecycle for the DSP engine.
 *
 * Responsibilities:
 * - Track the current audio session ID from just_audio
 * - Detect session changes (new session, session released)
 * - Notify EqualizerEngine when session changes occur
 * - Handle invalid/released session IDs gracefully
 *
 * Thread safety:
 * - All state changes are synchronized
 */
class AudioSessionManager {

    companion object {
        private const val TAG = "AURA_SESSION_MGR"
        const val INVALID_SESSION_ID = -1
        const val UNINITIALIZED_SESSION_ID = 0
    }

    private var currentSessionId: Int = INVALID_SESSION_ID
    private var isSessionValid: Boolean = false
    private var engine: EqualizerEngine? = null

    fun bindEngine(engine: EqualizerEngine) {
        this.engine = engine
        Log.i(TAG, "Engine bound to AudioSessionManager")
    }

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

        val previousSessionId = currentSessionId

        if (sessionId != previousSessionId) {
            Log.i(TAG, "Session changed: $previousSessionId → $sessionId")
            currentSessionId = sessionId
            isSessionValid = true

            engine?.initSession(sessionId)
            return true
        }

        Log.d(TAG, "Session unchanged: $sessionId")
        return true
    }

    @Synchronized
    fun onSessionClosed() {
        Log.i(TAG, "onSessionClosed: releasing DSP engine")
        isSessionValid = false

        engine?.release()
        currentSessionId = INVALID_SESSION_ID
    }

    fun hasValidSession(): Boolean = isSessionValid
    fun getSessionId(): Int = currentSessionId

    @Synchronized
    fun reinitializeCurrentSession() {
        val sessionId = currentSessionId
        if (sessionId > 0) {
            Log.i(TAG, "reinitializeCurrentSession: sessionId=$sessionId")
            engine?.initSession(sessionId)
        } else {
            Log.w(TAG, "reinitializeCurrentSession: no valid session to reinitialize")
        }
    }

    fun destroy() {
        Log.i(TAG, "destroy: cleaning up AudioSessionManager")
        onSessionClosed()
        engine = null
    }
}
