package com.techuhat.umar.history

import android.content.ContentValues
import android.content.Context
import android.database.ContentObserver
import android.database.Cursor
import android.os.Handler
import android.os.Looper
import android.provider.CallLog.Calls
import android.telecom.TelecomManager
import com.techuhat.umar.call.NetworkNames
import com.techuhat.umar.util.PhoneNumbers
import com.techuhat.umar.util.SimHelper

/**
 * The system call log, which Telecom fills for every call whether or not this app was running.
 * Reads and writes must run off the main thread.
 */
object CallHistory {
    private const val MAX_ROWS = 1000
    private const val SQL_ARG_CHUNK = 500
    private const val CHANGE_DEBOUNCE_MS = 400L

    private val PROJECTION = arrayOf(
        Calls._ID, Calls.NUMBER, Calls.DATE, Calls.DURATION, Calls.TYPE, Calls.IS_READ,
        Calls.CACHED_NAME, Calls.CACHED_NUMBER_LABEL, Calls.PHONE_ACCOUNT_ID,
        Calls.NUMBER_PRESENTATION, Calls.GEOCODED_LOCATION, Calls.FEATURES,
    )

    private var observer: ContentObserver? = null

    /** Null when the call log cannot be read (no permission), so callers keep what they have. */
    fun query(context: Context): List<Map<String, Any?>>? {
        val slots = accountSlots(context)
        val networkNames = NetworkNames.all(context)
        val uri = Calls.CONTENT_URI.buildUpon()
            .appendQueryParameter(Calls.LIMIT_PARAM_KEY, MAX_ROWS.toString())
            .build()
        return try {
            context.contentResolver.query(uri, PROJECTION, null, null, "${Calls.DATE} DESC")?.use { cursor ->
                val rows = ArrayList<Map<String, Any?>>(cursor.count)
                while (cursor.moveToNext()) rows += row(cursor, slots, networkNames)
                rows
            }.orEmpty()
        } catch (_: SecurityException) {
            null
        }
    }

    fun delete(context: Context, ids: List<String>): Int {
        val safeIds = ids.mapNotNull { it.toLongOrNull()?.toString() }
        return safeIds.chunked(SQL_ARG_CHUNK).sumOf { chunk ->
            runCatching {
                context.contentResolver.delete(
                    Calls.CONTENT_URI,
                    "${Calls._ID} IN (${chunk.joinToString(",") { "?" }})",
                    chunk.toTypedArray(),
                )
            }.getOrDefault(0)
        }
    }

    fun clear(context: Context): Int =
        runCatching { context.contentResolver.delete(Calls.CONTENT_URI, null, null) }.getOrDefault(0)

    /** Marks missed calls as seen and clears Telecom's missed-call notification, as the stock dialer does. */
    fun markMissedRead(context: Context) {
        val values = ContentValues().apply {
            put(Calls.IS_READ, 1)
            put(Calls.NEW, 0)
        }
        runCatching {
            context.contentResolver.update(
                Calls.CONTENT_URI,
                values,
                "${Calls.TYPE} = ? AND (${Calls.IS_READ} = 0 OR ${Calls.NEW} = 1)",
                arrayOf(Calls.MISSED_TYPE.toString()),
            )
        }
        runCatching { context.getSystemService(TelecomManager::class.java)?.cancelMissedCallsNotification() }
    }

    fun observe(context: Context, onChange: () -> Unit) {
        if (observer != null) return
        val handler = Handler(Looper.getMainLooper())
        val notify = Runnable(onChange)
        val contentObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                handler.removeCallbacks(notify)
                handler.postDelayed(notify, CHANGE_DEBOUNCE_MS)
            }
        }
        runCatching { context.contentResolver.registerContentObserver(Calls.CONTENT_URI, true, contentObserver) }
            .onSuccess { observer = contentObserver }
    }

    fun stopObserving(context: Context) {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
    }

    private fun row(cursor: Cursor, slots: Map<String, Int>, networkNames: Map<String, String>): Map<String, Any?> {
        val number = cursor.getString(1).orEmpty()
        val cachedName = cursor.getString(6)?.trim()?.takeIf { it.isNotEmpty() }
        val networkName = if (cachedName == null) networkNames[PhoneNumbers.key(number)] else null
        val withheld = if (number.isEmpty()) PhoneNumbers.presentationLabel(cursor.getInt(9)) else null
        val features = cursor.getInt(11)
        return mapOf(
            "id" to cursor.getLong(0).toString(),
            "number" to number,
            "name" to (cachedName ?: networkName ?: withheld),
            "nameSource" to when {
                cachedName != null -> "contact"
                networkName != null -> "network"
                else -> null
            },
            "date" to cursor.getLong(2),
            "duration" to cursor.getLong(3),
            "type" to typeName(cursor.getInt(4)),
            "isRead" to (cursor.getInt(5) != 0),
            "label" to cursor.getString(7)?.takeIf { it.isNotBlank() },
            "simSlot" to cursor.getString(8)?.let(slots::get),
            "location" to cursor.getString(10)?.takeIf { it.isNotBlank() },
            "hd" to ((features and Calls.FEATURES_HD_CALL) != 0),
            "wifi" to ((features and Calls.FEATURES_WIFI) != 0),
        )
    }

    private fun typeName(type: Int): String = when (type) {
        Calls.OUTGOING_TYPE -> "outgoing"
        Calls.MISSED_TYPE -> "missed"
        Calls.REJECTED_TYPE -> "rejected"
        Calls.BLOCKED_TYPE -> "blocked"
        Calls.VOICEMAIL_TYPE -> "voicemail"
        else -> "incoming" // INCOMING and ANSWERED_EXTERNALLY
    }

    /** PHONE_ACCOUNT_ID → SIM slot, only on multi-SIM phones (one SIM needs no badge). */
    private fun accountSlots(context: Context): Map<String, Int> {
        if (SimHelper.sims(context).size < 2) return emptyMap()
        val telecom = context.getSystemService(TelecomManager::class.java) ?: return emptyMap()
        val handles = try {
            telecom.callCapablePhoneAccounts
        } catch (_: SecurityException) {
            return emptyMap()
        }
        return handles.mapNotNull { handle -> SimHelper.slotFor(context, handle)?.let { handle.id to it } }.toMap()
    }
}
