import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/built_library_cache.dart';
import '../models/playback_resume_state.dart';
import '../models/tuning_settings.dart';
import 'settings_repository.dart';

class SettingsStorage implements SettingsRepository {
  static const String _settingsKey = 'app_settings';
  static const String _builtLibraryKey = 'built_library_cache';
  static const String _folderBrowserRecursiveKey = 'folder_browser_recursive';
  static const String _miniPlayerCollapsedKey = 'mini_player_collapsed';
  static const String _playbackResumeStateKey = 'playback_resume_state';
  static const String _tuningSettingsKey = 'tuning_settings';

  final SharedPreferencesAsync _preferences;

  SettingsStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  @override
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
      return const AppSettings.empty();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<BuiltLibraryCache?> loadBuiltLibrary() async {
    final jsonString = await _preferences.getString(_builtLibraryKey);

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

  Future<void> saveBuiltLibrary(BuiltLibraryCache cache) async {
    await _preferences.setString(_builtLibraryKey, jsonEncode(cache.toJson()));
  }

  Future<void> clearBuiltLibrary() async {
    await _preferences.remove(_builtLibraryKey);
  }

  Future<bool> loadFolderBrowserRecursive() async {
    return await _preferences.getBool(_folderBrowserRecursiveKey) ?? true;
  }

  Future<void> saveFolderBrowserRecursive(bool enabled) async {
    await _preferences.setBool(_folderBrowserRecursiveKey, enabled);
  }

  Future<bool> loadMiniPlayerCollapsed() async {
    return await _preferences.getBool(_miniPlayerCollapsedKey) ?? false;
  }

  Future<void> saveMiniPlayerCollapsed(bool collapsed) async {
    await _preferences.setBool(_miniPlayerCollapsedKey, collapsed);
  }

  Future<PlaybackResumeState?> loadPlaybackResumeState() async {
    final jsonString = await _preferences.getString(_playbackResumeStateKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) return null;
      final state = PlaybackResumeState.fromJson(json);
      return state.isValid ? state : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlaybackResumeState(PlaybackResumeState state) async {
    await _preferences.setString(
      _playbackResumeStateKey,
      jsonEncode(state.toJson()),
    );
  }

  Future<void> clearPlaybackResumeState() async {
    await _preferences.remove(_playbackResumeStateKey);
  }

  Future<TuningSettings> loadTuningSettings() async {
    final jsonString = await _preferences.getString(_tuningSettingsKey);
    if (jsonString == null) return TuningSettings.defaults;
    try {
      final json = jsonDecode(jsonString);
      return json is Map<String, dynamic>
          ? TuningSettings.fromJson(json)
          : TuningSettings.defaults;
    } catch (_) {
      return TuningSettings.defaults;
    }
  }

  Future<void> saveTuningSettings(TuningSettings settings) async {
    await _preferences.setString(
      _tuningSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
