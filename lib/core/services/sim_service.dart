import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../call_service.dart';
import '../utils/format_utils.dart';

class SimSelectionResult {
  final int? simSlot;
  final bool remember;
  final bool alwaysAsk;

  const SimSelectionResult({
    this.simSlot,
    this.remember = false,
    this.alwaysAsk = false,
  });
}

class SimService {
  static const String _defaultSimKey = 'default_sim_slot';
  static SharedPreferences? _prefs;
  static final ValueNotifier<int?> defaultSimNotifier = ValueNotifier<int?>(null);

  static Future<SharedPreferences> _prefsInstance() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (defaultSimNotifier.value == null) {
      defaultSimNotifier.value = _prefs!.getInt(_defaultSimKey);
    }
    return _prefs!;
  }

  static Future<int?> getDefaultSimSlot() async {
    final prefs = await _prefsInstance();
    return prefs.getInt(_defaultSimKey);
  }

  static Future<void> setDefaultSimSlot(int simSlot) async {
    final prefs = await _prefsInstance();
    await prefs.setInt(_defaultSimKey, simSlot);
    defaultSimNotifier.value = simSlot;
  }

  static Future<void> clearDefaultSim() async {
    final prefs = await _prefsInstance();
    await prefs.remove(_defaultSimKey);
    defaultSimNotifier.value = null;
  }

  /// Resolve which SIM to use for a call.
  /// Returns the stored default if present, otherwise shows a picker with an optional "remember" toggle.
  static Future<int?> pickSimForCall(
    BuildContext context, {
    required String number,
  }) async {
    // Never put a dialog in front of an emergency call.
    if (PhoneUtils.isEmergencyNumber(number)) {
      return 0;
    }

    final int? simCount = await CallService.getActiveSimCount();
    // Unknown count: assume single SIM and let Telecom pick, rather than asking on every call.
    if (simCount == null || simCount <= 1) {
      return 0;
    }

    final stored = await getDefaultSimSlot();
    if (stored != null) return stored;
    if (!context.mounted) return null;

    final SimSelectionResult? result = await _showSimSelectionDialog(
      context,
      title: 'Select SIM for Call',
      subtitle: PhoneUtils.formatPhoneNumber(number),
      showRemember: true,
      allowAlwaysAsk: false,
    );

    if (result == null || result.simSlot == null) return null;

    if (result.remember) {
      await setDefaultSimSlot(result.simSlot!);
    }
    return result.simSlot;
  }

  /// Opens the SIM preference dialog from settings.
  /// Returns a result indicating the chosen SIM or whether the user wants to always be asked.
  static Future<SimSelectionResult?> chooseDefaultSim(
    BuildContext context, {
    int? currentDefault,
  }) {
    return _showSimSelectionDialog(
      context,
      title: 'Default SIM for calls',
      subtitle: 'Apply to outgoing calls. Choose "Always ask" to reset.',
      showRemember: false,
      allowAlwaysAsk: true,
      currentDefault: currentDefault,
    );
  }

  static Future<SimSelectionResult?> _showSimSelectionDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool showRemember,
    required bool allowAlwaysAsk,
    int? currentDefault,
  }) async {
    bool rememberChoice = false;

    return showDialog<SimSelectionResult>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final isDarkMode = theme.brightness == Brightness.dark;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: isDarkMode ? const Color(0xFF0F2236) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.sim_card,
                            color: Color(0xFF42A5F5),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? const Color(0xFF90B0CB)
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSimOption(
                      context,
                      simSlot: 0,
                      label: 'SIM 1',
                      color: const Color(0xFF42A5F5),
                      isDarkMode: isDarkMode,
                      rememberChoice: rememberChoice,
                      onSelected: (slot) => Navigator.of(context).pop(
                        SimSelectionResult(simSlot: slot, remember: rememberChoice),
                      ),
                      isSelected: currentDefault == 0,
                    ),
                    const SizedBox(height: 12),
                    _buildSimOption(
                      context,
                      simSlot: 1,
                      label: 'SIM 2',
                      color: const Color(0xFF66BB6A),
                      isDarkMode: isDarkMode,
                      rememberChoice: rememberChoice,
                      onSelected: (slot) => Navigator.of(context).pop(
                        SimSelectionResult(simSlot: slot, remember: rememberChoice),
                      ),
                      isSelected: currentDefault == 1,
                    ),
                    if (allowAlwaysAsk) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.shuffle, size: 18),
                          label: const Text('Always ask'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : const Color(0xFF42A5F5).withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(
                            const SimSelectionResult(alwaysAsk: true),
                          ),
                        ),
                      ),
                    ],
                    if (showRemember) ...[
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: () {
                          setState(() {
                            rememberChoice = !rememberChoice;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: rememberChoice,
                                  onChanged: (value) {
                                    setState(() {
                                      rememberChoice = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF42A5F5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Remember this SIM for future calls',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSimOption(
    BuildContext context, {
    required int simSlot,
    required String label,
    required Color color,
    required bool isDarkMode,
    required bool rememberChoice,
    required void Function(int simSlot) onSelected,
    bool isSelected = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(simSlot),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sim_card,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (rememberChoice)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Will remember if checked',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.65)
                                : Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
