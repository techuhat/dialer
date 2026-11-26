import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages a user-selected background wallpaper for the app.
///
/// Persists the chosen image to the app‐specific directory and exposes
/// reactive state via [ChangeNotifier].
class WallpaperService extends ChangeNotifier {
  static const String _activeKey = 'wallpaper_active';
  static const String _opacityKey = 'wallpaper_opacity';
  static const String _fileName = 'user_wallpaper.jpg';

  bool _isActive = false;
  double _opacity = 0.35;
  File? _wallpaperFile;

  bool get isActive => _isActive;
  double get opacity => _opacity;
  File? get wallpaperFile => _wallpaperFile;

  WallpaperService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isActive = prefs.getBool(_activeKey) ?? false;
      _opacity = prefs.getDouble(_opacityKey) ?? 0.35;

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (file.existsSync()) {
        _wallpaperFile = file;
      } else {
        // File gone – reset active flag.
        _isActive = false;
      }
      notifyListeners();
    } catch (_) {
      // Silently fail on startup – wallpaper is non-critical.
    }
  }

  /// Let the user pick an image from gallery and persist it.
  Future<bool> pickWallpaper() async {
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return false;

      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/$_fileName');
      await File(picked.path).copy(dest.path);

      _wallpaperFile = dest;
      _isActive = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_activeKey, true);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle wallpaper on/off without removing the file.
  void setActive(bool active) async {
    if (active && _wallpaperFile == null) return;
    _isActive = active;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, active);
  }

  /// Adjust the dark overlay opacity (0.0 – 0.8).
  void setOpacity(double value) async {
    _opacity = value.clamp(0.0, 0.8);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_opacityKey, _opacity);
  }

  /// Remove the saved wallpaper completely.
  Future<void> removeWallpaper() async {
    if (_wallpaperFile != null && _wallpaperFile!.existsSync()) {
      await _wallpaperFile!.delete();
    }
    _wallpaperFile = null;
    _isActive = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, false);
  }
}
