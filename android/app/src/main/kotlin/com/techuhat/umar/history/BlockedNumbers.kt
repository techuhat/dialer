package com.techuhat.umar.history

import android.content.ContentValues
import android.content.Context
import android.provider.BlockedNumberContract
import android.provider.BlockedNumberContract.BlockedNumbers as Blocked

/**
 * The system block list. Telephony rejects these numbers before they ring, even while this app is
 * not running, and logs them as blocked. Only the default dialer (or SMS app) may use it.
 */
object BlockedNumbers {
    fun canBlock(context: Context): Boolean =
        runCatching { BlockedNumberContract.canCurrentUserBlockNumbers(context) }.getOrDefault(false)

    fun list(context: Context): List<String> = runCatching {
        context.contentResolver.query(
            Blocked.CONTENT_URI,
            arrayOf(Blocked.COLUMN_ORIGINAL_NUMBER),
            null,
            null,
            "${Blocked.COLUMN_ID} DESC",
        )?.use { cursor ->
            buildList { while (cursor.moveToNext()) cursor.getString(0)?.let(::add) }
        }.orEmpty()
    }.getOrDefault(emptyList())

    fun block(context: Context, number: String): Boolean = runCatching {
        if (BlockedNumberContract.isBlocked(context, number)) return true
        val values = ContentValues().apply { put(Blocked.COLUMN_ORIGINAL_NUMBER, number) }
        context.contentResolver.insert(Blocked.CONTENT_URI, values) != null
    }.getOrDefault(false)

    fun unblock(context: Context, number: String): Boolean =
        runCatching { BlockedNumberContract.unblock(context, number) > 0 }.getOrDefault(false)
}
