import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'core/services/call_event_handler.dart';
import 'pages/active_call_screen.dart';
import 'pages/home_page.dart';
import 'pages/incoming_call_screen.dart';
import 'pages/permission_page.dart';
import 'pages/splash_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _callChannel = MethodChannel('app.call_manager/call');
  final List<_PendingCallEvent> _pendingEvents = <_PendingCallEvent>[];
  bool _isDraining = false;
  String? _currentCallNumber;
  String? _lastEventMethod;
  bool _isOnActiveCallScreen = false;

  @override
  void initState() {
    super.initState();
    _callChannel.setMethodCallHandler(_handleCallMethod);
    // Initialize call event handler for logging
    CallEventHandler.initialize();
  }

  @override
  void dispose() {
    _callChannel.setMethodCallHandler(null);
    CallEventHandler.dispose();
    super.dispose();
  }

  Future<dynamic> _handleCallMethod(MethodCall call) async {
    debugPrint('📞 Received call event: ${call.method}');
    
    final Map<Object?, Object?> raw = (call.arguments as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final Map<String, dynamic> payload = <String, dynamic>{};
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      final Object? key = entry.key;
      if (key is String) {
        payload[key] = entry.value;
      }
    }

    debugPrint('📞 Event payload: $payload');

    // Forward to call event handler for logging/database updates
    await CallEventHandler.handleEvent(call.method, payload);

    final _PendingCallEvent event = _PendingCallEvent(call.method, payload);
    if (!_dispatchEvent(event)) {
      debugPrint('📞 Event queued for later dispatch: ${call.method}');
      _pendingEvents.add(event);
      _schedulePendingDrain();
    } else {
      debugPrint('📞 Event dispatched immediately: ${call.method}');
    }
    return null;
  }

  void _schedulePendingDrain() {
    if (_isDraining) return;
    _isDraining = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainPendingEvents();
    });
  }

  void _drainPendingEvents() {
    final NavigatorState? navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      _isDraining = false;
      if (_pendingEvents.isNotEmpty) {
        _schedulePendingDrain();
      }
      return;
    }

    final List<_PendingCallEvent> toProcess = List<_PendingCallEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    for (final _PendingCallEvent event in toProcess) {
      _navigateForEvent(navigator, event);
    }
    _isDraining = false;
  }

  bool _dispatchEvent(_PendingCallEvent event) {
    final NavigatorState? navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      return false;
    }
    _navigateForEvent(navigator, event);
    return true;
  }

  void _navigateForEvent(NavigatorState navigator, _PendingCallEvent event) {
    debugPrint('🧭 Navigating for event: ${event.method}');
    
    final String number = (event.payload['number'] as String?)?.trim() ?? 'Unknown';
    final String? caller = (event.payload['caller'] as String?)?.trim();

    // For outgoingCallConnected, allow it even if it's the same call
    // because we need to update the UI state from dialing to connected
    if (event.method != 'outgoingCallConnected') {
      // Prevent duplicate events for the same call (except outgoingCallConnected)
      if (event.method == _lastEventMethod && number == _currentCallNumber) {
        debugPrint('🧭 Skipping duplicate event: ${event.method} for $number');
        return;
      }
    }
    
    // Update tracking variables
    _currentCallNumber = number;
    _lastEventMethod = event.method;
    
    debugPrint('🧭 Current route tracking: isOnActiveCallScreen=$_isOnActiveCallScreen');
    
    // Clear tracking on call end
    if (event.method == 'callEnded') {
      _currentCallNumber = null;
      _lastEventMethod = null;
    }

    void pushHome() {
      navigator.pushNamedAndRemoveUntil(
        '/home',
        (Route<dynamic> route) => false,
      );
      _isOnActiveCallScreen = false;
    }

    void pushActive({required bool isDialing}) {
      navigator.pushNamedAndRemoveUntil(
        '/active',
        (Route<dynamic> route) => route.settings.name == '/home',
        arguments: ActiveCallArguments(
          number: number,
          caller: caller,
          isDialing: isDialing,
        ),
      );
      _isOnActiveCallScreen = true;
    }

    switch (event.method) {
      case 'incomingCall':
        // Skip incoming call events for outgoing calls
        if (_lastEventMethod == 'outgoingCall') {
          debugPrint('Skipping incoming call event for outgoing call');
          return;
        }
        navigator.pushNamedAndRemoveUntil(
          '/incoming',
          (Route<dynamic> route) => route.settings.name == '/home',
          arguments: IncomingCallArguments(
            number: number,
            caller: caller,
          ),
        );
        _isOnActiveCallScreen = false;
        break;
      case 'incomingCallConnected':
        pushActive(isDialing: false);
        break;
      case 'outgoingCall':
        // Only handle the first outgoing call event
        pushActive(isDialing: true);
        break;
      case 'outgoingCallConnected':
        // Check if we're already on the active call screen
        debugPrint('🧭 outgoingCallConnected: isOnActiveCallScreen=$_isOnActiveCallScreen');
        if (_isOnActiveCallScreen) {
          // Replace the existing route with connected state
          debugPrint('🧭 Replacing active call screen with connected state');
          navigator.pushReplacementNamed(
            '/active',
            arguments: ActiveCallArguments(
              number: number,
              caller: caller,
              isDialing: false,
            ),
          );
        } else {
          // Navigate to active call screen
          debugPrint('🧭 Navigating to active call screen (connected)');
          pushActive(isDialing: false);
        }
        break;
      case 'callEnded':
        debugPrint('Processing callEnded event - navigating to home');
        pushHome();
        break;
      default:
        debugPrint('Unhandled call event: ${event.method}');
        break;
    }
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return _defaultRoute(const SplashPage(), settings);
      case '/permission':
        return _defaultRoute(const PermissionPage(), settings);
      case '/home':
        return _defaultRoute(const HomePage(), settings);
      case '/incoming':
        final IncomingCallArguments args = settings.arguments is IncomingCallArguments
            ? settings.arguments! as IncomingCallArguments
            : IncomingCallArguments(number: 'Unknown');
        return _defaultRoute(
          IncomingCallScreen(
            number: args.number,
            caller: args.caller,
          ),
          settings,
        );
      case '/active':
        final ActiveCallArguments args = settings.arguments is ActiveCallArguments
            ? settings.arguments! as ActiveCallArguments
            : const ActiveCallArguments(number: 'Unknown');
        return _defaultRoute(
          ActiveCallScreen(
            number: args.number,
            caller: args.caller,
            isDialing: args.isDialing,
          ),
          settings,
        );
      default:
        return null;
    }
  }

  PageRoute<dynamic> _defaultRoute(Widget child, RouteSettings settings) {
    // Use smooth transitions for call-related screens
    if (settings.name == '/active' || settings.name == '/incoming') {
      return PageRouteBuilder<dynamic>(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Smooth fade and slight scale transition
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.95,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      );
    }
    
    // Default transition for other screens
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Umar Dialer',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      initialRoute: '/splash',
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

class _PendingCallEvent {
  const _PendingCallEvent(this.method, this.payload);

  final String method;
  final Map<String, dynamic> payload;
}
