package com.techuhat.umar.services

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService
import com.techuhat.umar.MainActivity
import com.techuhat.umar.bridge.CallEventDispatcher
import com.techuhat.umar.call.CallAudio
import com.techuhat.umar.call.CallController
import com.techuhat.umar.call.CallRegistry
import com.techuhat.umar.call.NetworkNames
import com.techuhat.umar.call.TrackedCall
import com.techuhat.umar.notification.CallNotifier

/**
 * Telecom's link to this dialer. Keeps [CallRegistry] current and turns every change into
 * Flutter events (`callsChanged` + lifecycle events) and refreshed notifications.
 */
class MyCallService : InCallService() {
    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) = onCallChanged(call)
        override fun onDetailsChanged(call: Call, details: Call.Details) = onCallChanged(call)
        override fun onParentChanged(call: Call, newParent: Call?) = publish()
        override fun onConferenceableCallsChanged(call: Call, conferenceableCalls: MutableList<Call>) = publish()
    }

    override fun onCreate() {
        super.onCreate()
        CallRegistry.service = this
        CallNotifier.clear(this) // left behind if the previous process died mid-call
    }

    override fun onDestroy() {
        CallNotifier.clear(this)
        CallRegistry.clear()
        CallRegistry.service = null
        super.onDestroy()
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        val tracked = TrackedCall(call, this)
        val waiting = tracked.isIncoming && CallRegistry.liveCount() > 0
        CallRegistry.add(tracked)
        call.registerCallback(callback)
        if (tracked.state == Call.STATE_ACTIVE || tracked.state == Call.STATE_HOLDING) tracked.markConnected()
        publish()

        when {
            tracked.connectedAt != null -> emitConnected(tracked) // already up when Telecom (re)bound us
            !tracked.isIncoming -> {
                emit("outgoingCall", tracked)
                if (MainActivity.visible == null) MainActivity.showCallScreen(this)
            }
            waiting -> emit("callWaiting", tracked, mapOf("isCallWaiting" to true))
            else -> emit("incomingCall", tracked)
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        call.unregisterCallback(callback)
        CallRegistry.remove(call)?.let { tracked ->
            tracked.networkName?.let { NetworkNames.remember(this, tracked.number, it) }
            reportEnded(tracked)
        }
        publish()
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onCallAudioStateChanged(audioState: CallAudioState) {
        super.onCallAudioStateChanged(audioState)
        CallEventDispatcher.emit("audioStateChanged", CallAudio.toMap(audioState))
        CallNotifier.refresh(this)
    }

    private fun onCallChanged(call: Call) {
        val tracked = CallRegistry[call] ?: return
        val firstConnect = tracked.state == Call.STATE_ACTIVE && tracked.connectedAt == null
        if (firstConnect) tracked.markConnected()
        publish()
        if (firstConnect) {
            emitConnected(tracked)
            if (!tracked.isIncoming) vibrate()
        }
        if (tracked.state == Call.STATE_DISCONNECTED) reportEnded(tracked)
    }

    private fun publish() {
        CallEventDispatcher.emit("callsChanged", CallRegistry.snapshot(this))
        CallNotifier.refresh(this)
        MainActivity.visible?.syncLockScreenAccess()
    }

    private fun emitConnected(tracked: TrackedCall) =
        emit(if (tracked.isIncoming) "incomingCallConnected" else "outgoingCallConnected", tracked)

    /** Once per call, whichever comes first: DISCONNECTED or removal. */
    private fun reportEnded(tracked: TrackedCall) {
        if (tracked.endReported) return
        tracked.endReported = true
        val extra = mapOf("remainingCalls" to CallRegistry.liveCount(except = tracked), "reason" to tracked.endReason())
        emit("callEnded", tracked, extra)
        if (tracked.answerRingingOnDisconnect) CallController.answer()
    }

    private fun emit(method: String, tracked: TrackedCall, extra: Map<String, Any?> = emptyMap()) =
        CallEventDispatcher.emit(method, tracked.eventPayload(this, extra))

    private fun vibrate() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            getSystemService(Vibrator::class.java)
        }
        if (vibrator?.hasVibrator() != true) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(CONNECT_VIBRATION_MS, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(CONNECT_VIBRATION_MS)
        }
    }

    private companion object {
        const val CONNECT_VIBRATION_MS = 80L
    }
}
