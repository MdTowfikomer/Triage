import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_provider_adapter.dart';

class ByokKeyStore {
  final FlutterSecureStorage secureStorage;
  SharedPreferences? _preferences;
  bool _prefsInitialized = false;
  final Map<String, String> _memoryFallback = {};

  ByokKeyStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? preferences,
  }) : secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: false,
                resetOnError: true,
              ),
            ),
       _preferences = preferences,
       _prefsInitialized = preferences != null;

  /// Lazy-load SharedPreferences if not provided at construction
  Future<SharedPreferences> _getPrefs() async {
    if (!_prefsInitialized) {
      _preferences = await SharedPreferences.getInstance();
      _prefsInitialized = true;
    }
    return _preferences!;
  }

  static const String _activeProviderKey = 'byok_active_provider';

  Future<void> saveApiKey(LlmProviderType provider, String key) async {
    final storageKey = 'byok_key_${provider.name}';
    // Persist to secure hardware-backed storage
    await secureStorage.write(key: storageKey, value: key);
    _memoryFallback[storageKey] = key;
  }

  Future<String?> getApiKey(LlmProviderType provider) async {
    final storageKey = 'byok_key_${provider.name}';
    if (_memoryFallback.containsKey(storageKey)) {
      return _memoryFallback[storageKey];
    }
    try {
      final val = await secureStorage.read(key: storageKey);
      if (val != null) {
        _memoryFallback[storageKey] = val;
        return val;
      }
    } catch (_) {}
    return null;
  }

  Future<void> deleteApiKey(LlmProviderType provider) async {
    final storageKey = 'byok_key_${provider.name}';
    _memoryFallback.remove(storageKey);
    try {
      await secureStorage.delete(key: storageKey);
    } catch (_) {}
  }

  Future<void> setActiveProvider(LlmProviderType provider) async {
    _memoryFallback[_activeProviderKey] = provider.name;
    final prefs = await _getPrefs();
    await prefs.setString(_activeProviderKey, provider.name);
  }

  Future<LlmProviderType> getActiveProvider() async {
    final prefs = await _getPrefs();
    final val = _memoryFallback[_activeProviderKey] ?? prefs.getString(_activeProviderKey);
    return LlmProviderType.fromString(val);
  }

  Future<void> setCustomModel(LlmProviderType provider, String model) async {
    final key = 'byok_model_${provider.name}';
    _memoryFallback[key] = model;
    final prefs = await _getPrefs();
    await prefs.setString(key, model);
  }

  Future<String?> getCustomModel(LlmProviderType provider) async {
    final key = 'byok_model_${provider.name}';
    final prefs = await _getPrefs();
    return _memoryFallback[key] ?? prefs.getString(key);
  }

  Future<LlmProviderConfig?> getActiveConfig() async {
    final active = await getActiveProvider();
    final key = await getApiKey(active);
    if (key == null || key.isEmpty) return null;
    final model = await getCustomModel(active);
    return LlmProviderConfig(
      provider: active,
      apiKey: key,
      model: model,
    );
  }
}
