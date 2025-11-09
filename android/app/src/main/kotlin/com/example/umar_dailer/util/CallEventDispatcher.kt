package com.example.umar_dailer.util

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object CallEventDispatcher {
    private const val TAG = "CallEventDispatcher"

    @Volatile
    private var channel: MethodChannel? = null

    @Volatile
    private var messenger: BinaryMessenger? = null

    @Volatile
    private var channelName: String? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingEvents = mutableListOf<Pair<String, Map<String, Any>>>()

    @Synchronized
    fun initialize(binaryMessenger: BinaryMessenger, name: String) {
        Log.d(TAG, "Initializing with messenger: $binaryMessenger, channel=$name")
        messenger = binaryMessenger
        channelName = name
        // Rebind the channel immediately
        bindChannel(MethodChannel(binaryMessenger, name))
    }

    @Synchronized
    fun bindChannel(methodChannel: MethodChannel) {
        Log.d(TAG, "Binding MethodChannel instance: $methodChannel")
        channel = methodChannel
    drainPendingEvents(methodChannel, Looper.myLooper() == Looper.getMainLooper())
    }

    fun emitIncomingCall(number: String?) {
        Log.d(TAG, "emitIncomingCall: $number")
        invoke("incomingCall", mapOf("number" to (number ?: "Unknown")))
    }

    fun emitIncomingCallConnected(number: String?) {
        Log.d(TAG, "emitIncomingCallConnected: $number")
        invoke("incomingCallConnected", mapOf("number" to (number ?: "Unknown")))
    }

    fun emitOutgoingCall(number: String?) {
        Log.d(TAG, "emitOutgoingCall: $number")
        invoke("outgoingCall", mapOf("number" to (number ?: "Unknown")))
    }

    fun emitOutgoingCallConnected(number: String?) {
        Log.d(TAG, "emitOutgoingCallConnected: $number")
        invoke("outgoingCallConnected", mapOf("number" to (number ?: "Unknown")))
    }

    fun emitCallEnded() {
        Log.d(TAG, "emitCallEnded")
        invoke("callEnded", emptyMap<String, Any>())
    }

    private fun invoke(method: String, arguments: Map<String, Any>) {
        val channel = ensureChannel()
        if (channel == null) {
            Log.w(TAG, "MethodChannel not bound; queuing event $method")
            enqueueEvent(method, arguments)
            return
        }

        val deliverOnMainThread = Looper.myLooper() == Looper.getMainLooper()
        drainPendingEvents(channel, deliverOnMainThread)

        if (deliverOnMainThread) {
            channel.invokeMethod(method, arguments)
        } else {
            mainHandler.post {
                ensureChannel()?.invokeMethod(method, arguments)
            }
        }
    }

    @Synchronized
    private fun ensureChannel(): MethodChannel? {
        channel?.let { return it }

        val binaryMessenger = messenger
        val name = channelName
        if (binaryMessenger != null && name != null) {
            Log.d(TAG, "Creating MethodChannel from messenger for $name")
            channel = MethodChannel(binaryMessenger, name)
            channel?.let { drainPendingEvents(it, Looper.myLooper() == Looper.getMainLooper()) }
        }
        return channel
    }

    private fun enqueueEvent(method: String, arguments: Map<String, Any>) {
        synchronized(pendingEvents) {
            pendingEvents.add(method to arguments)
        }
    }

    private fun drainPendingEvents(boundChannel: MethodChannel, deliverOnMainThread: Boolean) {
        val events: List<Pair<String, Map<String, Any>>>
        synchronized(pendingEvents) {
            if (pendingEvents.isEmpty()) {
                return
            }
            events = pendingEvents.toList()
            pendingEvents.clear()
        }

        val deliver: () -> Unit = {
            for ((pendingMethod, pendingArgs) in events) {
                Log.d(TAG, "Dispatching queued event: $pendingMethod")
                boundChannel.invokeMethod(pendingMethod, pendingArgs)
            }
        }

        if (deliverOnMainThread && Looper.myLooper() == Looper.getMainLooper()) {
            deliver()
        } else {
            mainHandler.post(deliver)
        }
    }
}
