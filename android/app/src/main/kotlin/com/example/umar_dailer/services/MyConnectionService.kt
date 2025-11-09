package com.example.umar_dailer.services

import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import com.example.umar_dailer.util.CallEventDispatcher

private const val TAG = "MyConnectionService"

class MyConnectionService : ConnectionService() {
    override fun onCreateIncomingConnection(
        phoneAccount: PhoneAccountHandle,
        request: ConnectionRequest,
    ): Connection {
        Log.d(TAG, "Incoming connection for ${request.address}")
        CallEventDispatcher.emitIncomingCall(request.address?.schemeSpecificPart)
        return SimpleConnection(request.address?.schemeSpecificPart)
    }

    override fun onCreateOutgoingConnection(
        phoneAccount: PhoneAccountHandle,
        request: ConnectionRequest,
    ): Connection {
        Log.d(TAG, "Outgoing connection for ${request.address}")
        CallEventDispatcher.emitOutgoingCallConnected(request.address?.schemeSpecificPart)
        return SimpleConnection(request.address?.schemeSpecificPart)
    }

    override fun onCreateIncomingConnectionFailed(
        phoneAccount: PhoneAccountHandle,
        request: ConnectionRequest,
    ) {
        Log.w(TAG, "Incoming connection failed for ${request.address}")
        CallEventDispatcher.emitCallEnded()
        super.onCreateIncomingConnectionFailed(phoneAccount, request)
    }

    override fun onCreateOutgoingConnectionFailed(
        phoneAccount: PhoneAccountHandle,
        request: ConnectionRequest,
    ) {
        Log.w(TAG, "Outgoing connection failed for ${request.address}")
        CallEventDispatcher.emitCallEnded()
        super.onCreateOutgoingConnectionFailed(phoneAccount, request)
    }
}

private class SimpleConnection(private val address: String?) : Connection() {
    init {
        address?.let {
            setAddress(android.net.Uri.fromParts("tel", it, null), TelecomManager.PRESENTATION_ALLOWED)
        }
        connectionCapabilities = CAPABILITY_HOLD or CAPABILITY_MUTE
        connectionProperties = PROPERTY_SELF_MANAGED
        setDialing()
        setInitialized()
        setActive()
    }

    override fun onDisconnect() {
        super.onDisconnect()
        disconnectAndDestroy()
    }

    override fun onAbort() {
        super.onAbort()
        disconnectAndDestroy()
    }

    override fun onHold() {
        super.onHold()
        setOnHold()
    }

    override fun onUnhold() {
        super.onUnhold()
        setActive()
    }

    private fun disconnectAndDestroy() {
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
        CallEventDispatcher.emitCallEnded()
    }
}
