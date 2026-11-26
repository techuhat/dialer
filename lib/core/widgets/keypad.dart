import 'package:flutter/material.dart';

import '../utils/keypad_feedback.dart';

class KeypadStyle {
  const KeypadStyle({
    required this.digit,
    required this.letters,
    required this.fill,
    this.border,
    this.size = 72,
    this.rowGap = 14,
  });

  final Color digit;
  final Color letters;
  final Color fill;
  final Color? border;
  final double size;
  final double rowGap;
}

/// The 4×3 phone keypad shared by the dialpad tab and the in-call DTMF pad.
class Keypad extends StatelessWidget {
  const Keypad({required this.style, required this.onKey, this.onAlternate, super.key});

  final KeypadStyle style;
  final ValueChanged<String> onKey;

  /// Long-press value: `+` on 0, pause `,` on * and wait `;` on #. Null disables long-press.
  final ValueChanged<String>? onAlternate;

  static const List<_Key> _keys = <_Key>[
    _Key('1'),
    _Key('2', 'ABC'),
    _Key('3', 'DEF'),
    _Key('4', 'GHI'),
    _Key('5', 'JKL'),
    _Key('6', 'MNO'),
    _Key('7', 'PQRS'),
    _Key('8', 'TUV'),
    _Key('9', 'WXYZ'),
    _Key('*', null, ','),
    _Key('0', '+', '+'),
    _Key('#', null, ';'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int row = 0; row < 4; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 3 ? 0 : style.rowGap),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[for (int col = 0; col < 3; col++) _button(_keys[row * 3 + col])],
            ),
          ),
      ],
    );
  }

  Widget _button(_Key key) {
    final ValueChanged<String>? alternate = onAlternate;
    return _KeypadButton(
      keyData: key,
      style: style,
      onTap: () {
        KeypadFeedback.key();
        onKey(key.digit);
      },
      onLongPress: alternate == null || key.alternate == null
          ? null
          : () {
              KeypadFeedback.alternateKey();
              alternate(key.alternate!);
            },
    );
  }
}

class _Key {
  const _Key(this.digit, [this.letters, this.alternate]);

  final String digit;
  final String? letters;
  final String? alternate;
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.keyData, required this.style, required this.onTap, this.onLongPress});

  final _Key keyData;
  final KeypadStyle style;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color? border = style.border;
    return Semantics(
      button: true,
      label: keyData.digit,
      excludeSemantics: true,
      child: Material(
        color: style.fill,
        shape: CircleBorder(side: border == null ? BorderSide.none : BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox.square(
            dimension: style.size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  keyData.digit,
                  style: TextStyle(fontSize: style.size * 0.38, height: 1.1, fontWeight: FontWeight.w500, color: style.digit),
                ),
                if (keyData.letters != null)
                  Text(
                    keyData.letters!,
                    style: TextStyle(
                      fontSize: style.size * 0.14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: style.letters,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
