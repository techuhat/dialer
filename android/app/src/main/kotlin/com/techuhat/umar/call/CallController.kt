package com.techuhat.umar.call

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.PhoneAccount
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import com.techuhat.umar.util.SimHelper

/** Every call action, shared by the Flutter channel and the notification buttons. */
object CallController {
    private const val DTMF_TONE_MS = 200L
    private val main = Handler(Looper.getMainLooper())

    fun answer(): Boolean = act(CallRegistry.ringing()) { it.answer(VideoProfile.STATE_AUDIO_ONLY) }

    /** Declines the ringing call only; with [message], Telecom texts it to the caller. */
    fun reject(message: String? = null): Boolean =
        act(CallRegistry.ringing()) { it.reject(message != null, message) }

    fun end(): Boolean {
        val target = CallRegistry.foreground() ?: return reject()
        return act(target) { it.disconnect() }
    }

    fun hold(on: Boolean): Boolean {
        val target = CallRegistry.inState(if (on) Call.STATE_ACTIVE else Call.STATE_HOLDING) ?: return false
        if (on && !target.can(Call.Details.CAPABILITY_HOLD)) return false
        return act(target) { if (on) it.hold() else it.unhold() }
    }

    /** Unholding the held call makes Telecom hold the active one, which is the swap. */
    fun swap(): Boolean {
        val active = CallRegistry.inState(Call.STATE_ACTIVE)
        if (active != null && active.can(Call.Details.CAPABILITY_SWAP_CONFERENCE)) {
            return act(active) { it.swapConference() }
        }
        return act(CallRegistry.inState(Call.STATE_HOLDING)) { it.unhold() }
    }

    fun merge(): Boolean = act(CallRegistry.foreground()) { call ->
        val other = call.conferenceableCalls.firstOrNull()
        if (other != null) call.conference(other) else call.mergeConference()
    }

    /** Telecom holds the active call itself when a waiting call is answered. */
    fun holdAndAnswer(): Boolean = answer()

    /** Answers only after the active call is gone, otherwise Telecom would hold it instead. */
    fun endAndAnswer(): Boolean {
        CallRegistry.ringing() ?: return false
        val active = CallRegistry.foreground() ?: return answer()
        active.answerRingingOnDisconnect = true
        return act(active) { it.disconnect() }
    }

    fun dtmf(digit: Char): Boolean = act(CallRegistry.inState(Call.STATE_ACTIVE)) { call ->
        call.playDtmfTone(digit)
        main.postDelayed({ call.stopDtmfTone() }, DTMF_TONE_MS)
    }

    fun mute(on: Boolean): Boolean = withService { it.setMuted(on) }

    fun route(name: String): Boolean = withService { CallAudio.setRoute(it, name) }

    fun toggleMute(): Boolean = mute(CallAudio.current()?.isMuted != true)

    fun toggleSpeaker(): Boolean =
        route(if (CallAudio.isSpeaker(CallAudio.current())) CallAudio.EARPIECE else CallAudio.SPEAKER)

    /** Completes a call that Telecom parked in SELECT_PHONE_ACCOUNT ("ask every time"). */
    fun selectSim(context: Context, slot: Int): Boolean {
        val handle = SimHelper.handleFor(context, slot) ?: return false
        return act(CallRegistry.inState(Call.STATE_SELECT_PHONE_ACCOUNT)) { it.phoneAccountSelected(handle, false) }
    }

    fun place(context: Context, number: String, simSlot: Int?): Boolean {
        val telecom = context.getSystemService(TelecomManager::class.java) ?: return false
        // fromParts keeps '#' and '*'; Uri.parse would treat '#' as a fragment and cut USSD codes.
        val uri = Uri.fromParts(PhoneAccount.SCHEME_TEL, number, null)
        val extras = Bundle()
        simSlot?.let { SimHelper.handleFor(context, it) }
            ?.let { extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, it) }
        return runCatching { telecom.placeCall(uri, extras) }.isSuccess
    }

    /** Runs an MMI/USSD code; the platform shows the response. Falls back to dialling it. */
    fun runMmi(context: Context, code: String, simSlot: Int?): Boolean {
        val telecom = context.getSystemService(TelecomManager::class.java) ?: return false
        val handle = simSlot?.let { SimHelper.handleFor(context, it) }
        val handled = runCatching {
            if (handle != null) telecom.handleMmi(code, handle) else telecom.handleMmi(code)
        }.getOrDefault(false)
        return handled || place(context, code, simSlot)
    }

    private inline fun act(target: TrackedCall?, block: (Call) -> Unit): Boolean {
        target ?: return false
        return runCatching { block(target.call) }.isSuccess
    }

    private inline fun withService(block: (android.telecom.InCallService) -> Unit): Boolean {
        val service = CallRegistry.service ?: return false
        return runCatching { block(service) }.isSuccess
    }
}
