import 'package:shared_preferences/shared_preferences.dart';

/// Локальное хранилище: рекорд и настройки.
///
/// Данные не покидают устройство — приложению не нужен интернет и не нужно
/// разрешение на сеть. Любая ошибка хранилища не должна ломать игру.
class GameStore {
  GameStore._();

  static const String _keyBest = 'best_score';
  static const String _keySound = 'sound_on';
  static const String _keyVibro = 'vibro_on';

  static Future<int> loadBest() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyBest) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> saveBest(int value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyBest, value);
    } catch (_) {
      // Некритично: рекорд просто не сохранится.
    }
  }

  static Future<bool> loadSound() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySound) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> loadVibro() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyVibro) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveSound(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySound, value);
    } catch (_) {
      // Некритично.
    }
  }

  static Future<void> saveVibro(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVibro, value);
    } catch (_) {
      // Некритично.
    }
  }
}
