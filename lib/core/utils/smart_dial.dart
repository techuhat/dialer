import '../models/contact.dart';
import 'format_utils.dart';

/// A contact the keypad suggests for the digits typed so far.
class DialMatch {
  const DialMatch({required this.contact, required this.number, this.nameRange, this.numberRange});

  final Contact contact;

  /// What to dial: the number that matched, else the contact's first.
  final String number;

  /// Characters of [Contact.displayName] spelled by the keys, to highlight.
  final ({int start, int end})? nameRange;

  /// Characters of `PhoneUtils.formatPhoneNumber(number)` that matched the digits, to highlight.
  final ({int start, int end})? numberRange;
}

/// Smart dial, as in the stock dialer: finds contacts from keypad digits, either inside a number or
/// spelled with the letters on the keys (2 = ABC … 9 = WXYZ). Build it once per contact list.
class SmartDial {
  SmartDial(Iterable<Contact> contacts)
    : _entries = <_Entry>[
        for (final Contact contact in contacts)
          if (contact.phones.isNotEmpty) _Entry(contact),
      ];

  static const int minDigits = 2;
  static final RegExp _codes = RegExp(r'[*#,;]');
  static final RegExp _nonDigit = RegExp(r'\D');

  final List<_Entry> _entries;

  List<DialMatch> search(String input, {int limit = 8}) {
    if (input.contains(_codes)) return const <DialMatch>[];
    final String digits = input.replaceAll(_nonDigit, '');
    if (digits.length < minDigits) return const <DialMatch>[];
    final List<_Scored> found = <_Scored>[for (final _Entry entry in _entries) ?entry.match(digits)]
      ..sort(_Scored.compare);
    return <DialMatch>[for (final _Scored scored in found.take(limit)) scored.match];
  }

  /// The key a character sits on, or null for anything without one.
  static String? keyFor(String character) {
    final int code = character.toLowerCase().codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) return character;
    if (code < 0x61 || code > 0x7A) return null;
    const String keys = '22233344455566677778889999';
    return keys[code - 0x61];
  }
}

class _Scored {
  const _Scored(this.score, this.match);

  final int score;
  final DialMatch match;

  static int compare(_Scored a, _Scored b) {
    final int byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.match.contact.displayName.toLowerCase().compareTo(b.match.contact.displayName.toLowerCase());
  }
}

/// One word of a name as key digits, with where each digit's letter sits in the name.
class _Word {
  _Word(this.keys, this.positions);

  final String keys;
  final List<int> positions;

  static List<_Word> split(String name) {
    final List<_Word> words = <_Word>[];
    final StringBuffer keys = StringBuffer();
    final List<int> positions = <int>[];
    void close() {
      if (keys.isEmpty) return;
      words.add(_Word(keys.toString(), List<int>.of(positions)));
      keys.clear();
      positions.clear();
    }

    for (int i = 0; i < name.length; i++) {
      final String? key = SmartDial.keyFor(name[i]);
      if (key == null) {
        if (name[i].trim().isEmpty || name[i] == '-') close();
        continue;
      }
      keys.write(key);
      positions.add(i);
    }
    close();
    return words;
  }
}

class _Entry {
  factory _Entry(Contact contact) {
    final List<_Word> words = _Word.split(contact.displayName);
    return _Entry._(contact, words, words.map((_Word word) => word.keys[0]).join(), <String>[
      for (final PhoneNumber phone in contact.phones) phone.number.replaceAll(SmartDial._nonDigit, ''),
    ]);
  }

  _Entry._(this.contact, this._words, this._initials, this._digits);

  final Contact contact;
  final List<_Word> _words;

  /// Key digits of each word's first letter: "Asha Verma" -> "28".
  final String _initials;
  final List<String> _digits;

  /// Best way [digits] fit this contact: a name word they spell scores highest, then the start of a
  /// number (ignoring +91 or 0), then the initials, then anywhere in a number.
  _Scored? match(String digits) {
    _Scored? best;
    void offer(int score, DialMatch match) {
      if (best == null || score > best!.score) best = _Scored(score, match);
    }

    final String firstNumber = contact.phones.first.number;
    for (int i = 0; i < _words.length; i++) {
      final _Word word = _words[i];
      if (!word.keys.startsWith(digits)) continue;
      offer(
        i == 0 ? 6 : 5,
        DialMatch(
          contact: contact,
          number: firstNumber,
          nameRange: (start: word.positions.first, end: word.positions[digits.length - 1] + 1),
        ),
      );
      break;
    }
    if (_initials.length > 1 && _initials.startsWith(digits)) {
      offer(3, DialMatch(contact: contact, number: firstNumber));
    }

    for (int i = 0; i < _digits.length; i++) {
      final int at = _digits[i].indexOf(digits);
      if (at < 0) continue;
      final String number = contact.phones[i].number;
      final bool start = PhoneUtils.matchKey(number).startsWith(digits) || at == 0;
      offer(
        start ? 4 : 2,
        DialMatch(contact: contact, number: number, numberRange: locate(PhoneUtils.formatPhoneNumber(number), digits)),
      );
    }
    return best;
  }

  /// Where [digits] appear in [formatted], skipping the spaces and dashes between them.
  static ({int start, int end})? locate(String formatted, String digits) {
    for (int start = 0; start < formatted.length; start++) {
      int matched = 0;
      int end = start;
      while (end < formatted.length && matched < digits.length) {
        final String character = formatted[end];
        if (character == digits[matched]) {
          matched++;
        } else if (SmartDial._nonDigit.hasMatch(character) && matched > 0) {
          // Separator inside the run.
        } else {
          break;
        }
        end++;
      }
      if (matched == digits.length) return (start: start, end: end);
    }
    return null;
  }
}
