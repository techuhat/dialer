package com.techuhat.umar.call

import android.os.Build
import android.telecom.CallAudioState
import android.telecom.InCallService

object CallAudio {
    const val EARPIECE = "earpiece"
    const val SPEAKER = "speaker"
    const val WIRED = "wired"
    const val BLUETOOTH = "bluetooth"

    private val ROUTES = linkedMapOf(
        BLUETOOTH to CallAudioState.ROUTE_BLUETOOTH,
        WIRED to CallAudioState.ROUTE_WIRED_HEADSET,
        SPEAKER to CallAudioState.ROUTE_SPEAKER,
        EARPIECE to CallAudioState.ROUTE_EARPIECE,
    )

    fun name(route: Int): String = ROUTES.entries.firstOrNull { (route and it.value) != 0 }?.key ?: EARPIECE

    /** "Phone" means earpiece or wired headset, whichever Telecom has; same as the stock dialer. */
    fun mask(name: String): Int = when (name) {
        SPEAKER -> CallAudioState.ROUTE_SPEAKER
        BLUETOOTH -> CallAudioState.ROUTE_BLUETOOTH
        else -> CallAudioState.ROUTE_WIRED_OR_EARPIECE
    }

    // CallEndpoint (API 34) supersedes CallAudioState, which still works on every supported version.
    @Suppress("DEPRECATION")
    fun current(): CallAudioState? = CallRegistry.service?.callAudioState

    @Suppress("DEPRECATION")
    fun setRoute(service: InCallService, name: String) = service.setAudioRoute(mask(name))

    fun isSpeaker(state: CallAudioState?) = state != null && (state.route and CallAudioState.ROUTE_SPEAKER) != 0

    fun toMap(state: CallAudioState?): Map<String, Any?> {
        if (state == null) return mapOf("route" to EARPIECE, "routes" to listOf(EARPIECE, SPEAKER), "muted" to false)
        return mapOf(
            "route" to name(state.route),
            "routes" to ROUTES.filterValues { (state.supportedRouteMask and it) != 0 }.keys.toList(),
            "muted" to state.isMuted,
            "bluetoothName" to bluetoothName(state),
        )
    }

    // Reading a device name needs BLUETOOTH_CONNECT on Android 12+; without it Flutter shows "Bluetooth".
    private fun bluetoothName(state: CallAudioState): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        return try {
            state.activeBluetoothDevice?.name
        } catch (_: SecurityException) {
            null
        }
    }
}
