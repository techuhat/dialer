package com.techuhat.umar.bridge

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Native → Flutter call events. Events are held until Dart calls `listen`, because a message
 * sent before Dart has a handler is dropped (or squeezed into a one-slot buffer).
 */
object CallEventDispatcher {
    const val CHANNEL = "app.call_manager/call"

    private const val MAX_PENDING = 50
    private const val MAX_PENDING_AGE_MS = 30_000L

    /** State snapshots: only the newest one is worth replaying. */
    private val REPLACEABLE = setOf("callsChanged", "audioStateChanged")

    private class Event(val method: String, val args: Any?, val at: Long = SystemClock.elapsedRealtime())

    private val main = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<Event>()
    private var channel: MethodChannel? = null
    private var listening = false

    fun attach(messenger: BinaryMessenger) {
        main.post {
            channel = MethodChannel(messenger, CHANNEL)
            listening = false
        }
    }

    fun detach() {
        main.post {
            channel = null
            listening = false
        }
    }

    fun onDartListening() {
        main.post {
            listening = true
            val cutoff = SystemClock.elapsedRealtime() - MAX_PENDING_AGE_MS
            while (pending.isNotEmpty()) {
                val event = pending.removeFirst()
                if (event.at >= cutoff) send(event)
            }
        }
    }

    fun emit(method: String, args: Any? = null) {
        main.post {
            val event = Event(method, args)
            if (listening && channel != null) {
                send(event)
                return@post
            }
            if (method in REPLACEABLE) pending.removeAll { it.method == method }
            if (pending.size >= MAX_PENDING) pending.removeFirst()
            pending.addLast(event)
        }
    }

    private fun send(event: Event) {
        channel?.invokeMethod(event.method, event.args)
    }
}
