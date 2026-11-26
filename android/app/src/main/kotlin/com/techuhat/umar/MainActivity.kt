package com.techuhat.umar

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.techuhat.umar.bridge.CallChannel
import com.techuhat.umar.bridge.CallEventDispatcher
import com.techuhat.umar.bridge.RoleChannel
import com.techuhat.umar.call.CallController
import com.techuhat.umar.call.CallRegistry
import com.techuhat.umar.history.CallHistory
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class MainActivity : FlutterFragmentActivity() {
    private val roleChannel = RoleChannel(this)
    private var overLockScreen = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        syncLockScreenAccess()
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        syncLockScreenAccess()
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        visibleRef = WeakReference(this)
        syncLockScreenAccess()
    }

    override fun onPause() {
        if (visible === this) visibleRef = null
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, RoleChannel.CHANNEL).setMethodCallHandler(roleChannel)
        MethodChannel(messenger, CallEventDispatcher.CHANNEL).setMethodCallHandler(CallChannel(this))
        CallEventDispatcher.attach(messenger)
        CallHistory.observe(applicationContext) { CallEventDispatcher.emit("callLogChanged") }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CallHistory.stopObserving(applicationContext)
        CallEventDispatcher.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * Over the keyguard only while a call exists, so contacts and history never show on a
     * locked phone; the stock dialer does the same with a separate in-call activity.
     * Released after a short delay so "Call ended" is still seen.
     */
    fun syncLockScreenAccess() {
        if (!CallRegistry.isEmpty()) {
            showOverLockScreen(true)
        } else if (overLockScreen) {
            window.decorView.postDelayed({ if (CallRegistry.isEmpty()) showOverLockScreen(false) }, LOCK_RELEASE_MS)
        }
    }

    private fun showOverLockScreen(show: Boolean) {
        overLockScreen = show
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data
        when (intent?.action) {
            Intent.ACTION_CALL -> data?.schemeSpecificPart?.takeIf { it.isNotBlank() }
                ?.let { CallController.place(this, it, null) }
            Intent.ACTION_DIAL, Intent.ACTION_VIEW -> data?.takeIf { it.scheme.equals("tel", ignoreCase = true) }
                ?.schemeSpecificPart
                ?.let { CallEventDispatcher.emit("dialNumber", mapOf("number" to Uri.decode(it))) }
            ACTION_SHOW_INCOMING_CALL, ACTION_RETURN_TO_CALL -> CallEventDispatcher.emit("showCall")
        }
    }

    companion object {
        const val ACTION_SHOW_INCOMING_CALL = "com.techuhat.umar.SHOW_INCOMING_CALL"
        const val ACTION_RETURN_TO_CALL = "com.techuhat.umar.RETURN_TO_CALL"
        private const val LOCK_RELEASE_MS = 1_200L

        @Volatile
        private var visibleRef: WeakReference<MainActivity>? = null

        /** The resumed instance, if any. */
        val visible: MainActivity? get() = visibleRef?.get()

        fun callIntent(context: Context, action: String): Intent = Intent(context, MainActivity::class.java)
            .setAction(action)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)

        fun showCallScreen(context: Context) {
            runCatching { context.startActivity(callIntent(context, ACTION_RETURN_TO_CALL)) }
        }
    }
}
