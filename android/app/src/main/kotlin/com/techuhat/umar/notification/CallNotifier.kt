package com.techuhat.umar.notification

import android.app.Service
import android.content.pm.ServiceInfo
import android.telecom.InCallService
import androidx.core.app.ServiceCompat
import com.techuhat.umar.call.CallAudio
import com.techuhat.umar.call.CallRegistry
import com.techuhat.umar.util.SimHelper

/** Derives both call notifications from [CallRegistry]; call [refresh] after any change. */
object CallNotifier {
    private var incomingKey: String? = null
    private var isForeground = false

    fun refresh(service: InCallService) {
        refreshIncoming(service)
        refreshOngoing(service)
    }

    fun clear(service: InCallService) {
        IncomingCallNotification.cancel(service)
        incomingKey = null
        stopOngoing(service)
    }

    private fun refreshIncoming(service: InCallService) {
        val ringing = CallRegistry.ringing()
        if (ringing == null) {
            if (incomingKey != null) IncomingCallNotification.cancel(service)
            incomingKey = null
            return
        }
        val waiting = CallRegistry.foreground() != null
        val key = "${ringing.id}/$waiting"
        if (key == incomingKey) return // re-posting would re-run the full-screen intent
        incomingKey = key
        val simLabel = SimHelper.describe(service, ringing.simSlot(service))
        IncomingCallNotification.show(service, ringing, waiting, simLabel)
    }

    private fun refreshOngoing(service: InCallService) {
        val call = CallRegistry.foreground() ?: return stopOngoing(service)
        val audio = CallAudio.current()
        isForeground = try {
            ServiceCompat.startForeground(
                service,
                NotificationKit.ONGOING_ID,
                OngoingCallNotification.build(service, call, audio, callStyle = true),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL,
            )
            true
        } catch (_: Exception) {
            false // e.g. dialer role revoked mid-call: Android 14 refuses a phoneCall service
        }
        if (!isForeground) {
            NotificationKit.post(
                service,
                NotificationKit.ONGOING_ID,
                OngoingCallNotification.build(service, call, audio, callStyle = false),
            )
        }
    }

    private fun stopOngoing(service: InCallService) {
        if (isForeground) service.stopForeground(Service.STOP_FOREGROUND_REMOVE)
        isForeground = false
        NotificationKit.cancel(service, NotificationKit.ONGOING_ID)
    }
}
