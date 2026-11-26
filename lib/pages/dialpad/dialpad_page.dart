import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/call_launcher.dart';
import '../../core/models/contact.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/dial_intent_service.dart';
import '../../core/theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/keypad_feedback.dart';
import '../../core/utils/smart_dial.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/keypad.dart';
import '../../core/widgets/nav_parts.dart';
import '../../core/widgets/page_header.dart';
import '../contact_editor_page.dart';
import 'dial_input.dart';
import 'dialpad_widgets.dart';

class DialpadPage extends StatefulWidget {
  const DialpadPage({super.key});

  @override
  State<DialpadPage> createState() => _DialpadPageState();
}

class _DialpadPageState extends State<DialpadPage> {
  /// Numbers this long that match no contact get the "not in your contacts" note.
  static const int _fullNumber = 7;
  static final RegExp _nonDigit = RegExp(r'\D');

  final DialInputController _input = DialInputController();
  SmartDial _smartDial = SmartDial(ContactsService.getCachedContacts());
  StreamSubscription<List<Contact>>? _contacts;

  @override
  void initState() {
    super.initState();
    _contacts = ContactsService.contactsStream.listen((List<Contact> contacts) {
      if (mounted) setState(() => _smartDial = SmartDial(contacts));
    });
    DialIntentService.pendingNumber.addListener(_applyDialIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyDialIntent());
  }

  @override
  void dispose() {
    _contacts?.cancel();
    DialIntentService.pendingNumber.removeListener(_applyDialIntent);
    _input.dispose();
    super.dispose();
  }

  /// Fills the field from a tel: link or ACTION_DIAL, without calling.
  void _applyDialIntent() {
    final String? pending = DialIntentService.consume();
    if (pending != null && mounted) _input.replaceAll(pending);
  }

  void _type(String value) {
    _input.insert(value);
    if (_input.text == '1985') {
      RotaryDial.spins.value++;
      showToast(context, 'Whoa, 1985. The dial is having flashbacks.');
    }
  }

  void _backspace() {
    if (_input.backspace()) {
      KeypadFeedback.backspace();
    } else {
      KeypadFeedback.rejected();
    }
  }

  void _clear() {
    if (!_input.clearAll()) {
      KeypadFeedback.rejected();
      return;
    }
    KeypadFeedback.clear();
  }

  Future<void> _call() async {
    final String number = _input.text;
    if (number.isEmpty) return;
    // Service codes leave no call screen behind, so clear the field once they ran.
    if (await CallLauncher.dial(context, number) && PhoneUtils.isMmiCode(number) && mounted) _input.clearAll();
  }

  void _pick(DialMatch match) {
    HapticFeedback.selectionClick();
    _input.replaceAll(match.number);
  }

  static Contact? _contactFor(String number) => number.isEmpty ? null : ContactsService.cachedContactFor(number);

  /// What the number is, shown above it: a contact's name, or the kind of number.
  static String? _caption(String number, Contact? contact) {
    if (contact != null) return contact.displayName;
    if (PhoneUtils.isEmergencyNumber(number)) return 'Emergency number';
    if (PhoneUtils.isMmiCode(number)) return 'Service code';
    return null;
  }

  /// Rebuilds [builder] on every edit of the number, and only it.
  Widget _onEdit(Widget Function(String number, Contact? contact) builder) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _input,
    builder: (BuildContext context, TextEditingValue value, _) => builder(value.text, _contactFor(value.text)),
  );

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    final bool landscape = screen.width > screen.height;
    final bool compact = landscape || screen.height < 700;

    final Widget readout = _onEdit((String number, Contact? contact) {
      final bool full = number.replaceAll(_nonDigit, '').length >= _fullNumber;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          NumberReadout(controller: _input, caption: _caption(number, contact), compact: compact),
          SuggestionStrip(
            number: number,
            matches: contact == null ? _smartDial.search(number) : const <DialMatch>[],
            unknown: contact == null && full && !PhoneUtils.isMmiCode(number),
            onPick: _pick,
            compact: compact,
          ),
        ],
      );
    });

    final Widget actions = _onEdit(
      (String number, Contact? contact) => DialActions(
        canSave: contact == null && number.length >= 3 && !PhoneUtils.isMmiCode(number),
        canCall: number.isNotEmpty,
        onSave: () => ContactEditorPage.saveNumber(context, number),
        onCall: _call,
        onBackspace: _backspace,
        onClear: _clear,
        compact: compact,
      ),
    );

    final Widget keypad = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      // scaleDown shrinks the keypad on short screens instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 300,
          child: Keypad(
            style: KeypadStyle(
              digit: palette.text,
              letters: palette.muted,
              fill: palette.card,
              border: palette.border,
              size: 76,
              rowGap: 16,
            ),
            onKey: _type,
            onAlternate: _type,
          ),
        ),
      ),
    );

    // Inside HomePage's Scaffold the bottom padding already covers the navigation and gesture inset.
    final double bottom = MediaQuery.paddingOf(context).bottom + 8;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: landscape
            ? Row(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: bottom),
                      // No title in landscape: the call button must stay above the navigation.
                      child: Column(children: <Widget>[const SizedBox(height: 8), readout, actions]),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottom),
                      child: keypad,
                    ),
                  ),
                ],
              )
            : Column(
                children: <Widget>[
                  const PageHeader(title: 'Keypad'),
                  readout,
                  Expanded(child: keypad),
                  actions,
                  SizedBox(height: bottom),
                ],
              ),
      ),
    );
  }
}
