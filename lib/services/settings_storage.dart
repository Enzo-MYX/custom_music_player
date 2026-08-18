import 'dart:convert';
import 'package:custom_music_player/services/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsStorage implements SettingsRepository {
  static const String _settingsKey = 'app_settings';
  final SharedPreferencesAsync _preferences;

  SettingsStorage({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  Future<AppSettings> load() async {
    final jsonString = await _preferences.getString(_settingsKey);
    if (jsonString == null) {
      return const AppSettings.empty();
    }
    try {
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        return const AppSettings.empty();
      }
      return AppSettings.fromJson(json);
    } catch (_) {
      // If the stored configuration is corrupt, start with an empty configuration.
      return const AppSettings.empty();
    }
  }

  Future<void> save(AppSettings settings) async {
    final jsonString = jsonEncode(settings.toJson());

    await _preferences.setString(
      _settingsKey,
      jsonString,
    );
  }
}