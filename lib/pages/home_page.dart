import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/call_log_entry.dart';
import '../core/services/call_log_service.dart';
import '../core/services/dial_intent_service.dart';
import '../core/services/nav_style_service.dart';
import '../core/services/theme_service.dart';
import '../core/services/wallpaper_service.dart';
import '../core/theme.dart';
import '../core/widgets/dial_menu.dart';
import '../core/widgets/dialer_nav_bar.dart';
import '../core/widgets/nav_parts.dart';
import 'contacts_page.dart';
import 'dialpad_page.dart';
import 'notes_page.dart';
import 'recents/recents_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const int _recentsTab = 0;
  static const int _keypadTab = 2;
  static const Duration _seenAfter = Duration(milliseconds: 1500);

  static const List<NavDestination> _destinations = <NavDestination>[
    NavDestination(icon: Icons.schedule_outlined, selectedIcon: Icons.schedule, label: 'Recents'),
    NavDestination(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Contacts'),
    NavDestination(icon: Icons.dialpad, selectedIcon: Icons.dialpad, label: 'Keypad'),
    NavDestination(icon: Icons.sticky_note_2_outlined, selectedIcon: Icons.sticky_note_2, label: 'Notes'),
    NavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  static const List<Widget> _pages = <Widget>[
    RecentsPage(),
    ContactsPage(),
    DialpadPage(),
    NotesPage(),
    SettingsPage(),
  ];

  int _index = _recentsTab;
  int _unreadMissed = 0;
  StreamSubscription<List<CallLogEntry>>? _recents;
  Timer? _markSeen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DialIntentService.pendingNumber.addListener(_showKeypadForIntent);
    if (DialIntentService.pendingNumber.value != null) _index = _keypadTab;
    _recents = CallLogService.watch().listen((_) {
      if (mounted) setState(() => _unreadMissed = CallLogService.unreadMissedCount);
      _scheduleMarkSeen();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DialIntentService.pendingNumber.removeListener(_showKeypadForIntent);
    _recents?.cancel();
    _markSeen?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleMarkSeen();
  }

  /// Missed calls count as seen once Recents has been on screen for a moment, like the stock dialer.
  void _scheduleMarkSeen() {
    _markSeen?.cancel();
    if (_index != _recentsTab || _unreadMissed == 0) return;
    _markSeen = Timer(_seenAfter, () {
      if (mounted && _index == _recentsTab) CallLogService.markMissedRead();
    });
  }

  // A tel: link opens the keypad tab; DialpadPage fills in the number itself.
  void _showKeypadForIntent() {
    if (!mounted || DialIntentService.pendingNumber.value == null || _index == _keypadTab) return;
    setState(() => _index = _keypadTab);
  }

  void _select(int index) {
    setState(() => _index = index);
    _scheduleMarkSeen();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.watch<ThemeService>().isDarkMode;
    final WallpaperService wallpaper = context.watch<WallpaperService>();
    final bool showWallpaper = wallpaper.isActive && wallpaper.wallpaperFile != null;
    final bool dialMenu = context.watch<NavStyleService>().style == NavStyle.dial;
    final Map<int, int> badges = <int, int>{_recentsTab: _unreadMissed};
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.getBackgroundGradient(isDark))),
        ),
        if (showWallpaper) ...<Widget>[
          Positioned.fill(
            child: Image.file(
              wallpaper.wallpaperFile!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: wallpaper.opacity))),
        ],
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: IndexedStack(index: _index, children: _pages),
          // With the dial menu the bar slot only reserves room, so pages and snack bars keep clear of the dial.
          bottomNavigationBar: dialMenu
              ? SizedBox(height: DialMenu.clearance(context))
              : DialerNavBar(destinations: _destinations, selectedIndex: _index, onSelected: _select, badges: badges),
        ),
        if (dialMenu)
          Positioned.fill(
            child: DialMenu(destinations: _destinations, selectedIndex: _index, onSelected: _select, badges: badges),
          ),
      ],
    );
  }
}
