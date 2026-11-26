import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/dialer_role_service.dart';
import '../core/services/nav_style_service.dart';
import '../core/services/sim_service.dart';
import '../core/services/theme_service.dart';
import '../core/theme.dart';
import '../core/widgets/app_sheet.dart';
import '../core/widgets/nav_parts.dart';
import '../core/widgets/page_header.dart';

import 'blocked_numbers_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = true;
  bool _isDefaultDialer = false;
  int? _defaultSimSlot;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    SimService.defaultSimNotifier.addListener(_onSimPreferenceChanged);
  }

  @override
  void dispose() {
    SimService.defaultSimNotifier.removeListener(_onSimPreferenceChanged);
    super.dispose();
  }

  void _onSimPreferenceChanged() {
    if (!mounted) return;
    setState(() {
      _defaultSimSlot = SimService.defaultSimNotifier.value;
    });
  }

  Future<void> _loadInitialState() async {
    final bool defaultDialer = await DialerRoleService.isDefaultDialer();
    final int? storedSim = await SimService.getDefaultSimSlot();
    if (!mounted) return;
    setState(() {
      _isDefaultDialer = defaultDialer;
      _defaultSimSlot = storedSim;
      _isLoading = false;
    });
  }

  Future<void> _toggleDefaultDialer(bool value) async {
    if (value) {
      final bool granted = await DialerRoleService.requestDefaultDialer();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to set default dialer right now.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default dialer can only be changed from system settings.')),
        );
      }
    }
    final bool current = await DialerRoleService.isDefaultDialer();
    if (mounted) {
      setState(() => _isDefaultDialer = current);
    }
  }

  Future<void> _onChangeDefaultSim() async {
    final result = await SimService.chooseDefaultSim(
      context,
      currentDefault: _defaultSimSlot,
    );

    if (result == null) return;

    if (result.alwaysAsk) {
      await SimService.clearDefaultSim();
      if (!mounted) return;
      setState(() => _defaultSimSlot = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Will ask for SIM every time')),
      );
      return;
    }

    if (result.simSlot != null) {
      await SimService.setDefaultSimSlot(result.simSlot!);
      if (!mounted) return;
      setState(() => _defaultSimSlot = result.simSlot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Default SIM set to SIM ${result.simSlot! + 1}')),
      );
    }
  }

  String _defaultSimSubtitle() {
    if (_defaultSimSlot == null) return 'Ask every time';
    return 'Currently SIM ${_defaultSimSlot! + 1}';
  }

  void _toggleDarkMode(bool value) {
    context.read<ThemeService>().toggleTheme(value);
  }

  Future<void> _chooseNavStyle() async {
    final NavStyleService navigation = context.read<NavStyleService>();
    final NavStyle? picked = await showAppSheet<NavStyle>(
      context,
      builder: (BuildContext sheetContext) => _NavStylePicker(current: navigation.style),
    );
    if (picked != null) await navigation.setStyle(picked);
  }

  void _showAboutDialog() {
    final isDarkMode = context.read<ThemeService>().isDarkMode;
    final theme = Theme.of(context);
    
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode 
              ? const Color(0xFF0F2236)
              : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Umar Dialer',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Beta Version 1.0.0',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This app is designed to deliver a faster, cleaner, and more efficient calling experience than the stock dialer. The focus is simple: smooth performance, minimal load, and a user interface that works exactly the way a dialer should — quick, responsive, and dependable.',
                  style: TextStyle(
                    color: isDarkMode 
                        ? const Color(0xFFB0BEC5)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Behind every feature is continuous testing and refinement. A big credit goes to Mohammad Taha Sheikh, who has consistently helped by testing every build the moment it's ready. His honest feedback and practical suggestions have helped shape the app into something more stable and more usable with each update.",
                  style: TextStyle(
                    color: isDarkMode 
                        ? const Color(0xFFB0BEC5)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This project is an ongoing effort to build a smarter dialer for everyday use, and the improvements will continue as user needs evolve.',
                  style: TextStyle(
                    color: isDarkMode 
                        ? const Color(0xFFB0BEC5)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.white.withValues(alpha: 0.05)
                        : theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Developed by',
                        style: TextStyle(
                          color: isDarkMode 
                              ? const Color(0xFF90B0CB)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mohammad Umar Wajid Khan',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF42A5F5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const PageHeader(title: 'Settings'),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                        children: [
                          _SettingsSwitchTile(
                            title: 'Set as Default Dialer',
                            subtitle: 'Handle every incoming and outgoing call with Umar Dialer',
                            value: _isDefaultDialer,
                            onChanged: (value) {
                              _toggleDefaultDialer(value);
                            },
                          ),
                          const SizedBox(height: 24),
                          _SettingsActionTile(
                            title: 'Default Call SIM',
                            subtitle: _defaultSimSubtitle(),
                            onTap: _onChangeDefaultSim,
                          ),
                          const SizedBox(height: 24),
                          _SettingsSwitchTile(
                            title: 'Dark Mode',
                            subtitle: 'Easy on the eyes at 2 a.m.',
                            value: context.watch<ThemeService>().isDarkMode,
                            onChanged: _toggleDarkMode,
                          ),
                          const SizedBox(height: 24),
                          _SettingsActionTile(
                            title: 'Navigation style',
                            subtitle: context.watch<NavStyleService>().style.title,
                            onTap: _chooseNavStyle,
                          ),
                          const SizedBox(height: 24),
                          _SettingsActionTile(
                            title: 'Blocked Numbers',
                            subtitle: 'Numbers that will never ring again',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const BlockedNumbersPage()),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          _SettingsActionTile(
                            title: 'About App',
                            subtitle: 'Beta v1.0.0 · Learn more about Umar Dialer',
                            onTap: _showAboutDialog,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode 
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: isDarkMode 
                        ? const Color(0xFF90B0CB)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF42A5F5),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode 
                          ? const Color(0xFF90B0CB)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDarkMode ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavStylePicker extends StatelessWidget {
  const _NavStylePicker({required this.current});

  final NavStyle current;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'Navigation style',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final NavStyle style in NavStyle.values)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              selected: style == current,
              leading: SizedBox.square(
                dimension: 40,
                child: Center(
                  child: style == NavStyle.dial
                      ? const RotaryDialFace(size: 36)
                      : Icon(Icons.call_to_action_outlined, size: 32, color: palette.accent),
                ),
              ),
              title: Text(style.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(style.description),
              trailing: style == current ? Icon(Icons.check_circle, color: palette.accent) : null,
              onTap: () => Navigator.pop(context, style),
            ),
        ],
      ),
    );
  }
}
