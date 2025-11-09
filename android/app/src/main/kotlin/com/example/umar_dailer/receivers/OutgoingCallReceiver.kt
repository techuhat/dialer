package com.example.umar_dailer.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.umar_dailer.util.CallEventDispatcher

class OutgoingCallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val phoneNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
        Log.d(TAG, "Outgoing call detected: $phoneNumber")
        CallEventDispatcher.emitOutgoingCall(phoneNumber)
    }

    companion object {
        private const val TAG = "OutgoingCallReceiver"
    }
}
