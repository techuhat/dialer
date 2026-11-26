package com.techuhat.umar.notification

import android.content.Context
import androidx.core.app.NotificationCompat
import com.techuhat.umar.MainActivity
import com.techuhat.umar.R
import com.techuhat.umar.call.TrackedCall

object IncomingCallNotification {
    private const val SAFETY_TIMEOUT_MS = 2 * 60_000L

    /** [waiting]: another call is up, so answering puts it on hold; "End & answer" is offered too. */
    fun show(context: Context, call: TrackedCall, waiting: Boolean, simLabel: String?) {
        NotificationKit.ensureChannels(context)
        val screen = NotificationKit.openCallScreen(context, MainActivity.ACTION_SHOW_INCOMING_CALL)
        val style = NotificationCompat.CallStyle.forIncomingCall(
            NotificationKit.person(context, call),
            NotificationKit.broadcast(context, NotificationKit.ACTION_DECLINE),
            NotificationKit.broadcast(context, NotificationKit.ACTION_ANSWER),
        )
            .setAnswerButtonColorHint(NotificationKit.COLOR_ANSWER)
            .setDeclineButtonColorHint(NotificationKit.COLOR_DECLINE)

        val builder = NotificationCompat.Builder(context, NotificationKit.INCOMING_CHANNEL)
            .setSmallIcon(R.drawable.ic_notif_call)
            .setContentTitle(call.title)
            .setContentText(listOfNotNull(if (waiting) "Call waiting" else "Incoming call", simLabel).joinToString(" · "))
            .setLargeIcon(call.avatar(context))
            .setStyle(style)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setTimeoutAfter(SAFETY_TIMEOUT_MS)
            .setColorized(true)
            .setColor(NotificationKit.COLOR_BRAND)
            .setFullScreenIntent(screen, true)
            .setContentIntent(screen)

        if (waiting) {
            builder.addAction(
                NotificationKit.action(context, R.drawable.ic_notif_end_call, "End & answer", NotificationKit.ACTION_END_AND_ANSWER),
            )
        }
        NotificationKit.post(context, NotificationKit.INCOMING_ID, builder.build())
    }

    fun cancel(context: Context) = NotificationKit.cancel(context, NotificationKit.INCOMING_ID)
}
