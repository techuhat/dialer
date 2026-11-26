import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umar_dailer/core/services/nav_style_service.dart';

Future<NavStyleService> _loaded() async {
  final NavStyleService service = NavStyleService();
  await Future<void>.delayed(Duration.zero);
  return service;
}

void main() {
  test('defaults to classic tabs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect((await _loaded()).style, NavStyle.classic);
  });

  test('remembers the chosen style across launches', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final NavStyleService service = await _loaded();
    int notified = 0;
    service.addListener(() => notified++);

    await service.setStyle(NavStyle.dial);

    expect(service.style, NavStyle.dial);
    expect(notified, 1);
    expect((await _loaded()).style, NavStyle.dial);
  });

  test('ignores a stored value it does not know', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'nav_style': 'hologram'});
    expect((await _loaded()).style, NavStyle.classic);
  });

  test('a choice made while loading wins and is saved', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'nav_style': 'dial'});
    final NavStyleService service = NavStyleService();
    await service.setStyle(NavStyle.classic);
    await Future<void>.delayed(Duration.zero);

    expect(service.style, NavStyle.classic);
    expect((await _loaded()).style, NavStyle.classic);
  });
}
