import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'pcm16_buffer.dart';
import 'voice_engine.dart';

class AndroidNeedleVoiceEngine implements VoiceEngine {
  static const _channel = MethodChannel('triage.needle');
  static const _recordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 16,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
  );

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSubscription;
  Pcm16Buffer _audio = Pcm16Buffer();
  bool _initialized = false;
  bool _recording = false;
  bool _microphoneGranted = false;

  Future<Map<String, dynamic>> _dispatch(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    final raw = await _channel.invokeMethod<String>('dispatch', {
      'message': jsonEncode({
        'requestId': DateTime.now().microsecondsSinceEpoch.toString(),
        'action': action,
        ...payload,
      }),
    });
    return Map<String, dynamic>.from(jsonDecode(raw ?? '{}') as Map);
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _channel.invokeMethod<void>('initialize');
    await _dispatch('init');
    _initialized = true;
  }

  @override
  Future<void> requestPermission() async {
    final status = await Permission.microphone.request();
    _microphoneGranted = status.isGranted;
    if (!_microphoneGranted) {
      throw StateError('Microphone permission was not granted.');
    }
  }

  @override
  Future<void> start() async {
    if (!_microphoneGranted || !await _recorder.hasPermission(request: false)) {
      throw StateError('Microphone permission was not granted.');
    }
    _audio = Pcm16Buffer();
    final stream = await _recorder.startStream(_recordConfig);
    _audioSubscription = stream.listen(
      _audio.add,
      onError: (Object error) {},
      cancelOnError: true,
    );
    _recording = true;
  }

  @override
  Future<Map<String, dynamic>> stop() async {
    if (!_recording) throw StateError('Microphone is not recording.');
    _recording = false;
    await _recorder.stop();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    if (_audio.isEmpty) throw StateError('No microphone audio was captured.');
    final bytes = _audio.takeBytes();
    return _dispatch('audio', {'pcm16Base64': base64Encode(bytes)});
  }

  @override
  Future<Map<String, dynamic>> route(String text) =>
      _dispatch('text', {'text': text});

  @override
  Future<List<double>> levels() async {
    if (!_recording) return List<double>.filled(12, 0);
    final amplitude = await _recorder.getAmplitude();
    final energy = math.pow(10, amplitude.current / 20).toDouble().clamp(0, 1);
    return List<double>.generate(
      12,
      (index) => energy * (.65 + .35 * math.sin((index + 1) * math.pi / 13)),
    );
  }

  @override
  Future<void> cancel() async {
    if (_recording) {
      _recording = false;
      await _recorder.cancel();
    }
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _audio = Pcm16Buffer();
  }
}
