package com.example.umar_dailer

import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.PhoneAccountHandle
import android.util.Log

class MyConnectionService : ConnectionService() {
    override fun onCreateIncomingConnection(phoneAccount: PhoneAccountHandle, request: ConnectionRequest): Connection? {
        Log.d("MyConnectionService", "onCreateIncomingConnection: ${request.address}")
        return super.onCreateIncomingConnection(phoneAccount, request)
    }

    override fun onCreateOutgoingConnection(phoneAccount: PhoneAccountHandle, request: ConnectionRequest): Connection? {
        Log.d("MyConnectionService", "onCreateOutgoingConnection: ${request.address}")
        return super.onCreateOutgoingConnection(phoneAccount, request)
    }

    override fun onCreateIncomingConnectionFailed(phoneAccount: PhoneAccountHandle, request: ConnectionRequest) {
        Log.w("MyConnectionService", "Incoming connection failed: ${request.address}")
        super.onCreateIncomingConnectionFailed(phoneAccount, request)
    }

    override fun onCreateOutgoingConnectionFailed(phoneAccount: PhoneAccountHandle, request: ConnectionRequest) {
        Log.w("MyConnectionService", "Outgoing connection failed: ${request.address}")
        super.onCreateOutgoingConnectionFailed(phoneAccount, request)
    }
}
