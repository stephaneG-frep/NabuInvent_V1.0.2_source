import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String kProvider = 'ai_provider';
  static const String kBaseUrl = 'ai_base_url';
  static const String kApiKey = 'ai_api_key';
  static const String kModel = 'ai_model';
  static const String kThemeMode = 'theme_mode';
  static const String kAccentIndex = 'accent_index';
  static const String kOnboarded = 'onboarded';
  static const String kInventorName = 'inventor_name';
  static const String kLastSparkDate = 'last_spark_date';
  static const String kSparkCount = 'spark_count_today';

  final String aiProvider;
  final String aiBaseUrl;
  final String apiKey;
  final String aiModel;
  final ThemeMode themeMode;
  final int accentIndex;
  final bool onboarded;
  final String inventorName;
  final String lastSparkDate;
  final int sparkCountToday;

  const AppSettings({
    this.aiProvider = 'local',
    this.aiBaseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.aiModel = 'gpt-4o-mini',
    this.themeMode = ThemeMode.system,
    this.accentIndex = 0,
    this.onboarded = false,
    this.inventorName = 'Nabu',
    this.lastSparkDate = '',
    this.sparkCountToday = 0,
  });

  bool get useCloud => aiProvider == 'openai';

  int sparksUsedToday(String today) =>
      lastSparkDate == today ? sparkCountToday : 0;

  AppSettings copyWith({
    String? aiProvider,
    String? aiBaseUrl,
    String? apiKey,
    String? aiModel,
    ThemeMode? themeMode,
    int? accentIndex,
    bool? onboarded,
    String? inventorName,
    String? lastSparkDate,
    int? sparkCountToday,
  }) =>
      AppSettings(
        aiProvider: aiProvider ?? this.aiProvider,
        aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
        apiKey: apiKey ?? this.apiKey,
        aiModel: aiModel ?? this.aiModel,
        themeMode: themeMode ?? this.themeMode,
        accentIndex: accentIndex ?? this.accentIndex,
        onboarded: onboarded ?? this.onboarded,
        inventorName: inventorName ?? this.inventorName,
        lastSparkDate: lastSparkDate ?? this.lastSparkDate,
        sparkCountToday: sparkCountToday ?? this.sparkCountToday,
      );
}

class SettingsService {
  // La clé API va dans le stockage chiffré du système (Keystore Android),
  // jamais dans SharedPreferences qui est un fichier XML en clair.
  static const _secure = FlutterSecureStorage();

  // Les réglages sont enregistrés à chaque frappe : la file garantit que les
  // écritures ne s'entremêlent pas et que la dernière valeur gagne.
  Future<void> _queue = Future.value();

  Future<String> _loadApiKey(SharedPreferences prefs) async {
    final legacy = prefs.getString(AppSettings.kApiKey);
    if (legacy != null) {
      // Migration des versions ≤ 1.0.2 : clé stockée en clair.
      if (legacy.isNotEmpty) {
        await _secure.write(key: AppSettings.kApiKey, value: legacy);
      }
      await prefs.remove(AppSettings.kApiKey);
      return legacy;
    }
    return await _secure.read(key: AppSettings.kApiKey) ?? '';
  }

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey;
    try {
      apiKey = await _loadApiKey(prefs);
    } catch (_) {
      apiKey = prefs.getString(AppSettings.kApiKey) ?? '';
    }
    return AppSettings(
      aiProvider: prefs.getString(AppSettings.kProvider) ?? 'local',
      aiBaseUrl:
          prefs.getString(AppSettings.kBaseUrl) ?? 'https://api.openai.com/v1',
      apiKey: apiKey,
      aiModel: prefs.getString(AppSettings.kModel) ?? 'gpt-4o-mini',
      themeMode: _themeFromName(prefs.getString(AppSettings.kThemeMode)),
      accentIndex: prefs.getInt(AppSettings.kAccentIndex) ?? 0,
      onboarded: prefs.getBool(AppSettings.kOnboarded) ?? false,
      inventorName: prefs.getString(AppSettings.kInventorName) ?? 'Nabu',
      lastSparkDate: prefs.getString(AppSettings.kLastSparkDate) ?? '',
      sparkCountToday: prefs.getInt(AppSettings.kSparkCount) ?? 0,
    );
  }

  Future<void> save(AppSettings settings) {
    final next = _queue.then((_) => _write(settings));
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _write(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppSettings.kProvider, settings.aiProvider);
    await prefs.setString(AppSettings.kBaseUrl, settings.aiBaseUrl);
    if (settings.apiKey.isEmpty) {
      await _secure.delete(key: AppSettings.kApiKey);
    } else {
      await _secure.write(key: AppSettings.kApiKey, value: settings.apiKey);
    }
    await prefs.setString(AppSettings.kModel, settings.aiModel);
    await prefs.setString(
        AppSettings.kThemeMode, settings.themeMode.name);
    await prefs.setInt(AppSettings.kAccentIndex, settings.accentIndex);
    await prefs.setBool(AppSettings.kOnboarded, settings.onboarded);
    await prefs.setString(AppSettings.kInventorName, settings.inventorName);
    await prefs.setString(AppSettings.kLastSparkDate, settings.lastSparkDate);
    await prefs.setInt(AppSettings.kSparkCount, settings.sparkCountToday);
  }

  ThemeMode _themeFromName(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}