package com.techuhat.umar.call

import android.content.Context
import android.telecom.Call
import com.techuhat.umar.services.MyCallService
import com.techuhat.umar.util.SimHelper

/** Live calls of the bound InCallService. Main thread only, like every Telecom callback. */
object CallRegistry {
    var service: MyCallService? = null

    private val calls = LinkedHashMap<Call, TrackedCall>()

    /** Top-level calls; conference participants are represented by their conference. */
    val all: List<TrackedCall> get() = calls.values.filter { !it.isConferenceChild }

    fun add(tracked: TrackedCall) {
        calls[tracked.call] = tracked
    }

    fun remove(call: Call): TrackedCall? = calls.remove(call)

    operator fun get(call: Call): TrackedCall? = calls[call]

    fun clear() = calls.clear()

    fun isEmpty() = calls.isEmpty()

    fun ringing(): TrackedCall? = all.firstOrNull { it.state == Call.STATE_RINGING }

    fun inState(state: Int): TrackedCall? = all.firstOrNull { it.state == state }

    /** The call "End call", the ongoing notification and the call screen act on: never a ringing one. */
    fun foreground(): TrackedCall? =
        all.filter { it.isLive && it.state != Call.STATE_RINGING }.maxByOrNull { priority(it.state) }

    fun liveCount(except: TrackedCall? = null): Int = all.count { it !== except && it.isLive }

    fun snapshot(context: Context): Map<String, Any?> {
        val simCount = SimHelper.simCount(context)
        return mapOf(
            "calls" to all.filter { it.isLive }.map { it.toMap(context, simCount) },
            "audio" to CallAudio.toMap(CallAudio.current()),
            "simCount" to simCount,
        )
    }

    private fun priority(state: Int) = when (state) {
        Call.STATE_ACTIVE -> 3
        Call.STATE_HOLDING -> 1
        else -> 2
    }
}
