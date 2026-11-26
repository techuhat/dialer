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
    const val PAGE = 100
    private const val SQL_ARG_CHUNK = 500
    private const val CHANGE_DEBOUNCE_MS = 400L
    private const val NEWEST_FIRST = "${Calls.DATE} DESC, ${Calls._ID} DESC"

    // Keyset paging: everything after the last row of the previous page, in NEWEST_FIRST order.
    private const val OLDER_THAN_ROW = "(${Calls.DATE} < ? OR (${Calls.DATE} = ? AND ${Calls._ID} < ?))"
    private const val OLDER_THAN_DATE = "${Calls.DATE} < ?"

    private val PROJECTION = arrayOf(
        Calls._ID, Calls.NUMBER, Calls.DATE, Calls.DURATION, Calls.TYPE, Calls.IS_READ,
        Calls.CACHED_NAME, Calls.CACHED_NUMBER_LABEL, Calls.PHONE_ACCOUNT_ID,
        Calls.NUMBER_PRESENTATION, Calls.GEOCODED_LOCATION, Calls.FEATURES,
    )

    private var observer: ContentObserver? = null

    /**
     * One page of the log, newest first: at most [limit] calls older than the row ([beforeDate],
     * [beforeId]), only calls with [number] when given (matched by [PhoneNumbers.key], as Flutter
     * does). `more` says whether older calls are left. Null when the log cannot be read (no
     * permission), so callers keep what they have.
     */
    fun page(context: Context, limit: Int, beforeDate: Long?, beforeId: Long?, number: String?): Map<String, Any?>? {
        val slots = accountSlots(context)
        val networkNames = NetworkNames.all(context)
        val (selection, args) = when {
            beforeDate == null -> null to null
            beforeId == null -> OLDER_THAN_DATE to arrayOf(beforeDate.toString())
            else -> OLDER_THAN_ROW to arrayOf(beforeDate.toString(), beforeDate.toString(), beforeId.toString())
        }
        val key = number?.let(PhoneNumbers::key)
        // One row past the page tells whether more are left. A number is matched here, not in SQL,
        // so then the provider cannot stop early.
        val uri = if (key != null) {
            Calls.CONTENT_URI
        } else {
            Calls.CONTENT_URI.buildUpon().appendQueryParameter(Calls.LIMIT_PARAM_KEY, (limit + 1).toString()).build()
        }
        return try {
            context.contentResolver.query(uri, PROJECTION, selection, args, NEWEST_FIRST)?.use { cursor ->
                val rows = ArrayList<Map<String, Any?>>()
                var more = false
                while (cursor.moveToNext()) {
                    if (key != null && PhoneNumbers.key(cursor.getString(1)) != key) continue
                    if (rows.size == limit) {
                        more = true
                        break
                    }
                    rows += row(cursor, slots, networkNames)
                }
                mapOf("rows" to rows, "more" to more)
            } ?: mapOf("rows" to emptyList<Map<String, Any?>>(), "more" to false)
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
