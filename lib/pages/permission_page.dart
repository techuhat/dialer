import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with WidgetsBindingObserver {
  static const MethodChannel _roleChannel = MethodChannel(
    'app.call_manager/role',
  );

  bool _hasCallPermission = false;
  bool _hasContactsPermission = false;
  bool _isDefaultDialer = false;
  bool _isRequestingDefaultDialer = false;

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

  // Check existing permissions
  Future<void> _checkPermissions() async {
    final PermissionStatus phoneStatus = await Permission.phone.status;
    final PermissionStatus contactsStatus = await Permission.contacts.status;

    debugPrint('Phone permission status (check): $phoneStatus');
    debugPrint('Contacts permission status (check): $contactsStatus');

    if (!mounted) return;
    setState(() {
      _hasCallPermission = phoneStatus.isGranted;
      _hasContactsPermission = contactsStatus.isGranted;
    });
  }

  Future<void> _refreshDefaultDialerStatus() async {
    try {
      debugPrint('🔄 Refreshing default dialer state...');
      final bool? isDefault = await _roleChannel.invokeMethod<bool>(
        'isDefaultDialer',
      );
      debugPrint('📱 Is default dialer: $isDefault');
      if (!mounted) return;
      setState(() {
        _isDefaultDialer = isDefault ?? false;
      });
    } on PlatformException catch (error) {
      debugPrint('❌ Default dialer check failed: $error');
      if (!mounted) return;
      setState(() {
        _isDefaultDialer = false;
      });
    }
  }

  Future<void> _handlePhonePermissionTap() async {
    final PermissionStatus status = await Permission.phone.request();
    debugPrint('Phone permission status (tap): $status');

    if (status.isGranted) {
      await _checkPermissions();
      return;
    }

    if (status.isPermanentlyDenied) {
      _showSnackBar(
        'Phone permission permanently denied. Enable it in Settings.',
      );
      await openAppSettings();
    } else {
      _showSnackBar('Phone permission required to continue.');
    }

    await _checkPermissions();
  }

  Future<void> _handleContactsPermissionTap() async {
    final PermissionStatus status = await Permission.contacts.request();
    debugPrint('Contacts permission status (tap): $status');

    if (status.isGranted) {
      await _checkPermissions();
      return;
    }

    if (status.isPermanentlyDenied) {
      _showSnackBar(
        'Contacts permission permanently denied. Enable it in Settings.',
      );
      await openAppSettings();
    } else {
      _showSnackBar('Contacts permission required to continue.');
    }

    await _checkPermissions();
  }

  // Request permissions through batch toggle
  Future<void> _requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.phone,
      Permission.contacts,
    ].request();

    final PermissionStatus phoneStatus =
        statuses[Permission.phone] ?? PermissionStatus.denied;
    final PermissionStatus contactsStatus =
        statuses[Permission.contacts] ?? PermissionStatus.denied;

    debugPrint('Phone permission status (batch): $phoneStatus');
    debugPrint('Contacts permission status (batch): $contactsStatus');

    if (mounted) {
      setState(() {
        _hasCallPermission = phoneStatus.isGranted;
        _hasContactsPermission = contactsStatus.isGranted;
      });
    }

    if (phoneStatus.isGranted && contactsStatus.isGranted) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    if (phoneStatus.isPermanentlyDenied || contactsStatus.isPermanentlyDenied) {
      _showSnackBar('Permissions permanently denied. Enable them in Settings.');
      await openAppSettings();
    } else {
      _showSnackBar('Permissions required to continue.');
    }

    await _checkPermissions();
  }

  Future<void> _requestSetDefaultDialer() async {
    if (_isRequestingDefaultDialer) return;

    setState(() => _isRequestingDefaultDialer = true);
    try {
      debugPrint('📞 Requesting default dialer role via MethodChannel...');
      final bool? result = await _roleChannel.invokeMethod<bool>(
        'requestDefaultDialer',
      );
      debugPrint('✅ Default dialer request result: $result');
      await Future.delayed(const Duration(seconds: 1));
      await _refreshDefaultDialerStatus();
      if (result != true) {
        _showSnackBar('Please set this app as your default phone app.');
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint('❌ Default dialer request failed: $error');
      debugPrint('$stackTrace');
      _showSnackBar('Error requesting default dialer.');
    } catch (error, stackTrace) {
      debugPrint('❌ Unexpected error requesting default dialer: $error');
      debugPrint('$stackTrace');
      _showSnackBar('Error requesting default dialer.');
    } finally {
      if (mounted) {
        setState(() => _isRequestingDefaultDialer = false);
      }
    }
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
    const bool notificationsEnabled =
        false; // TODO: Wire up notification permission state

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
                                    ).withOpacity(0.5),
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
                                  icon: Icons.notifications,
                                  title: 'Notifications',
                                  subtitle:
                                      'To alert you about missed calls and important updates.',
                                  granted: notificationsEnabled,
                                  isDarkMode: isDarkMode,
                                  lightTileColor: lightTileColor,
                                ),
                                _buildPermissionTile(
                                  icon: Icons.app_registration,
                                  title: 'Set as Default',
                                  subtitle:
                                      'Make this app your primary call manager.',
                                  granted: _isDefaultDialer,
                                  isDarkMode: isDarkMode,
                                  lightTileColor: lightTileColor,
                                  onTap: _requestSetDefaultDialer,
                                  onToggleTap: _requestSetDefaultDialer,
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
                                ).withOpacity(0.45),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: _requestPermissions,
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
                            child: const Text('Grant All Permissions'),
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
        ? Colors.white.withOpacity(0.1)
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
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
