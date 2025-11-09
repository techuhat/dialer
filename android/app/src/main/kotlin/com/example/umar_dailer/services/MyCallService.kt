package com.example.umar_dailer.services

import android.content.Intent
import android.telecom.Call
import android.telecom.InCallService
import android.util.Log
import com.example.umar_dailer.MainActivity
import com.example.umar_dailer.util.CallEventDispatcher

private const val TAG = "MyCallService"

class MyCallService : InCallService() {
    companion object {
        private var currentCall: Call? = null
        
        fun endCurrentCall(): Boolean {
            return currentCall?.let { call ->
                try {
                    when (call.state) {
                        Call.STATE_RINGING -> {
                            Log.d(TAG, "Rejecting incoming call")
                            call.reject(false, null)
                        }
                        Call.STATE_DIALING, Call.STATE_ACTIVE, Call.STATE_CONNECTING -> {
                            Log.d(TAG, "Disconnecting active/dialing call")
                            call.disconnect()
                        }
                        else -> {
                            Log.d(TAG, "Attempting to disconnect call in state: ${call.state}")
                            call.disconnect()
                        }
                    }
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to end call", e)
                    false
                }
            } ?: false
        }
    }
    
    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "Call added: ${call.details.handle}")

        // Check if this is an incoming or outgoing call
        val isIncoming = call.details.callDirection == android.telecom.Call.Details.DIRECTION_INCOMING
        val number = call.details.handle?.schemeSpecificPart

        // Store the current call reference
        currentCall = call

        // Add call state change listener
        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call, state: Int) {
                Log.d(TAG, "Call state changed to: $state")
                when (state) {
                    Call.STATE_DISCONNECTED -> {
                        Log.d(TAG, "Call disconnected, emitting callEnded event")
                        CallEventDispatcher.emitCallEnded()
                        currentCall = null
                    }
                    Call.STATE_ACTIVE -> {
                        val connectedNumber = call.details.handle?.schemeSpecificPart
                        Log.d(TAG, "Call became active: $connectedNumber")
                        if (isIncoming) {
                            CallEventDispatcher.emitIncomingCallConnected(connectedNumber)
                        } else {
                            CallEventDispatcher.emitOutgoingCallConnected(connectedNumber)
                        }
                    }
                }
            }
        })

        Log.d(TAG, "Call direction: ${if (isIncoming) "incoming" else "outgoing"}")
        Log.d(TAG, "Call state: ${call.state}")

        // Only emit incoming call event for actual incoming calls
        if (isIncoming) {
            bringAppToForeground(number)
            CallEventDispatcher.emitIncomingCall(number)
        }
        // For outgoing calls, we let the MainActivity handle the event emission
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        Log.d(TAG, "Call removed: ${call.details.handle}")
        
        // Clear the current call reference
        if (currentCall == call) {
            currentCall = null
        }
        
        CallEventDispatcher.emitCallEnded()
    }

    private fun bringAppToForeground(number: String?) {
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                action = MainActivity.ACTION_SHOW_INCOMING_CALL
                putExtra(MainActivity.EXTRA_PHONE_NUMBER, number)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            Log.d(TAG, "Launching MainActivity for incoming call UI")
            startActivity(launchIntent)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to bring app to foreground: ${e.message}")
        }
    }
}
