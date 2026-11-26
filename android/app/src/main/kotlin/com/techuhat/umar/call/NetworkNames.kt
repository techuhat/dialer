package com.techuhat.umar.call

import android.content.Context
import com.techuhat.umar.util.PhoneNumbers

/**
 * Caller names the network sent (CNAP) for numbers that are not saved contacts.
 * Telecom does not keep them in the call log, so recents read them from here.
 */
object NetworkNames {
    private const val PREFS = "network_caller_names"
    private const val MAX_ENTRIES = 300

    fun remember(context: Context, number: String, name: String) {
        val key = PhoneNumbers.key(number)
        if (key.isEmpty()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getString(key, null) == name) return
        val editor = prefs.edit().putString(key, name)
        val stored = prefs.all.keys
        if (stored.size >= MAX_ENTRIES) stored.firstOrNull { it != key }?.let(editor::remove)
        editor.apply()
    }

    fun all(context: Context): Map<String, String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).all
            .mapNotNull { (key, value) -> (value as? String)?.let { key to it } }
            .toMap()
}
