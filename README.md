# Umar Dialer

Android default-dialer app: Flutter UI on top of a Kotlin `InCallService`.

## How a call flows

1. Telecom binds `MyCallService` and reports every call (`onCallAdded`, state and audio changes).
2. The service keeps `CallRegistry` current, refreshes the notifications (`CallNotifier`) and emits
   events on the `app.call_manager/call` channel: `callsChanged` and `audioStateChanged` (full state)
   plus lifecycle events (`incomingCall`, `outgoingCall`, `…Connected`, `callWaiting`, `callEnded`).
3. In Flutter, `CallRouter` applies them to `CallManager` and picks the screen; `IncomingCallScreen`
   and `InCallScreen` only render `CallManager`. Commands go back through `CallService`.

| Area | Kotlin | Flutter |
| --- | --- | --- |
| Call state | `call/` (`CallRegistry`, `TrackedCall`, `CallController`, `CallAudio`) | `core/call_manager.dart`, `core/models/live_call.dart` |
| Bridge | `bridge/` (`CallEventDispatcher`, `CallChannel`, `RoleChannel`) | `core/call_service.dart`, `core/call_router.dart` |
| Notifications | `notification/` (CallStyle incoming + ongoing) | — |
| Recents, blocking | `history/` (system call log, system block list) | `core/services/call_log_service.dart`, `pages/recents/` |
| Screens | — | `pages/call/`, `pages/` |

Recents come from the system call log, so calls made while the app was closed are included.
Blocked numbers live in the system block list and never ring. Unsaved callers show the name the
network sends (CNAP) where the operator provides it.

## Build and check

```powershell
flutter pub get
flutter analyze
flutter test
cd android; ./gradlew :app:compileDebugKotlin; cd ..
flutter build apk --debug
```

`kotlin.incremental=false` in `android/gradle.properties` is required while the project (D:) and the
Pub cache (C:) are on different drives.

Set the app as the default phone app on first launch; incoming calls need the phone, notification and
(Android 14+) full-screen-intent permissions.
