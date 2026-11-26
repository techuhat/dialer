package com.techuhat.umar.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.techuhat.umar.MainActivity
import com.techuhat.umar.call.CallController
import com.techuhat.umar.notification.NotificationKit

/** Notification buttons. Notifications refresh themselves from the resulting Telecom callbacks. */
class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            NotificationKit.ACTION_ANSWER -> if (CallController.answer()) MainActivity.showCallScreen(context)
            NotificationKit.ACTION_END_AND_ANSWER -> if (CallController.endAndAnswer()) MainActivity.showCallScreen(context)
            NotificationKit.ACTION_DECLINE -> CallController.reject()
            NotificationKit.ACTION_HANG_UP -> CallController.end()
            NotificationKit.ACTION_TOGGLE_MUTE -> CallController.toggleMute()
            NotificationKit.ACTION_TOGGLE_SPEAKER -> CallController.toggleSpeaker()
        }
    }
}
