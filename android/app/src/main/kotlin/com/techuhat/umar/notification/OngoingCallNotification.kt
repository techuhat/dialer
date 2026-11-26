package com.techuhat.umar.notification

import android.app.Notification
import android.content.Context
import android.telecom.Call
import android.telecom.CallAudioState
import androidx.core.app.NotificationCompat
import com.techuhat.umar.MainActivity
import com.techuhat.umar.R
import com.techuhat.umar.call.CallAudio
import com.techuhat.umar.call.TrackedCall

object OngoingCallNotification {
    /**
     * [callStyle] needs the notification to belong to a foreground service (it also gives the
     * status-bar call chip on Android 12+); the plain variant is the fallback when that is refused.
     */
    fun build(context: Context, call: TrackedCall, audio: CallAudioState?, callStyle: Boolean): Notification {
        NotificationKit.ensureChannels(context)
        val muted = audio?.isMuted == true
        val speaker = CallAudio.isSpeaker(audio)
        val timing = call.state == Call.STATE_ACTIVE && call.connectedAt != null

        val mute = NotificationKit.action(
            context,
            if (muted) R.drawable.ic_notif_mic_off else R.drawable.ic_notif_mic_on,
            if (muted) "Unmute" else "Mute",
            NotificationKit.ACTION_TOGGLE_MUTE,
        )
        val speakerAction = NotificationKit.action(
            context,
            if (speaker) R.drawable.ic_notif_speaker_on else R.drawable.ic_notif_speaker_off,
            if (speaker) "Speaker off" else "Speaker",
            NotificationKit.ACTION_TOGGLE_SPEAKER,
        )

        val builder = NotificationCompat.Builder(context, NotificationKit.ONGOING_CHANNEL)
            .setSmallIcon(R.drawable.ic_notif_call)
            .setContentTitle(call.title)
            .setContentText(status(call, muted))
            .setLargeIcon(call.avatar(context))
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setColorized(true)
            .setColor(NotificationKit.COLOR_BRAND)
            .setContentIntent(NotificationKit.openCallScreen(context, MainActivity.ACTION_RETURN_TO_CALL))
            .setUsesChronometer(timing)
            .setShowWhen(timing)
            .setWhen(call.connectedAt ?: System.currentTimeMillis())

        if (callStyle) {
            val hangUp = NotificationKit.broadcast(context, NotificationKit.ACTION_HANG_UP)
            builder.setStyle(NotificationCompat.CallStyle.forOngoingCall(NotificationKit.person(context, call), hangUp))
                .addAction(mute)
                .addAction(speakerAction)
        } else {
            builder.addAction(mute)
                .addAction(speakerAction)
                .addAction(NotificationKit.action(context, R.drawable.ic_notif_end_call, "Hang up", NotificationKit.ACTION_HANG_UP))
        }
        return builder.build()
    }

    private fun status(call: TrackedCall, muted: Boolean): String = when (call.state) {
        Call.STATE_SELECT_PHONE_ACCOUNT -> "Choose a SIM"
        Call.STATE_HOLDING -> "On hold"
        Call.STATE_DISCONNECTING -> "Hanging up…"
        Call.STATE_ACTIVE -> if (muted) "Ongoing call · Muted" else "Ongoing call"
        else -> "Calling…"
    }
}
