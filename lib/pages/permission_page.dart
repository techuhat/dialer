import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/services/dialer_role_service.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with WidgetsBindingObserver {
  bool _hasCallPermission = false;
  bool _hasContactsPermission = false;
  bool _hasNotificationPermission = false;
  /// Android 14+ "full-screen notifications" toggle. Auto-granted below 14 and for
  /// most default dialers; this is what actually powers the lockscreen call screen.
  bool _hasFullScreenIntentPermission = true;
  bool _hasBackgroundPermission = false;
  bool _isDefaultDialer = false;
  bool _isRequestingDefaultDialer = false;
  bool _isGrantAllInProgress = false;

  /// Only what the dialer cannot work without. Battery optimisation is excluded: MIUI keeps
  /// reporting it denied even after the user allows it, which trapped people on this screen.
  bool get _allRequirementsMet {
    return _hasCallPermission &&
        _hasContactsPermission &&
        _hasNotificationPermission &&
        _isDefaultDialer;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _refreshDefaultDialerStatus();
    }
  }

  Future<void> _initializeState() async {
    await _checkPermissions();
    await _refreshDefaultDialerStatus();
  }

  Future<void> _checkPermissions() async {
    final PermissionStatus phoneStatus = await Permission.phone.status;
    final PermissionStatus contactsStatus = await Permission.contacts.status;
    PermissionStatus? notificationStatus;
    bool notificationGranted = false;
    if (Platform.isAndroid) {
      notificationGranted = await DialerRoleService.hasNotificationPermission();
      if (!notificationGranted) {
        notificationStatus = await Permission.notification.status;
        notificationGranted = notificationStatus.isGranted;
        debugPrint(
          'Notification permission status (fallback check): $notificationStatus',
        );
      }
    } else {
      notificationStatus = await Permission.notification.status;
      notificationGranted = notificationStatus.isGranted;
      debugPrint('Notification permission status (check): $notificationStatus');
    }

    final PermissionStatus batteryStatus = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.status
        : PermissionStatus.granted;

    final bool fullScreenIntentGranted =
        !Platform.isAndroid || await DialerRoleService.hasFullScreenIntentPermission();

    debugPrint('Phone permission status (check): $phoneStatus');
    debugPrint('Contacts permission status (check): $contactsStatus');
    debugPrint('Battery optimization status (check): $batteryStatus');
    debugPrint('Full-screen intent allowed (check): $fullScreenIntentGranted');

    if (!mounted) return;
    setState(() {
      _hasCallPermission = phoneStatus.isGranted;
      _hasContactsPermission = contactsStatus.isGranted;
      _hasNotificationPermission = notificationGranted;
      _hasBackgroundPermission = batteryStatus.isGranted;
      _hasFullScreenIntentPermission = fullScreenIntentGranted;
    });
  }

  Future<void> _refreshDefaultDialerStatus() async {
    final bool isDefault = await DialerRoleService.isDefaultDialer();
    if (mounted) setState(() => _isDefaultDialer = isDefault);
  }

  Future<PermissionStatus> _requestPermissionWithFeedback({
    required Permission permission,
    required String logLabel,
    required String permanentlyDeniedMessage,
    required String deniedMessage,
    bool showFeedback = true,
  }) async {
    PermissionStatus status;
    try {
      status = await permission.request();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('❌ $logLabel permission request failed: $error');
      debugPrint('$stackTrace');
      if (showFeedback && mounted) {
        _showSnackBar(
          'Unable to request $logLabel permission. Please enable it from Settings.',
        );
      }
      if (mounted) {
        await _checkPermissions();
      }
      return PermissionStatus.denied;
    }

    debugPrint('$logLabel permission status (request): $status');

    if (!mounted) {
      return status;
    }

    if (status.isGranted) {
      await _checkPermissions();
      return status;
    }

    if (!showFeedback) {
      await _checkPermissions();
      return status;
    }

    if (status.isPermanentlyDenied) {
      if (permanentlyDeniedMessage.isNotEmpty) {
        _showSnackBar(permanentlyDeniedMessage);
      }
      await openAppSettings();
    } else if (deniedMessage.isNotEmpty) {
      _showSnackBar(deniedMessage);
    }

    await _checkPermissions();
    return status;
  }

  Future<bool> _ensureNotificationPermission({bool showFeedback = true}) async {
    if (Platform.isAndroid) {
      if (_hasNotificationPermission) {
        return true;
      }

      await DialerRoleService.requestNotificationPermission();
      await _checkPermissions();
      if (_hasNotificationPermission) {
        return true;
      }

      if (showFeedback) {
        _showSnackBar('Notification permission required for call alerts.');
      }
      return _hasNotificationPermission;
    }

    final PermissionStatus status = await Permission.notification.request();
    debugPrint('Notification permission status (request): $status');

    if (status.isGranted) {
      await _checkPermissions();
      return true;
    }

    if (showFeedback) {
      if (status.isPermanentlyDenied) {
        _showSnackBar(
          'Notification permission permanently denied. Enable it in Settings.',
        );
        await openAppSettings();
      } else {
        _showSnackBar('Notification permission required for call alerts.');
      }
    }

    await _checkPermissions();
    return false;
  }

  /// Android 14+: the lock-screen incoming call screen needs the full-screen-intent permission.
  Future<void> _ensureFullScreenIntentPermission() async {
    if (!Platform.isAndroid) return;
    if (await DialerRoleService.hasFullScreenIntentPermission()) return;
    await DialerRoleService.requestFullScreenIntentPermission();
  }

  Future<void> _openNotificationSettings() async {
    try {
      await openAppSettings();
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to open notification settings: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _openDefaultDialerSettings() async {
    if (!Platform.isAndroid) {
      await openAppSettings();
      return;
    }

    if (!await DialerRoleService.openDefaultDialerSettings()) {
      await openAppSettings();
    }
  }

  List<String> _missingRequirements() {
    final List<String> missing = <String>[];
    if (!_hasCallPermission) {
      missing.add('Phone permission');
    }
    if (!_hasContactsPermission) {
      missing.add('Contacts access');
    }
    if (!_hasNotificationPermission) {
      missing.add('Notifications');
    }
    if (Platform.isAndroid) {
      if (!_hasFullScreenIntentPermission) {
        missing.add('Full-screen call notifications');
      }
      if (!_hasBackgroundPermission) {
        missing.add('Background activity');
      }
    }
    if (Platform.isAndroid && !_isDefaultDialer) {
      missing.add('Default phone app role');
    }
    return missing;
  }

  Future<void> _handlePhonePermissionTap() async {
    await _requestPermissionWithFeedback(
      permission: Permission.phone,
      logLabel: 'Phone',
      permanentlyDeniedMessage:
          'Phone permission permanently denied. Enable it in Settings.',
      deniedMessage: 'Phone permission required to continue.',
    );
  }

  Future<void> _handleContactsPermissionTap() async {
    await _requestPermissionWithFeedback(
      permission: Permission.contacts,
      logLabel: 'Contacts',
      permanentlyDeniedMessage:
          'Contacts permission permanently denied. Enable it in Settings.',
      deniedMessage: 'Contacts permission required to continue.',
    );
  }

  Future<void> _handleNotificationPermissionTap() async {
    if (Platform.isAndroid && _hasNotificationPermission) {
      await _openNotificationSettings();
      await _checkPermissions();
      return;
    }

    final bool granted = await _ensureNotificationPermission();
    if (!granted && Platform.isAndroid) {
      await _openNotificationSettings();
      await _checkPermissions();
    }
  }

  Future<void> _handleFullScreenIntentTap() async {
    if (!Platform.isAndroid) {
      return;
    }
    await DialerRoleService.requestFullScreenIntentPermission();
    await _checkPermissions();
  }

  Future<void> _handleBackgroundPermissionTap() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _requestPermissionWithFeedback(
      permission: Permission.ignoreBatteryOptimizations,
      logLabel: 'Battery optimization',
      permanentlyDeniedMessage:
          'Disable battery optimizations for Umar Dialer from system settings.',
      deniedMessage:
          'Background activity permission is required to keep calls active when the app is closed.',
    );
  }

  Future<void> _requestPermissions() async {
    if (_isGrantAllInProgress) {
      return;
    }

    if (_allRequirementsMet) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    setState(() => _isGrantAllInProgress = true);

    try {
      await _requestPermissionWithFeedback(
        permission: Permission.phone,
        logLabel: 'Phone',
        permanentlyDeniedMessage:
            'Phone permission permanently denied. Enable it in Settings.',
        deniedMessage: 'Phone permission required to continue.',
        showFeedback: false,
      );

      await _requestPermissionWithFeedback(
        permission: Permission.contacts,
        logLabel: 'Contacts',
        permanentlyDeniedMessage:
            'Contacts permission permanently denied. Enable it in Settings.',
        deniedMessage: 'Contacts permission required to continue.',
        showFeedback: false,
      );

      if (Platform.isAndroid) {
        await _ensureNotificationPermission(showFeedback: false);
      } else {
        await _requestPermissionWithFeedback(
          permission: Permission.notification,
          logLabel: 'Notification',
          permanentlyDeniedMessage:
              'Notification permission permanently denied. Enable it in Settings.',
          deniedMessage: 'Notification permission required for call alerts.',
          showFeedback: false,
        );
      }

      if (Platform.isAndroid) {
        if (!_hasFullScreenIntentPermission) {
          await _handleFullScreenIntentTap();
        }

        await _requestPermissionWithFeedback(
          permission: Permission.ignoreBatteryOptimizations,
          logLabel: 'Battery optimization',
          permanentlyDeniedMessage:
              'Disable battery optimizations for Umar Dialer from system settings.',
          deniedMessage:
              'Background activity permission is required to keep calls active when the app is closed.',
          showFeedback: false,
        );

        // Full-screen intent (Android 14+) — lets the incoming-call screen wake
        // the device on the lockscreen.
        await _ensureFullScreenIntentPermission();
      }

      await _checkPermissions();

      if (Platform.isAndroid) {
        if (!_isDefaultDialer) {
          await _requestSetDefaultDialer(fromUserInteraction: false);
        } else {
          await _refreshDefaultDialerStatus();
        }
      }

      await _checkPermissions();

      if (_allRequirementsMet) {
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      final List<String> missing = _missingRequirements();
      if (missing.isNotEmpty) {
        _showSnackBar('Enable ${missing.join(', ')} to continue.');
      } else {
        _showSnackBar('All permissions must be enabled to continue.');
      }
    } finally {
      if (mounted) {
        setState(() => _isGrantAllInProgress = false);
      }
    }
  }

  Future<void> _requestSetDefaultDialer({bool fromUserInteraction = true}) async {
    if (!Platform.isAndroid) {
      return;
    }

    if (_isDefaultDialer && fromUserInteraction) {
      await _openDefaultDialerSettings();
      await _refreshDefaultDialerStatus();
      await _checkPermissions();
      return;
    }

    if (_isRequestingDefaultDialer) return;

    setState(() => _isRequestingDefaultDialer = true);
    final bool granted = await DialerRoleService.requestDefaultDialer();
    await _refreshDefaultDialerStatus();
    await _checkPermissions();
    if (!granted && !_isDefaultDialer) {
      _showSnackBar('Please set this app as your default phone app.');
    }
    if (mounted) setState(() => _isRequestingDefaultDialer = false);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const Color gradientStart = Color(0xFF0A1929);
    const Color gradientEnd = Color(0xFF1C3A5E);
    const Color lightTileColor = Color(0xFFF7F9FC);
                const Color darkSubtitleColor = Color(0xFF90B0CB);

    return Scaffold(
      backgroundColor: gradientStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [gradientStart, gradientEnd],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;
              final bool isAndroid = Platform.isAndroid;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Container(
                              height: 192,
                              width: 192,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4D9FFF,
                                    ).withValues(alpha: 0.5),
                                    blurRadius: 25,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.network(
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuC59beDNXyHCcwLW6RAgu7F4sT267xsYtbZTcznRdt14sesp3mx8YZXt55jDfH0MQrRQv6HMV9KxIqeAoBs8pt6Hi6a79kk3dJXcfgawfYqa6hi91J5iAe95NeLlA2l3WF-2n1F5o5bRrM19NzHMGCbWrvRA82LfZLGGfvnZdG2kU51AoCGUy9RqEcIMhsvb_qKmLfnx00qGVuDN9DWZhqbDLa73EzDIo-1B54oxuGmgV-k5wVUdIC1CWMNzqPHAE9ekDI4qiwG0js',
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (
                                        BuildContext context,
                                        Widget child,
                                        ImageChunkEvent? progress,
                                      ) {
                                        if (progress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: const Color(0xFF12324F),
                                          alignment: Alignment.center,
                                          child: CircularProgressIndicator(
                                            value:
                                                progress.expectedTotalBytes !=
                                                    null
                                                ? progress.cumulativeBytesLoaded /
                                                      (progress
                                                              .expectedTotalBytes ??
                                                          1)
                                                : null,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(Color(0xFF4D9FFF)),
                                          ),
                                        );
                                      },
                                  errorBuilder:
                                      (
                                        BuildContext context,
                                        Object error,
                                        StackTrace? stackTrace,
                                      ) {
                                        return Container(
                                          color: const Color(0xFF12324F),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.signal_wifi_off,
                                            size: 48,
                                            color: Colors.white70,
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Unlock Full Potential',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'To manage your calls effectively, we need access to the following:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: darkSubtitleColor,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Wrap(
                              runSpacing: 16,
                              children: [
                                _buildPermissionTile(
                                  icon: Icons.phone,
                                  title: 'Phone Access',
                                  subtitle:
                                      'To identify callers and manage incoming/outgoing calls.',
                                  granted: _hasCallPermission,
                                  isDarkMode: isDarkMode,
                                  lightTileColor: lightTileColor,
                                  onTap: _handlePhonePermissionTap,
                                  onToggleTap: _handlePhonePermissionTap,
                                ),
                                _buildPermissionTile(
                                  icon: Icons.contacts,
                                  title: 'Contacts',
                                  subtitle:
                                      'To display contact names for your call history.',
                                  granted: _hasContactsPermission,
                                  isDarkMode: isDarkMode,
                                  lightTileColor: lightTileColor,
                                  onTap: _handleContactsPermissionTap,
                                  onToggleTap: _handleContactsPermissionTap,
                                ),
                                _buildPermissionTile(
                                  icon: Icons.notifications_active,
                                  title: 'Notifications',
                                  subtitle:
                                      'Display call notifications with controls during active calls.',
                                  granted: _hasNotificationPermission,
                                  isDarkMode: isDarkMode,
                                  lightTileColor: lightTileColor,
                                  onTap: _handleNotificationPermissionTap,
                                  onToggleTap: _handleNotificationPermissionTap,
                                ),
                                if (isAndroid)
                                  _buildPermissionTile(
                                    icon: Icons.screen_lock_portrait,
                                    title: 'Lockscreen Access',
                                    subtitle:
                                        'Show the incoming call UI over the lockscreen.',
                                    granted: _hasFullScreenIntentPermission,
                                    isDarkMode: isDarkMode,
                                    lightTileColor: lightTileColor,
                                    onTap: _handleFullScreenIntentTap,
                                    onToggleTap: _handleFullScreenIntentTap,
                                  ),
                                if (isAndroid)
                                  _buildPermissionTile(
                                    icon: Icons.battery_charging_full,
                                    title: 'Background Calls',
                                    subtitle:
                                        'Keeps calls connected even when the app is closed.',
                                    granted: _hasBackgroundPermission,
                                    isDarkMode: isDarkMode,
                                    lightTileColor: lightTileColor,
                                    onTap: _handleBackgroundPermissionTap,
                                    onToggleTap: _handleBackgroundPermissionTap,
                                  ),
                                if (isAndroid)
                                  _buildPermissionTile(
                                    icon: Icons.app_registration,
                                    title: 'Set as Default',
                                    subtitle:
                                        'Make this app your primary call manager.',
                                    granted: _isDefaultDialer,
                                    isDarkMode: isDarkMode,
                                    lightTileColor: lightTileColor,
                                    onTap: () {
                                      _requestSetDefaultDialer();
                                    },
                                    onToggleTap: () {
                                      _requestSetDefaultDialer();
                                    },
                                    isProcessing: _isRequestingDefaultDialer,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4D9FFF,
                                ).withValues(alpha: 0.45),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed:
                                _isGrantAllInProgress ? null : _requestPermissions,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: const StadiumBorder(),
                              backgroundColor: const Color(0xFF4D9FFF),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: _isGrantAllInProgress
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<
                                              Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Requesting permissions...'),
                                    ],
                                  )
                                : Text(
                                    _allRequirementsMet
                                        ? 'Continue'
                                        : 'Grant All Permissions',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required bool isDarkMode,
    required Color lightTileColor,
    VoidCallback? onTap,
    VoidCallback? onToggleTap,
    bool isProcessing = false,
  }) {
    final Color tileColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : lightTileColor;
    final Color iconBackground = isDarkMode
        ? const Color(0xFF223749)
        : const Color(0xFFE2E8F0);
    final Color titleColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1F2933);
    final Color subtitleColor = isDarkMode
        ? const Color(0xFF90B0CB)
        : const Color(0xFF64748B);

    final Widget trailing = isProcessing
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4D9FFF)),
            ),
          )
        : _PermissionToggle(
            isActive: granted,
            isDarkMode: isDarkMode,
            onTap: onToggleTap,
          );

    final Widget tile = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );

    if (onTap == null) {
      return tile;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: tile,
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.isActive,
    required this.isDarkMode,
    this.onTap,
  });

  final bool isActive;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color inactiveColor = isDarkMode
        ? const Color(0xFF223749)
        : const Color(0xFFCBD5E1);

    final Widget toggle = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 51,
      height: 31,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4D9FFF) : inactiveColor,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 27,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return toggle;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: toggle,
    );
  }
}
