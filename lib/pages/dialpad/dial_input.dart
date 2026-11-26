import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/format_utils.dart';

/// The number on the keypad. Edits at the cursor like the stock dialer and draws the number in
/// readable groups without changing the text, so the cursor and paste keep working.
class DialInputController extends TextEditingController {
  static final RegExp _undialable = RegExp(r'[^0-9+*#,;]');

  /// Only what a phone can dial: digits, + * # and the pause (,) and wait (;) marks.
  static String sanitize(String value) => value.replaceAll(_undialable, '');

  /// The same filter for text pasted into the field.
  static final TextInputFormatter formatter = FilteringTextInputFormatter.deny(_undialable);

  void insert(String value) {
    final TextSelection range = selection;
    final int start = range.isValid ? range.start : text.length;
    final int end = range.isValid ? range.end : text.length;
    this.value = TextEditingValue(
      text: text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  /// Removes the selection or the character before the cursor; false when nothing was removed.
  bool backspace() {
    final TextSelection range = selection;
    final int end = range.isValid ? range.end : text.length;
    final int start = range.isValid && !range.isCollapsed ? range.start : end - 1;
    if (start < 0) return false;
    value = TextEditingValue(
      text: text.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
    return true;
  }

  /// Empties the field; false when it already was.
  bool clearAll() {
    if (text.isEmpty) return false;
    value = TextEditingValue.empty;
    return true;
  }

  /// Puts a whole number in, e.g. from a tel: link or a suggestion, with the cursor at the end.
  void replaceAll(String number) {
    final String clean = sanitize(number);
    value = TextEditingValue(
      text: clean,
      selection: TextSelection.collapsed(offset: clean.length),
    );
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<int> breaks = PhoneUtils.groupBreaks(text);
    if (breaks.isEmpty) return TextSpan(style: style, text: text);
    // Extra spacing after the last character of each group draws the gap.
    final TextStyle gap = TextStyle(letterSpacing: (style?.letterSpacing ?? 0) + (style?.fontSize ?? 32) * 0.3);
    final List<TextSpan> spans = <TextSpan>[];
    int start = 0;
    for (final int index in breaks) {
      if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(TextSpan(text: text[index], style: gap));
      start = index + 1;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(style: style, children: spans);
  }
}
