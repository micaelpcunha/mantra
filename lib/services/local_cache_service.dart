import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  LocalCacheService._();

  static final LocalCacheService instance = LocalCacheService._();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> writeJson(String key, Object value) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  Future<List<Map<String, dynamic>>> readJsonMapList(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }
}
