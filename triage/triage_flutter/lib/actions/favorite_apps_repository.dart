import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteApp {
  const FavoriteApp({
    required this.name,
    required this.packageName,
    this.aliases = const [],
  });

  final String name;
  final String packageName;
  final List<String> aliases;

  Map<String, Object?> toJson() => {
    'name': name,
    'packageName': packageName,
    'aliases': aliases,
  };

  factory FavoriteApp.fromJson(Map<String, dynamic> json) => FavoriteApp(
    name: json['name'] as String? ?? '',
    packageName: json['packageName'] as String? ?? '',
    aliases: (json['aliases'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

class FavoriteAppsRepository {
  FavoriteAppsRepository(this.preferences);

  static const _key = 'favorite_apps_v1';
  final SharedPreferences preferences;

  List<FavoriteApp> getAll() {
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    try {
      final stored = (jsonDecode(raw) as List<dynamic>)
          .map((item) => FavoriteApp.fromJson(item as Map<String, dynamic>))
          .toList();
      return stored;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAll(List<FavoriteApp> apps) async {
    final encoded = jsonEncode(apps.map((e) => e.toJson()).toList());
    await preferences.setString(_key, encoded);
  }

  Future<void> addOrUpdate(FavoriteApp app) async {
    final current = getAll().toList();
    final index = current.indexWhere((a) => a.packageName == app.packageName);
    if (index >= 0) {
      current[index] = app;
    } else {
      current.add(app);
    }
    await saveAll(current);
  }

  Future<void> remove(String packageName) async {
    final current = getAll().where((a) => a.packageName != packageName).toList();
    await saveAll(current);
  }

  /// Resolve a spoken app query (e.g. "insta", "music", "notes")
  FavoriteApp? resolve(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final apps = getAll();
    // 1. Exact match on name or package
    for (final app in apps) {
      if (app.name.toLowerCase() == normalized || app.packageName.toLowerCase() == normalized) {
        return app;
      }
      for (final alias in app.aliases) {
        if (alias.toLowerCase() == normalized) {
          return app;
        }
      }
    }

    // 2. Contains match
    for (final app in apps) {
      if (app.name.toLowerCase().contains(normalized) || normalized.contains(app.name.toLowerCase())) {
        return app;
      }
    }

    return null;
  }
}
