import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NavStyle {
  classic('Classic tabs', 'Five tabs at the bottom. Reliable, like a landline.'),
  dial('Dial menu', 'Just the dial. Tap it to pick a page, or hold and slide. Very 1985.');

  const NavStyle(this.title, this.description);

  final String title;
  final String description;
}

/// Which bottom navigation the home screen uses, kept across launches.
class NavStyleService extends ChangeNotifier {
  NavStyleService() {
    _load();
  }

  static const String _key = 'nav_style';

  NavStyle _style = NavStyle.classic;
  bool _chosen = false;

  NavStyle get style => _style;

  Future<void> _load() async {
    final String? stored = (await SharedPreferences.getInstance()).getString(_key);
    final NavStyle? style = NavStyle.values.asNameMap()[stored];
    // A choice made while loading wins over the stored one.
    if (_chosen || style == null || style == _style) return;
    _style = style;
    notifyListeners();
  }

  Future<void> setStyle(NavStyle style) async {
    _chosen = true;
    if (style != _style) {
      _style = style;
      notifyListeners();
    }
    await (await SharedPreferences.getInstance()).setString(_key, style.name);
  }
}
