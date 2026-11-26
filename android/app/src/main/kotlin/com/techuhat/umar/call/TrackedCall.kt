package com.techuhat.umar.call

import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.telecom.Call
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import com.techuhat.umar.util.ContactsHelper
import com.techuhat.umar.util.PhoneNumbers
import com.techuhat.umar.util.SimHelper

/** A Telecom [Call] plus what the app derives from it once (caller identity, connect time). */
class TrackedCall(val call: Call, context: Context) {
    val id: String = "call-${nextId++}"
    val number: String = call.details.handle?.schemeSpecificPart.orEmpty()
    val isIncoming: Boolean = isIncoming(call)

    private val contact = ContactsHelper.lookup(context, number)
    private val withheldLabel = PhoneNumbers.presentationLabel(call.details.handlePresentation)
    private val formattedNumber = if (number.isEmpty()) "Unknown" else PhoneNumbers.format(context, number)

    /** CNAP: the caller name the network sends (India's KYC caller ID). Can arrive after the call. */
    val networkName: String?
        get() {
            val details = call.details
            if (contact != null || details.callerDisplayNamePresentation != TelecomManager.PRESENTATION_ALLOWED) return null
            val name = details.callerDisplayName?.trim()
            return name?.takeIf { it.isNotEmpty() && PhoneNumbers.key(it) != PhoneNumbers.key(number) }
        }

    val name: String? get() = contact?.name ?: networkName ?: withheldLabel
    val title: String get() = name ?: formattedNumber

    var connectedAt: Long? = null
        private set
    var endReported = false
    var answerRingingOnDisconnect = false
    private var avatar: Pair<String, Bitmap>? = null
    private var simFor: Pair<PhoneAccountHandle?, Int?>? = null

    val state: Int get() = stateOf(call)
    val isLive: Boolean get() = state != Call.STATE_DISCONNECTED
    val isConferenceChild: Boolean get() = call.parent != null

    fun can(capability: Int) = call.details.can(capability)

    fun avatar(context: Context): Bitmap {
        val label = title
        avatar?.let { (forTitle, bitmap) -> if (forTitle == label) return bitmap }
        return ContactsHelper.avatar(context, contact, label).also { avatar = label to it }
    }

    /** SIM slot of the call's account; re-resolved only when Telecom changes the account. */
    fun simSlot(context: Context): Int? {
        val handle = call.details.accountHandle
        simFor?.let { (cachedHandle, slot) -> if (cachedHandle == handle) return slot }
        return SimHelper.slotFor(context, handle).also { simFor = handle to it }
    }

    /** Keeps the first connect time, so hold/unhold never restarts the call timer. */
    fun markConnected() {
        if (connectedAt != null) return
        val telecomTime = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) call.details.connectTimeMillis else 0L
        connectedAt = telecomTime.takeIf { it > 0 } ?: System.currentTimeMillis()
    }

    fun toMap(context: Context, simCount: Int): Map<String, Any?> {
        val slot = if (simCount > 1) simSlot(context) else null
        return mapOf(
            "id" to id,
            "number" to number,
            "name" to name,
            "nameSource" to when {
                contact != null -> "contact"
                networkName != null -> "network"
                else -> null
            },
            "state" to stateName(state),
            "incoming" to isIncoming,
            "connectedAt" to connectedAt,
            "canHold" to can(Call.Details.CAPABILITY_HOLD),
            "canMerge" to (call.conferenceableCalls.isNotEmpty() || can(Call.Details.CAPABILITY_MERGE_CONFERENCE)),
            "canSwap" to can(Call.Details.CAPABILITY_SWAP_CONFERENCE),
            "conference" to call.details.hasProperty(Call.Details.PROPERTY_CONFERENCE),
            "hd" to call.details.hasProperty(Call.Details.PROPERTY_HIGH_DEF_AUDIO),
            "wifi" to call.details.hasProperty(Call.Details.PROPERTY_WIFI),
            "simSlot" to slot,
            "carrier" to SimHelper.carrierFor(context, slot),
        )
    }

    /** Payload of the lifecycle events that Flutter's history logging consumes. */
    fun eventPayload(context: Context, extra: Map<String, Any?> = emptyMap()): Map<String, Any?> {
        val slot = simSlot(context)
        return mapOf(
            "number" to number.ifEmpty { "Unknown" },
            "name" to name,
            "connectedSince" to connectedAt,
            "simSlot" to slot,
            "activeSimCount" to SimHelper.simCount(context),
            "simCarrierName" to SimHelper.carrierFor(context, slot),
        ) + extra
    }

    fun endReason(): String = when (call.details.disconnectCause?.code) {
        DisconnectCause.MISSED -> "missed"
        DisconnectCause.REJECTED -> "rejected"
        DisconnectCause.ERROR -> "error"
        else -> "completed"
    }

    companion object {
        private var nextId = 0

        fun stateOf(call: Call): Int =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) call.details.state
            else @Suppress("DEPRECATION") call.state

        fun stateName(state: Int): String = when (state) {
            Call.STATE_RINGING, Call.STATE_SIMULATED_RINGING -> "ringing"
            Call.STATE_NEW, Call.STATE_DIALING, Call.STATE_CONNECTING, Call.STATE_PULLING_CALL -> "dialing"
            Call.STATE_SELECT_PHONE_ACCOUNT -> "selectSim"
            Call.STATE_ACTIVE, Call.STATE_AUDIO_PROCESSING -> "active"
            Call.STATE_HOLDING -> "holding"
            Call.STATE_DISCONNECTING -> "disconnecting"
            else -> "disconnected"
        }

        private fun isIncoming(call: Call): Boolean {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                when (call.details.callDirection) {
                    Call.Details.DIRECTION_INCOMING -> return true
                    Call.Details.DIRECTION_OUTGOING -> return false
                }
            }
            return stateOf(call) == Call.STATE_RINGING
        }
    }
}
