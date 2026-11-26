import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'core/call_router.dart';
import 'core/services/call_log_service.dart';
import 'core/services/nav_style_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/wallpaper_service.dart';
import 'core/theme.dart';
import 'pages/call/in_call_screen.dart';
import 'pages/call/incoming_call_screen.dart';
import 'pages/home_page.dart';
import 'pages/permission_page.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    CallRouter.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => WallpaperService()),
        // Not lazy: the saved style must be loaded before HomePage's first frame.
        ChangeNotifierProvider(create: (_) => NavStyleService(), lazy: false),
      ],
      child: Consumer<ThemeService>(
        builder: (BuildContext context, ThemeService theme, Widget? child) => MaterialApp(
          title: 'Umar Dialer',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          navigatorKey: CallRouter.instance.navigatorKey,
          navigatorObservers: <NavigatorObserver>[CallRouter.instance.observer],
          home: const _Bootstrap(),
          onGenerateRoute: _route,
        ),
      ),
    );
  }

  static Route<dynamic>? _route(RouteSettings settings) {
    return switch (settings.name) {
      Routes.permission => MaterialPageRoute<void>(builder: (_) => const PermissionPage(), settings: settings),
      Routes.home => _fade(const HomePage(), settings, const Duration(milliseconds: 200)),
      Routes.incoming => _fade(const IncomingCallScreen(), settings, const Duration(milliseconds: 280)),
      Routes.inCall => _fade(const InCallScreen(), settings, const Duration(milliseconds: 280)),
      _ => null,
    };
  }

  static PageRoute<void> _fade(Widget page, RouteSettings settings, Duration duration) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, Animation<double> animation, _, Widget child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}

/// First screen: opens the live call if there is one, otherwise home or the permission flow.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final bool phoneGranted = await Permission.phone.isGranted;
    // A ringing call must reach its screen on phone permission alone; contacts only add names.
    if (phoneGranted && await CallRouter.instance.restore()) return;
    final bool contactsGranted = await Permission.contacts.isGranted;
    if (!mounted || CallRouter.instance.isOnCallScreen) return;

    final bool ready = phoneGranted && contactsGranted;
    Navigator.of(context).pushReplacementNamed(ready ? Routes.home : Routes.permission);
    if (ready) unawaited(CallLogService.refresh());
  }

  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF0A1929));
}
