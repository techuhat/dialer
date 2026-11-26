import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/models/contact.dart';
import 'package:umar_dailer/core/utils/smart_dial.dart';

Contact _contact(String id, String name, List<String> numbers) => Contact(
  id: id,
  name: name,
  phones: <PhoneNumber>[for (final String number in numbers) PhoneNumber(number: number, label: 'Mobile')],
);

void main() {
  final SmartDial dial = SmartDial(<Contact>[
    _contact('1', 'Asha Verma', <String>['+91 98765 43210']),
    _contact('2', 'Ravi Kumar', <String>['9123456780']),
    _contact('3', 'Mom', <String>['9988776655']),
    _contact('4', 'Bhavna Ashok', <String>['8000012345']),
    _contact('5', 'No Number', <String>[]),
  ]);

  List<String> names(String input) => <String>[for (final DialMatch match in dial.search(input)) match.contact.name];

  test('spells names with the letters on the keys', () {
    final DialMatch match = dial.search('2742').single;
    expect(match.contact.name, 'Asha Verma');
    expect(match.nameRange, (start: 0, end: 4));
  });

  test('a later word matches too, after a first-word match', () {
    expect(names('274'), <String>['Asha Verma', 'Bhavna Ashok']);
    expect(dial.search('274')[1].nameRange, (start: 7, end: 10));
  });

  test('finds digits in a number, ignoring +91, and marks them in the formatted number', () {
    final DialMatch match = dial.search('98765').single;
    expect(match.contact.name, 'Asha Verma');
    expect(match.number, '+91 98765 43210');
    expect(match.numberRange, (start: 4, end: 9));
  });

  test('initials work, and contacts without a number are never suggested', () {
    expect(names('28'), <String>['Asha Verma']);
    expect(names('66'), <String>['Mom']);
  });

  test('codes, pauses and single digits suggest nothing', () {
    expect(dial.search('*#06#'), isEmpty);
    expect(dial.search('98,1'), isEmpty);
    expect(dial.search('9'), isEmpty);
  });
}
