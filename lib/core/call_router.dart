import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'call_manager.dart';
import 'call_service.dart';
import 'models/live_call.dart';
import 'services/call_log_service.dart';
import 'services/caller_details.dart';
import 'services/dial_intent_service.dart';

abstract final class Routes {
  static const String home = '/home';
  static const String permission = '/permission';
  static const String incoming = '/incoming';
  static const String inCall = '/active';

  static bool isCallScreen(String? name) => name == incoming || name == inCall;
}

/// Turns native call events into [CallManager] updates and call-screen navigation.
/// The only place that decides which call screen is showing.
class CallRouter {
  CallRouter._();

  static final CallRouter instance = CallRouter._();

  static const Duration endedDisplayTime = Duration(milliseconds: 1500);

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final PageRouteTracker observer = PageRouteTracker();

  NavigatorState? get _navigator => navigatorKey.currentState;

  bool get isOnCallScreen => Routes.isCallScreen(observer.topPage);

  void start() {
    CallService.channel.setMethodCallHandler(_onEvent);
    unawaited(CallService.listen());
  }

  /// Pulls the native call state (cold start, or the app was reopened mid-call).
  /// Returns true when a call screen is now showing.
  Future<bool> restore() async {
    final Map<Object?, Object?>? snapshot = await CallService.getCalls();
    if (snapshot != null) CallManager.instance.applySnapshot(snapshot);
    return showCurrentCall();
  }

  bool showCurrentCall() {
    final CallManager calls = CallManager.instance;
    if (calls.foreground != null) {
      _show(Routes.inCall);
    } else if (calls.ringing != null) {
      _show(Routes.incoming);
    } else {
      return false;
    }
    return true;
  }

  /// Straight to the in-call screen, e.g. right after answering, before Telecom confirms.
  void showInCall() => _show(Routes.inCall);

  void goHome() {
    if (!_popToHome()) _navigator?.pushReplacementNamed(Routes.home);
  }

  bool _popToHome() {
    final NavigatorState? navigator = _navigator;
    if (navigator == null) return false;
    bool foundHome = false;
    navigator.popUntil((Route<dynamic> route) {
      foundHome = route.settings.name == Routes.home;
      return foundHome || route.isFirst;
    });
    return foundHome;
  }

  Future<void> _onEvent(MethodCall call) async {
    final Map<Object?, Object?> payload = call.arguments is Map ? call.arguments as Map<Object?, Object?> : const {};
    switch (call.method) {
      case 'callsChanged':
        CallManager.instance.applySnapshot(payload);
        return;
      case 'audioStateChanged':
        CallManager.instance.applyAudio(payload);
        return;
      case 'showCall':
        showCurrentCall();
        return;
      case 'callLogChanged':
        unawaited(CallLogService.refresh());
        return;
      case 'dialNumber':
        DialIntentService.request(payload['number'] as String? ?? '');
        if (!isOnCallScreen) _popToHome(); // on a cold start the bootstrap route opens home itself
        return;
    }

    switch (call.method) {
      case 'incomingCall':
        _show(Routes.incoming);
      case 'callWaiting':
      case 'outgoingCall':
      case 'incomingCallConnected':
      case 'outgoingCallConnected':
        _show(Routes.inCall);
      case 'callEnded':
        _onCallEnded(payload);
    }
  }

  void _onCallEnded(Map<Object?, Object?> payload) {
    if ((payload['remainingCalls'] as num? ?? 0) > 0) {
      showCurrentCall(); // e.g. the active call ended while another one is still ringing
      return;
    }
    CallerDetails.clearCache();
    final int? connectedMs = (payload['connectedSince'] as num?)?.toInt();
    CallManager.instance.markEnded(EndedCall(
      number: payload['number'] as String? ?? '',
      name: payload['name'] as String?,
      duration: connectedMs == null
          ? null
          : DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(connectedMs)),
    ));
    if (observer.topPage != Routes.inCall) {
      if (observer.topPage == Routes.incoming) goHome();
      return;
    }
    // Leave "Call ended" on screen briefly, unless another call has started meanwhile.
    Future<void>.delayed(endedDisplayTime, () {
      if (!CallManager.instance.hasCalls && observer.topPage == Routes.inCall) goHome();
    });
  }

  void _show(String route) {
    final NavigatorState? navigator = _navigator;
    if (navigator == null || observer.topPage == route) return;
    navigator.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => r.settings.name == Routes.home);
  }
}

/// Tracks the topmost page route; dialogs and sheets on top of it do not count.
class PageRouteTracker extends NavigatorObserver {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  String? get topPage {
    for (int i = _stack.length - 1; i >= 0; i--) {
      if (_stack[i] is PageRoute) return _stack[i].settings.name;
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final int index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute == null) return;
    if (index >= 0) {
      _stack[index] = newRoute;
    } else {
      _stack.add(newRoute);
    }
  }
}
