package com.techuhat.umar.util

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager

object SimHelper {
    class Sim(val slot: Int, val subId: Int, val carrier: String?)

    private const val CACHE_MS = 30_000L
    private val GENERIC_NAME = Regex("^(CARD|SIM|UNKNOWN).*", RegexOption.IGNORE_CASE)

    private var cached: List<Sim> = emptyList()
    private var cachedAt = 0L

    @Synchronized
    fun sims(context: Context): List<Sim> {
        val now = SystemClock.elapsedRealtime()
        if (cachedAt != 0L && now - cachedAt < CACHE_MS) return cached
        cached = try {
            context.getSystemService(SubscriptionManager::class.java)
                ?.activeSubscriptionInfoList.orEmpty()
                .filter { it.simSlotIndex >= 0 }
                .map { Sim(it.simSlotIndex, it.subscriptionId, carrierOf(it)) }
        } catch (_: SecurityException) {
            emptyList()
        }
        cachedAt = now
        return cached
    }

    fun simCount(context: Context): Int = sims(context).size.coerceAtLeast(1)

    fun slotFor(context: Context, handle: PhoneAccountHandle?): Int? {
        handle ?: return null
        val sims = sims(context)
        subscriptionIdOf(context, handle)?.let { id ->
            sims.firstOrNull { it.subId == id }?.let { return it.slot }
        }
        // Before Android 11 there is no API for this; OEMs put the subscription id in the handle id,
        // sometimes with a suffix, so compare whole tokens only ("2" must not match "12").
        val tokens = handle.id.split(';', ',', '|', '/').map(String::trim)
        return sims.firstOrNull { it.subId.toString() in tokens }?.slot
    }

    fun handleFor(context: Context, slot: Int): PhoneAccountHandle? {
        val telecom = context.getSystemService(TelecomManager::class.java) ?: return null
        val handles = try {
            telecom.callCapablePhoneAccounts
        } catch (_: SecurityException) {
            return null
        }
        return handles.firstOrNull { slotFor(context, it) == slot }
    }

    /** "SIM 2 · Jio" on multi-SIM phones, null otherwise. */
    fun describe(context: Context, slot: Int?): String? {
        val sims = sims(context)
        if (slot == null || sims.size < 2) return null
        val carrier = sims.firstOrNull { it.slot == slot }?.carrier
        return listOfNotNull("SIM ${slot + 1}", carrier).joinToString(" · ")
    }

    fun carrierFor(context: Context, slot: Int?): String? =
        slot?.let { s -> sims(context).firstOrNull { it.slot == s }?.carrier }

    private fun subscriptionIdOf(context: Context, handle: PhoneAccountHandle): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return try {
            context.getSystemService(TelephonyManager::class.java)
                ?.getSubscriptionId(handle)
                ?.takeIf { it != SubscriptionManager.INVALID_SUBSCRIPTION_ID }
        } catch (_: Exception) {
            null
        }
    }

    private fun carrierOf(info: SubscriptionInfo): String? =
        sequenceOf(info.displayName, info.carrierName)
            .map { it?.toString()?.trim() }
            .firstOrNull { !it.isNullOrEmpty() && !GENERIC_NAME.matches(it) }
}
