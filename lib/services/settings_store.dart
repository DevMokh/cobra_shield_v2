import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore._();

  static final SettingsStore instance = SettingsStore._();
  static const String _kClip = 'cobra.clipwatch';

  bool _clipWatch = false;
  bool get clipWatch => _clipWatch;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _clipWatch = p.getBool(_kClip) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setClipWatch(bool v) async {
    _clipWatch = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kClip, v);
    } catch (_) {}
  }
}
