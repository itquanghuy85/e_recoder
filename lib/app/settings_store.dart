import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over SharedPreferences. Everything the user can configure lives here.
class SettingsStore {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async =>
      SettingsStore(await SharedPreferences.getInstance());

  ThemeMode get themeMode {
    switch (_prefs.getString('themeMode')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode m) =>
      _prefs.setString('themeMode', m.name);

  int getInt(String key, int fallback) => _prefs.getInt(key) ?? fallback;
  Future<void> setInt(String key, int v) => _prefs.setInt(key, v);
  bool getBool(String key, bool fallback) => _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool v) => _prefs.setBool(key, v);
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('override in main()'),
);

/// Forced UI language; null follows the system (Vietnamese or English, Vietnamese otherwise).
/// Tests override it so they do not depend on the machine's locale.
final localeProvider = Provider<Locale?>((ref) => null);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(settingsStoreProvider).themeMode;

  Future<void> set(ThemeMode m) async {
    state = m;
    await ref.read(settingsStoreProvider).setThemeMode(m);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
