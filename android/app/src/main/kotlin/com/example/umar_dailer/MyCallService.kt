package com.example.umar_dailer

import android.telecom.Call
import android.telecom.InCallService
import android.telecom.VideoProfile

class MyCallService : InCallService() {
    private var activeCall: Call? = null
    private var activeCallIsOutgoing: Boolean? = null
    private var activeCallNumber: String? = null
    private var hasEmittedCallEnded = false
    
    override fun onCallAdded(call: Call?) {
        super.onCallAdded(call)
        call?.let { 
            android.util.Log.d("MyCallService", "Call added: ${it.details?.handle}")
            
            // Determine call direction and emit initial event
            val isOutgoing = it.details?.callDirection == Call.Details.DIRECTION_OUTGOING
            val number = extractPhoneNumber(it.details?.handle?.toString())
            
            android.util.Log.d("MyCallService", "Call direction: ${if (isOutgoing) "outgoing" else "incoming"}")
            android.util.Log.d("MyCallService", "Call state: ${it.state}")
            
            if (isOutgoing) {
                CallEventDispatcher.emitOutgoingCall(number)
            } else {
                CallEventDispatcher.emitIncomingCall(number)
            }
            
            activeCall = it
            activeCallIsOutgoing = isOutgoing
            activeCallNumber = number
            hasEmittedCallEnded = false
            it.registerCallback(callCallback)
        }
    }

    override fun onCallRemoved(call: Call?) {
        super.onCallRemoved(call)
        android.util.Log.d("MyCallService", "Call removed: ${call?.details?.handle}")
        
        if (call == activeCall) {
            call?.unregisterCallback(callCallback)
            if (!hasEmittedCallEnded) {
                CallEventDispatcher.emitCallEnded()
                hasEmittedCallEnded = true
            }
            activeCall = null
            activeCallIsOutgoing = null
            activeCallNumber = null
        }
    }
    
    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call?, state: Int) {
            super.onStateChanged(call, state)
            android.util.Log.d("MyCallService", "Call state changed to: $state")
            
            call?.let {
                val number = activeCallNumber ?: extractPhoneNumber(it.details?.handle?.toString())
                val isOutgoing = activeCallIsOutgoing ?: (it.details?.callDirection == Call.Details.DIRECTION_OUTGOING)
                
                when (state) {
                    Call.STATE_ACTIVE -> {
                        android.util.Log.d("MyCallService", "Call became active: $number")
                        if (isOutgoing == true) {
                            CallEventDispatcher.emitOutgoingCallConnected(number)
                        } else {
                            // For answered incoming calls, navigate to active call UI
                            CallEventDispatcher.emitIncomingCallConnected(number)
                        }
                    }
                    Call.STATE_DISCONNECTED -> {
                        if (!hasEmittedCallEnded) {
                            android.util.Log.d("MyCallService", "Call disconnected, emitting callEnded event")
                            CallEventDispatcher.emitCallEnded()
                            hasEmittedCallEnded = true
                        }
                    }
                }
            }
        }
    }
    
    private fun extractPhoneNumber(handle: String?): String {
        return handle?.let { h ->
            if (h.startsWith("tel:")) {
                h.substring(4)
            } else {
                h
            }
        } ?: "Unknown"
    }
    
    fun endCurrentCall(): Boolean {
        return try {
            activeCall?.let { call ->
                android.util.Log.d("MyCallService", "Disconnecting active/dialing call")
                call.disconnect()
                true
            } ?: false
        } catch (e: Exception) {
            android.util.Log.e("MyCallService", "Error ending call", e)
            false
        }
    }

    fun answerCurrentCall(): Boolean {
        return try {
            activeCall?.let { call ->
                android.util.Log.d("MyCallService", "Answering incoming call")
                call.answer(VideoProfile.STATE_AUDIO_ONLY)
                true
            } ?: false
        } catch (e: Exception) {
            android.util.Log.e("MyCallService", "Error answering call", e)
            false
        }
    }
    
    companion object {
        private var instance: MyCallService? = null
        
        fun getInstance(): MyCallService? = instance
        
        fun endCurrentCallStatic(): Boolean {
            return instance?.endCurrentCall() ?: false
        }

        fun answerCurrentCallStatic(): Boolean {
            return instance?.answerCurrentCall() ?: false
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        activeCall = null
        activeCallIsOutgoing = null
        activeCallNumber = null
        hasEmittedCallEnded = false
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}
