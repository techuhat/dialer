package com.techuhat.umar.bridge

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.techuhat.umar.call.CallController
import com.techuhat.umar.call.CallRegistry
import com.techuhat.umar.history.BlockedNumbers
import com.techuhat.umar.history.CallHistory
import com.techuhat.umar.util.SimHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Flutter → native call commands on [CallEventDispatcher.CHANNEL]. */
class CallChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val context = activity.applicationContext
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val number = call.argument<String>("number")?.trim().orEmpty()
        val simSlot = call.argument<Int>("simSlot")
        when (call.method) {
            "getCallLog" -> return inBackground(result) { CallHistory.query(context) }
            "deleteCallLog" -> return inBackground(result) {
                CallHistory.delete(context, call.argument<List<String>>("ids").orEmpty())
            }
            "clearCallLog" -> return inBackground(result) { CallHistory.clear(context) }
            "markMissedRead" -> return inBackground(result) { CallHistory.markMissedRead(context) }
            "canBlockNumbers" -> return inBackground(result) { BlockedNumbers.canBlock(context) }
            "getBlockedNumbers" -> return inBackground(result) { BlockedNumbers.list(context) }
            "blockNumber" -> return inBackground(result) { number.isNotEmpty() && BlockedNumbers.block(context, number) }
            "unblockNumber" -> return inBackground(result) { BlockedNumbers.unblock(context, number) }
        }
        val reply: Any? = when (call.method) {
            "listen" -> CallEventDispatcher.onDartListening()
            "getCalls" -> CallRegistry.snapshot(activity)
            "getSimCount" -> SimHelper.simCount(activity)
            "placeCall" -> number.isNotEmpty() && CallController.place(activity, number, simSlot)
            "runMmi" -> number.isNotEmpty() && CallController.runMmi(activity, number, simSlot)
            "answer" -> CallController.answer()
            "reject" -> CallController.reject(call.argument<String>("message"))
            "end" -> CallController.end()
            "hold" -> CallController.hold(call.argument<Boolean>("on") ?: true)
            "swap" -> CallController.swap()
            "merge" -> CallController.merge()
            "holdAndAnswer" -> CallController.holdAndAnswer()
            "endAndAnswer" -> CallController.endAndAnswer()
            "mute" -> CallController.mute(call.argument<Boolean>("on") ?: false)
            "route" -> CallController.route(call.argument<String>("route").orEmpty())
            "dtmf" -> call.argument<String>("digit")?.singleOrNull()?.let(CallController::dtmf) ?: false
            "selectSim" -> simSlot != null && CallController.selectSim(activity, simSlot)
            "composeSms" -> composeSms(number, call.argument<String>("body"))
            else -> return result.notImplemented()
        }
        result.success(if (reply is Unit) null else reply)
    }

    /** Content-provider work stays off the UI thread; the reply must go back on it. */
    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val reply = runCatching(work).getOrNull()
            main.post { result.success(if (reply is Unit) null else reply) }
        }
    }

    private fun composeSms(number: String, body: String?): Boolean = runCatching {
        val intent = Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", number, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (!body.isNullOrEmpty()) intent.putExtra("sms_body", body)
        activity.startActivity(intent)
    }.isSuccess

    private companion object {
        val io = Executors.newSingleThreadExecutor()
    }
}
