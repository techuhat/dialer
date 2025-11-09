package com.example.umar_dailer

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telecom.TelecomManager
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterFragmentActivity() {
    private val roleChannelName = "app.call_manager/role"
    private val callChannelName = "app.call_manager/call"
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var roleRequestLauncher: ActivityResultLauncher<Intent>

    companion object {
        const val ACTION_SHOW_INCOMING_CALL = "com.example.umar_dailer.SHOW_INCOMING_CALL"
        const val EXTRA_PHONE_NUMBER = "extra_phone_number"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }

        // Register phone account for telecom integration
        registerPhoneAccount()
        
        // Handle incoming call intents
        handleIncomingIntent(intent)
        
        roleRequestLauncher =
            registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { _ ->
                val result = pendingResult
                pendingResult = null

                val isNowDefault = isDefaultDialer()
                android.util.Log.d("MainActivity", "Role request result, isDefault=$isNowDefault")
                if (!isNowDefault) {
                    android.util.Log.w(
                        "MainActivity",
                        "Role request canceled or denied, attempting telecom fallback",
                    )
                    launchTelecomChangeIntent()
                    result?.success(false)
                } else {
                    result?.success(true)
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_CALL -> {
                val number = intent.data?.schemeSpecificPart
                android.util.Log.d("MainActivity", "Handling ACTION_CALL for: $number")
                if (!number.isNullOrEmpty()) {
                    // Emit outgoing call event
                    CallEventDispatcher.emitOutgoingCall(number)
                }
            }
            Intent.ACTION_DIAL -> {
                val number = intent.data?.schemeSpecificPart
                android.util.Log.d("MainActivity", "Handling ACTION_DIAL for: $number")
                // For DIAL action, just open the app with the number pre-filled
            }
            ACTION_SHOW_INCOMING_CALL -> {
                val number = intent.getStringExtra(EXTRA_PHONE_NUMBER)
                android.util.Log.d("MainActivity", "Handling ACTION_SHOW_INCOMING_CALL for: $number")
                CallEventDispatcher.emitIncomingCall(number)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, roleChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDefaultDialer" -> result.success(isDefaultDialer())
                    "requestDefaultDialer" -> requestDefaultDialer(result)
                    "makeCall" -> makeCall(call.argument<String>("number"), result)
                    "endCall" -> endCall(result)
                    "rejectCall" -> rejectCall(result)
                    "answerCall" -> answerCall(result)
                    else -> result.notImplemented()
                }
            }

        // Store binary messenger globally for call events
        val callChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callChannelName)
        CallEventDispatcher.setMethodChannel(callChannel)
        CallEventDispatcher.setBinaryMessenger(flutterEngine.dartExecutor.binaryMessenger, callChannelName)
    }

    private fun isDefaultDialer(): Boolean {
        val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
        return telecomManager?.defaultDialerPackage == applicationContext.packageName
    }

    private fun registerPhoneAccount() {
        val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
        if (telecomManager != null) {
            val phoneAccountHandle = android.telecom.PhoneAccountHandle(
                android.content.ComponentName(this, MyCallService::class.java),
                "UmarDialerAccount"
            )
            
            val phoneAccount = android.telecom.PhoneAccount.builder(phoneAccountHandle, "Umar Dialer")
                .setCapabilities(android.telecom.PhoneAccount.CAPABILITY_CALL_PROVIDER)
                .build()
            
            try {
                telecomManager.registerPhoneAccount(phoneAccount)
                android.util.Log.d("MainActivity", "Phone account registered successfully")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to register phone account", e)
            }
        }
    }

    private fun requestDefaultDialer(result: MethodChannel.Result) {
        android.util.Log.d("MainActivity", "requestDefaultDialer called")
        
        if (isDefaultDialer()) {
            android.util.Log.d("MainActivity", "Already default dialer")
            result.success(true)
            return
        }

        pendingResult?.let {
            android.util.Log.w("MainActivity", "Another request already in progress")
            it.error("in_progress", "Another default dialer request is already running.", null)
            pendingResult = null
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            android.util.Log.d("MainActivity", "Android Q+ detected, using RoleManager")
            val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
            
            if (roleManager == null) {
                android.util.Log.e("MainActivity", "RoleManager is null!")
                openDefaultAppsSettings()
                result.success(false)
                return
            }
            
            val isRoleAvailable = roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)
            android.util.Log.d("MainActivity", "ROLE_DIALER available: $isRoleAvailable")
            
            if (isRoleAvailable) {
                val isRoleHeld = roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
                android.util.Log.d("MainActivity", "ROLE_DIALER held: $isRoleHeld")
                
                pendingResult = result
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                android.util.Log.d(
                    "DialerRole",
                    "Launching RoleManager intent to request default dialer role",
                )
                android.util.Log.d("MainActivity", "Launching role request intent")
                roleRequestLauncher.launch(intent)
                return
            } else {
                android.util.Log.w("MainActivity", "ROLE_DIALER not available, opening settings")
            }
        } else {
            android.util.Log.d("MainActivity", "Android version < Q, opening settings")
        }

        openDefaultAppsSettings()
        result.success(false)
    }

    private fun launchTelecomChangeIntent() {
        val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && telecomManager != null) {
            val changeDialerIntent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
                .putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (changeDialerIntent.resolveActivity(packageManager) != null) {
                android.util.Log.d("MainActivity", "Launching TelecomManager change default dialer intent")
                startActivity(changeDialerIntent)
                return
            }
        }

        android.util.Log.w("MainActivity", "Telecom change intent unavailable, opening default apps settings")
        openDefaultAppsSettings()
    }

    private fun openDefaultAppsSettings() {
        val defaultAppsIntent = Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (defaultAppsIntent.resolveActivity(packageManager) != null) {
            startActivity(defaultAppsIntent)
            return
        }

        val appDetailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .setData(Uri.fromParts("package", packageName, null))

        if (appDetailsIntent.resolveActivity(packageManager) != null) {
            startActivity(appDetailsIntent)
        }
    }

    private fun makeCall(number: String?, result: MethodChannel.Result) {
        if (number.isNullOrEmpty()) {
            result.error("INVALID_NUMBER", "Phone number is required", null)
            return
        }

        try {
            android.util.Log.d("MainActivity", "Making actual call to: $number")

            // Method 1: Try using TelecomManager first (more direct)
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            var callInitiated = false
            
            if (telecomManager != null && isDefaultDialer()) {
                try {
                    val phoneAccountHandle = android.telecom.PhoneAccountHandle(
                        android.content.ComponentName(this, MyCallService::class.java),
                        "UmarDialerAccount"
                    )
                    
                    val callUri = Uri.fromParts("tel", number, null)
                    val extras = android.os.Bundle()
                    
                    telecomManager.placeCall(callUri, extras)
                    android.util.Log.d("MainActivity", "Call placed via TelecomManager for: $number")
                    callInitiated = true
                } catch (e: SecurityException) {
                    android.util.Log.w("MainActivity", "TelecomManager.placeCall failed: ${e.message}")
                } catch (e: Exception) {
                    android.util.Log.w("MainActivity", "TelecomManager.placeCall exception: ${e.message}")
                }
            }
            
            // Method 2: Fallback to Intent method if TelecomManager didn't work
            if (!callInitiated) {
                val callIntent = Intent(Intent.ACTION_CALL).apply {
                    data = Uri.parse("tel:$number")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    // Try to avoid chooser by being more specific
                    if (isDefaultDialer()) {
                        setPackage(packageName)
                    }
                }

                if (callIntent.resolveActivity(packageManager) != null) {
                    startActivity(callIntent)
                    android.util.Log.d("MainActivity", "Call initiated via Intent for: $number")
                    callInitiated = true
                } else {
                    android.util.Log.e("MainActivity", "No app can handle phone calls")
                }
            }
            
            if (callInitiated) {
                // Emit outgoing call event
                CallEventDispatcher.emitOutgoingCall(number)
                result.success(true)
            } else {
                result.error("NO_HANDLER", "Failed to initiate call", null)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to make call", e)
            result.error("CALL_FAILED", "Failed to initiate call: ${e.message}", null)
        }
    }

    private fun endCall(result: MethodChannel.Result) {
        try {
            android.util.Log.d("MainActivity", "Attempting to end call...")
            
            // Multiple approaches to end call
            var success = false
            
            // Method 1: Try using InCallService to properly end/reject the call
            try {
                success = MyCallService.endCurrentCallStatic()
                android.util.Log.d("MainActivity", "InCallService.endCurrentCall() success: $success")
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "InCallService.endCurrentCall() failed: ${e.message}")
            }
            
            // Method 2: Try TelecomManager (Android 9+)
            if (!success && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                if (telecomManager != null) {
                    try {
                        success = telecomManager.endCall()
                        android.util.Log.d("MainActivity", "TelecomManager.endCall() success: $success")
                    } catch (e: SecurityException) {
                        android.util.Log.w("MainActivity", "TelecomManager.endCall() failed: ${e.message}")
                    }
                }
            }
            
            // Method 3: Send KEYCODE_ENDCALL
            if (!success) {
                try {
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "input keyevent 6"))
                    android.util.Log.d("MainActivity", "Sent KEYCODE_ENDCALL with su")
                    success = true
                } catch (e: Exception) {
                    android.util.Log.w("MainActivity", "Failed to send keyevent with su: ${e.message}")
                    
                    // Try without su
                    try {
                        Runtime.getRuntime().exec("input keyevent 6")
                        android.util.Log.d("MainActivity", "Sent KEYCODE_ENDCALL without su")
                        success = true
                    } catch (e2: Exception) {
                        android.util.Log.w("MainActivity", "Failed to send keyevent: ${e2.message}")
                    }
                }
            }
            
            // Method 4: Try AudioManager approach
            if (!success) {
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
                    audioManager?.let { am ->
                        // This might work on some devices
                        val keyEvent = android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_ENDCALL)
                        am.dispatchMediaKeyEvent(keyEvent)
                        val keyEventUp = android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_ENDCALL)
                        am.dispatchMediaKeyEvent(keyEventUp)
                        android.util.Log.d("MainActivity", "Sent media key events")
                        success = true
                    }
                } catch (e: Exception) {
                    android.util.Log.w("MainActivity", "Failed to send media key events: ${e.message}")
                }
            }
            
            // If InCallService didn't handle it, manually emit the event
            if (!success) {
                CallEventDispatcher.emitCallEnded()
            }
            
            result.success(success)
            android.util.Log.d("MainActivity", "End call completed, success: $success")
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to end call", e)
            // Still emit event for UI consistency
            CallEventDispatcher.emitCallEnded()
            result.success(false)
        }
    }

    private fun rejectCall(result: MethodChannel.Result) {
        try {
            android.util.Log.d("MainActivity", "Attempting to reject incoming call...")
            
            // Try using InCallService to reject the incoming call
            var success = false
            try {
                success = MyCallService.endCurrentCallStatic()
                android.util.Log.d("MainActivity", "InCallService.endCurrentCall() for reject success: $success")
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "InCallService.endCurrentCall() for reject failed: ${e.message}")
            }
            
            // If that didn't work, try the same methods as endCall
            if (!success) {
                endCall(result)
                return
            }
            
            result.success(success)
            android.util.Log.d("MainActivity", "Reject call completed, success: $success")
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to reject call", e)
            // Fallback to regular endCall
            endCall(result)
        }
    }

    private fun answerCall(result: MethodChannel.Result) {
        try {
            android.util.Log.d("MainActivity", "Attempting to answer call...")

            var success = false

            // Prefer using InCallService when available
            try {
                success = MyCallService.answerCurrentCallStatic()
                android.util.Log.d("MainActivity", "InCallService.answerCurrentCall() success: $success")
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "InCallService.answerCurrentCall() failed: ${e.message}")
            }

            // Fallback to TelecomManager if needed
            if (!success && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                try {
                    telecomManager?.let {
                        it.acceptRingingCall()
                        success = true
                    }
                    android.util.Log.d("MainActivity", "TelecomManager.acceptRingingCall() attempted, success=$success")
                } catch (e: SecurityException) {
                    android.util.Log.w("MainActivity", "TelecomManager.acceptRingingCall() failed: ${e.message}")
                }
            }

            result.success(success)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to answer call", e)
            result.success(false)
        }
    }
}
