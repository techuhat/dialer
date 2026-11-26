import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/call_launcher.dart';
import '../core/services/dial_intent_service.dart';
import '../core/services/theme_service.dart';
import '../core/utils/format_utils.dart';
import '../core/utils/keypad_feedback.dart';
import '../core/widgets/dialer_nav_bar.dart';
import '../core/widgets/keypad.dart';
import '../core/widgets/page_header.dart';
import 'contact_editor_page.dart';

class DialpadPage extends StatefulWidget {
  const DialpadPage({super.key});

  @override
  State<DialpadPage> createState() => _DialpadPageState();
}

class _DialpadPageState extends State<DialpadPage> {
  late TextEditingController _controller;

  String _input = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _input);
    DialIntentService.pendingNumber.addListener(_applyPendingDialIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingDialIntent());
  }

  @override
  void dispose() {
    DialIntentService.pendingNumber.removeListener(_applyPendingDialIntent);
    _controller.dispose();
    super.dispose();
  }

  /// Fills the field from an inbound ACTION_DIAL intent, without calling.
  void _applyPendingDialIntent() {
    final String? pending = DialIntentService.consume();
    if (pending == null || !mounted) {
      return;
    }
    _controller.value = TextEditingValue(
      text: pending,
      selection: TextSelection.collapsed(offset: pending.length),
    );
    setState(() {
      _input = pending;
    });
  }

  void _appendValue(String value) {
    final text = _controller.text;
    final textSelection = _controller.selection;
    final newText = text.replaceRange(
      textSelection.start >= 0 ? textSelection.start : text.length,
      textSelection.end >= 0 ? textSelection.end : text.length,
      value,
    );
    final newSelectionIndex =
        (textSelection.start >= 0 ? textSelection.start : text.length) + value.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
    setState(() {
      _input = newText;
    });
  }

  void _onBackspace() {
    KeypadFeedback.backspace();
    final text = _controller.text;
    final textSelection = _controller.selection;
    final selectionLength = textSelection.end - textSelection.start;

    if (selectionLength > 0) {
      final newText = text.replaceRange(textSelection.start, textSelection.end, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: textSelection.start),
      );
      setState(() {
        _input = newText;
      });
      return;
    }

    if (textSelection.start == 0 && textSelection.end == 0) {
      return;
    }

    final offset = textSelection.start >= 0 ? textSelection.start : text.length;
    if (offset > 0) {
      final newText = text.replaceRange(offset - 1, offset, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset - 1),
      );
      setState(() {
        _input = newText;
      });
    }
  }

  void _clearAll() {
    if (_controller.text.isEmpty) {
      KeypadFeedback.rejected();
      return;
    }
    _controller.clear();
    _controller.selection = const TextSelection.collapsed(offset: 0);
    setState(() {
      _input = '';
    });
    KeypadFeedback.clear();
  }

  Future<void> _onCallPressed() async {
    final String dialString = _input;
    if (dialString.isEmpty) return;
    // Service codes leave no call screen behind, so clear the field once they ran.
    if (await CallLauncher.dial(context, dialString) && PhoneUtils.isMmiCode(dialString) && mounted) _clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PageHeader(title: 'Keypad', subtitle: 'Long-press 0 for +, * for a pause'),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.06)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                        boxShadow: isDarkMode
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _controller,
                                  keyboardType: TextInputType.none,
                                  showCursor: true,
                                  autofocus: true,
                                  enableInteractiveSelection: true,
                                  style:
                                      textTheme.headlineMedium?.copyWith(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ) ??
                                      TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter number',
                                    hintStyle: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : Colors.black.withValues(alpha: 0.5),
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _input = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _input.isEmpty
                                      ? 'Tap numbers to begin a call'
                                      : 'Ready to connect',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode
                                        ? const Color(0xFF90B0CB)
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _onBackspace,
                            onLongPress: _clearAll,
                            splashRadius: 24,
                            icon: Icon(
                              Icons.backspace_outlined,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_input.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ContactEditorPage(initialNumber: _input),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add to Contact'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  // scaleDown shrinks the keypad on short screens instead of overflowing.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 300,
                      child: Keypad(
                        style: KeypadStyle(
                          digit: isDarkMode ? Colors.white : colors.onSurface,
                          letters: isDarkMode ? const Color(0xFF90B0CB) : colors.onSurface.withValues(alpha: 0.6),
                          fill: isDarkMode ? Colors.white.withValues(alpha: 0.08) : colors.surface,
                          border: isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : colors.primary.withValues(alpha: 0.15),
                          size: 76,
                          rowGap: 18,
                        ),
                        onKey: _appendValue,
                        onAlternate: _appendValue,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, DialerNavBar.clearance(context) + 8),
                child: FilledButton.icon(
                  onPressed: _input.isEmpty ? null : _onCallPressed,
                  icon: const Icon(Icons.call, size: 22),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  label: const Text('Call'),
                ),
              ),
            ],
          ),
      ),
    );
  }
}
