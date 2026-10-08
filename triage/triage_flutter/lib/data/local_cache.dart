import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/draft.dart';

/// Account-namespaced, device-only storage. Never used as endpoint arguments.
class LocalCache {
  LocalCache(this.preferences, this.owner);
  final SharedPreferences preferences;
  final String owner;
  String get _key => 'triage.v1.$owner';
  Future<void> _put(String key, String value) async {
    if (!await preferences.setString(key, value)) {
      throw StateError('Local storage unavailable');
    }
  }

  String? original(int itemId) => preferences.getString('$_key.raw.$itemId');
  Future<void> putOriginal(int itemId, String raw) =>
      _put('$_key.raw.$itemId', raw);
  Future<void> deleteOriginal(int itemId) async =>
      preferences.remove('$_key.raw.$itemId');
  List<Draft> get drafts {
    try {
      final json =
          jsonDecode(preferences.getString('$_key.drafts') ?? '[]') as List;
      return json
          .map((v) => Draft.fromLocalJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> saveDrafts(List<Draft> drafts) => _put(
    '$_key.drafts',
    jsonEncode(drafts.map((d) => d.toLocalJson()).toList()),
  );
}
