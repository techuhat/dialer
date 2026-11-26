package com.techuhat.umar.bridge

import android.Manifest
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telecom.TelecomManager
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Default-dialer role and the permissions that need an Activity. Construct before onCreate. */
class RoleChannel(private val activity: ComponentActivity) : MethodChannel.MethodCallHandler {
    private var pendingRole: MethodChannel.Result? = null
    private var pendingNotification: MethodChannel.Result? = null

    private val roleLauncher = activity.registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        pendingRole?.success(isDefaultDialer())
        pendingRole = null
    }

    private val notificationLauncher = activity.registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        pendingNotification?.success(granted)
        pendingNotification = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDefaultDialer" -> result.success(isDefaultDialer())
            "requestDefaultDialer" -> requestDefaultDialer(result)
            "openDefaultDialerSettings" -> result.success(openSettings(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
            "hasNotificationPermission" -> result.success(hasNotificationPermission())
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "hasFullScreenIntentPermission" -> result.success(canUseFullScreenIntent())
            "requestFullScreenIntentPermission" -> requestFullScreenIntent(result)
            else -> result.notImplemented()
        }
    }

    private fun isDefaultDialer(): Boolean =
        activity.getSystemService(TelecomManager::class.java)?.defaultDialerPackage == activity.packageName

    private fun requestDefaultDialer(result: MethodChannel.Result) {
        if (isDefaultDialer()) return result.success(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = activity.getSystemService(RoleManager::class.java)
            if (roles != null && roles.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                pendingRole?.success(false)
                pendingRole = result
                roleLauncher.launch(roles.createRequestRoleIntent(RoleManager.ROLE_DIALER))
                return
            }
        } else {
            @Suppress("DEPRECATION")
            val change = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
                .putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, activity.packageName)
            if (runCatching { activity.startActivity(change) }.isSuccess) return result.success(false)
        }
        openSettings(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
        result.success(false)
    }

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (hasNotificationPermission()) return result.success(true)
        pendingNotification?.success(false)
        pendingNotification = result
        notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    private fun canUseFullScreenIntent(): Boolean =
        NotificationManagerCompat.from(activity).canUseFullScreenIntent()

    private fun requestFullScreenIntent(result: MethodChannel.Result) {
        if (canUseFullScreenIntent() || Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return result.success(true)
        }
        openSettings(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.fromParts("package", activity.packageName, null))
        result.success(false)
    }

    private fun openSettings(action: String, data: Uri? = null): Boolean {
        val intent = Intent(action).setData(data).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (runCatching { activity.startActivity(intent) }.isSuccess) return true
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { activity.startActivity(details) }.isSuccess
    }

    companion object {
        const val CHANNEL = "app.call_manager/role"
    }
}
