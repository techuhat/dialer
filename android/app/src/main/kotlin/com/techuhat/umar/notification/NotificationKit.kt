package com.techuhat.umar.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.annotation.DrawableRes
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import com.techuhat.umar.MainActivity
import com.techuhat.umar.call.TrackedCall
import com.techuhat.umar.receivers.NotificationActionReceiver

/** Channels, intents and caller identity shared by the incoming and ongoing call notifications. */
object NotificationKit {
    // Channel ids are kept from earlier builds: a channel's sound is fixed once the user has it.
    const val INCOMING_CHANNEL = "incoming_call_channel"
    const val ONGOING_CHANNEL = "active_call_channel"
    const val INCOMING_ID = 1001
    const val ONGOING_ID = 1002

    const val ACTION_ANSWER = "com.techuhat.umar.ANSWER_CALL"
    const val ACTION_DECLINE = "com.techuhat.umar.DECLINE_CALL"
    const val ACTION_END_AND_ANSWER = "com.techuhat.umar.END_AND_ANSWER"
    const val ACTION_HANG_UP = "com.techuhat.umar.END_CALL"
    const val ACTION_TOGGLE_MUTE = "com.techuhat.umar.TOGGLE_MUTE"
    const val ACTION_TOGGLE_SPEAKER = "com.techuhat.umar.TOGGLE_SPEAKER"

    const val COLOR_ANSWER = 0xFF1E8E3E.toInt()
    const val COLOR_DECLINE = 0xFFD93025.toInt()
    const val COLOR_BRAND = 0xFF0B57D0.toInt()

    private const val PENDING_FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(INCOMING_CHANNEL) == null) {
            manager.createNotificationChannel(
                NotificationChannel(INCOMING_CHANNEL, "Incoming calls", NotificationManager.IMPORTANCE_MAX).apply {
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    enableVibration(false)
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                },
            )
        }
        if (manager.getNotificationChannel(ONGOING_CHANNEL) == null) {
            manager.createNotificationChannel(
                NotificationChannel(ONGOING_CHANNEL, "Ongoing calls", NotificationManager.IMPORTANCE_LOW).apply {
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                },
            )
        }
    }

    fun broadcast(context: Context, action: String): PendingIntent = PendingIntent.getBroadcast(
        context,
        action.hashCode(),
        Intent(context, NotificationActionReceiver::class.java).setAction(action),
        PENDING_FLAGS,
    )

    fun openCallScreen(context: Context, action: String): PendingIntent =
        PendingIntent.getActivity(context, action.hashCode(), MainActivity.callIntent(context, action), PENDING_FLAGS)

    fun action(context: Context, @DrawableRes icon: Int, title: String, action: String) =
        NotificationCompat.Action.Builder(IconCompat.createWithResource(context, icon), title, broadcast(context, action))
            .build()

    fun person(context: Context, call: TrackedCall): Person = Person.Builder()
        .setName(call.title)
        .setIcon(IconCompat.createWithBitmap(call.avatar(context)))
        .setImportant(true)
        .build()

    fun post(context: Context, id: Int, notification: Notification) {
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS denied: the call screen still works, only the shade entry is missing.
        }
    }

    fun cancel(context: Context, id: Int) = NotificationManagerCompat.from(context).cancel(id)
}
