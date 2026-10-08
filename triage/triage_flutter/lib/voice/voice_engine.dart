import 'dart:convert';
import 'bridge_stub.dart'
    if (dart.library.js_interop) 'bridge_web.dart'
    as bridge;

abstract class VoiceEngine {
  Future<void> initialize();
  Future<void> requestPermission() async {}
  Future<void> start();
  Future<Map<String, dynamic>> stop();
  Future<Map<String, dynamic>> route(String text);
  Future<List<double>> levels();
  Future<void> cancel();
}

class NeedleVoiceEngine implements VoiceEngine {
  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async => Map<String, dynamic>.from(
    jsonDecode(await bridge.invoke(jsonEncode({'action': action, ...payload})))
        as Map,
  );
  @override
  Future<void> initialize() async {
    await _call('init');
  }

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> start() async {
    await _call('start');
  }

  @override
  Future<Map<String, dynamic>> stop() => _call('stop');
  @override
  Future<Map<String, dynamic>> route(String text) =>
      _call('text', {'text': text});
  @override
  Future<List<double>> levels() async =>
      ((await _call('levels'))['levels'] as List)
          .map((n) => (n as num).toDouble())
          .toList();
  @override
  Future<void> cancel() async {
    await _call('cancel');
  }
}
