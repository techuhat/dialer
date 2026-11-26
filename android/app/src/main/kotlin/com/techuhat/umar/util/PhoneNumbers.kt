package com.techuhat.umar.util

import android.content.Context
import android.telecom.TelecomManager
import android.telephony.PhoneNumberUtils
import android.telephony.TelephonyManager
import java.util.Locale

object PhoneNumbers {
    private const val KEY_DIGITS = 10

    /**
     * Last ten digits, so `+91 98…`, `098…` and `98…` of one subscriber compare equal; an address
     * without digits compares as itself. Flutter's `PhoneUtils.matchKey` is the same rule.
     */
    fun key(number: String?): String {
        val digits = number.orEmpty().filter { it in '0'..'9' }
        if (digits.isEmpty()) return number.orEmpty().trim().lowercase()
        return if (digits.length > KEY_DIGITS) digits.takeLast(KEY_DIGITS) else digits
    }

    /** Label for a withheld or unknown caller (Telecom and CallLog share these presentation values). */
    fun presentationLabel(presentation: Int): String? = when (presentation) {
        TelecomManager.PRESENTATION_RESTRICTED -> "Private number"
        TelecomManager.PRESENTATION_PAYPHONE -> "Payphone"
        TelecomManager.PRESENTATION_UNKNOWN -> "Unknown caller"
        else -> null
    }

    fun format(context: Context, number: String): String {
        val iso = context.getSystemService(TelephonyManager::class.java)?.networkCountryIso
            ?.takeIf { it.isNotBlank() } ?: Locale.getDefault().country
        return PhoneNumberUtils.formatNumber(number, iso.uppercase(Locale.US)) ?: number
    }
}
