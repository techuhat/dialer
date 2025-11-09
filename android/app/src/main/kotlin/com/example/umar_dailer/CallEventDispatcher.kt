package com.example.umar_dailer

import com.example.umar_dailer.util.CallEventDispatcher as UtilDispatcher
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object CallEventDispatcher {
    fun setMethodChannel(channel: MethodChannel) {
        UtilDispatcher.bindChannel(channel)
    }

    fun setBinaryMessenger(messenger: BinaryMessenger, channelName: String) {
        UtilDispatcher.initialize(messenger, channelName)
    }

    fun emitIncomingCall(number: String?) {
        UtilDispatcher.emitIncomingCall(number)
    }

    fun emitIncomingCallConnected(number: String?) {
        UtilDispatcher.emitIncomingCallConnected(number)
    }

    fun emitOutgoingCall(number: String?) {
        UtilDispatcher.emitOutgoingCall(number)
    }

    fun emitOutgoingCallConnected(number: String?) {
        UtilDispatcher.emitOutgoingCallConnected(number)
    }

    fun emitCallEnded() {
        UtilDispatcher.emitCallEnded()
    }
}