import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/built_library_cache.dart';
import 'settings_repository.dart';

class SettingsStorage implements SettingsRepository {
  static const String _settingsKey = 'app_settings';
  static const String _builtLibraryKey = 'built_library_cache';
  static const String _folderBrowserRecursiveKey =
      'folder_browser_recursive';

  final SharedPreferencesAsync _preferences;

  SettingsStorage({
    SharedPreferencesAsync? preferences,
  }) : _preferences =
      preferences ?? SharedPreferencesAsync();

  @override
  Future<AppSettings> load() async {
    final jsonString = await _preferences.getString(
      _settingsKey,
    );

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
      return const AppSettings.empty();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setString(
      _settingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<BuiltLibraryCache?> loadBuiltLibrary() async {
    final jsonString = await _preferences.getString(
      _builtLibraryKey,
    );

    if (jsonString == null) {
      return null;
    }

    try {
      final json = jsonDecode(jsonString);

      if (json is! Map<String, dynamic>) {
        return null;
      }

      if (json['version'] != 1) {
        return null;
      }

      return BuiltLibraryCache.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBuiltLibrary(
      BuiltLibraryCache cache,
      ) async {
    await _preferences.setString(
      _builtLibraryKey,
      jsonEncode(cache.toJson()),
    );
  }

  Future<void> clearBuiltLibrary() async {
    await _preferences.remove(_builtLibraryKey);
  }

  Future<bool> loadFolderBrowserRecursive() async {
    return await _preferences.getBool(
      _folderBrowserRecursiveKey,
    ) ??
        true;
  }

  Future<void> saveFolderBrowserRecursive(bool enabled) async {
    await _preferences.setBool(
      _folderBrowserRecursiveKey,
      enabled,
    );
  }
}