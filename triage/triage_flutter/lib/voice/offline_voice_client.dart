import 'dart:async';
import 'package:flutter/services.dart';

class VoiceCapabilities {
  final bool onDeviceRecognitionAvailable;
  final bool offlineTtsAvailable;
  final String selectedVoiceName;
  final String selectedLocale;
  final bool micPermissionGranted;
  final int apiLevel;

  const VoiceCapabilities({
    required this.onDeviceRecognitionAvailable,
    required this.offlineTtsAvailable,
    required this.selectedVoiceName,
    required this.selectedLocale,
    required this.micPermissionGranted,
    required this.apiLevel,
  });

  factory VoiceCapabilities.fromMap(Map<dynamic, dynamic> map) {
    return VoiceCapabilities(
      onDeviceRecognitionAvailable: map['onDeviceRecognitionAvailable'] as bool? ?? false,
      offlineTtsAvailable: map['offlineTtsAvailable'] as bool? ?? false,
      selectedVoiceName: map['selectedVoiceName'] as String? ?? 'unknown',
      selectedLocale: map['selectedLocale'] as String? ?? 'unknown',
      micPermissionGranted: map['micPermissionGranted'] as bool? ?? false,
      apiLevel: (map['apiLevel'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isFullyOfflineCapable => onDeviceRecognitionAvailable && offlineTtsAvailable && micPermissionGranted;
}

class SpeechResult {
  final String status; // 'success', 'permission_required', 'unsupported', 'error'
  final String? transcript;
  final List<String> alternatives;
  final int? sttLatencyMs;
  final String? errorCode;
  final String? errorMessage;

  const SpeechResult({
    required this.status,
    this.transcript,
    this.alternatives = const [],
    this.sttLatencyMs,
    this.errorCode,
    this.errorMessage,
  });

  bool get isSuccess => status == 'success' && transcript != null && transcript!.isNotEmpty;

  factory SpeechResult.fromMap(Map<dynamic, dynamic> map) {
    return SpeechResult(
      status: map['status'] as String? ?? 'error',
      transcript: map['transcript'] as String?,
      alternatives: (map['alternatives'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      sttLatencyMs: (map['sttLatencyMs'] as num?)?.toInt(),
      errorCode: map['code'] as String?,
      errorMessage: map['message'] as String?,
    );
  }
}

class TtsResult {
  final String status; // 'success', 'error'
  final int? ttsLatencyMs;
  final int? startLatencyMs;
  final String? voice;
  final String? errorCode;
  final String? errorMessage;

  const TtsResult({
    required this.status,
    this.ttsLatencyMs,
    this.startLatencyMs,
    this.voice,
    this.errorCode,
    this.errorMessage,
  });

  bool get isSuccess => status == 'success';

  factory TtsResult.fromMap(Map<dynamic, dynamic> map) {
    return TtsResult(
      status: map['status'] as String? ?? 'error',
      ttsLatencyMs: (map['ttsLatencyMs'] as num?)?.toInt(),
      startLatencyMs: (map['startLatencyMs'] as num?)?.toInt(),
      voice: map['voice'] as String?,
      errorCode: map['code'] as String?,
      errorMessage: map['message'] as String?,
    );
  }
}

class OfflineVoiceClient {
  static const MethodChannel _methodChannel = MethodChannel('triage.offline_voice');
  static const EventChannel _eventChannel = EventChannel('triage.offline_voice_events');

  final StreamController<Map<String, dynamic>> _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventStreamController.stream;

  StreamSubscription<dynamic>? _eventSubscription;

  OfflineVoiceClient() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          _eventStreamController.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (dynamic error) {
        _eventStreamController.add({
          'event': 'stream_error',
          'error': error.toString(),
        });
      },
    );
  }

  Future<VoiceCapabilities> checkCapabilities() async {
    try {
      final dynamic result = await _methodChannel.invokeMethod('checkCapabilities');
      if (result is Map) {
        return VoiceCapabilities.fromMap(result);
      }
      return const VoiceCapabilities(
        onDeviceRecognitionAvailable: false,
        offlineTtsAvailable: false,
        selectedVoiceName: 'unknown',
        selectedLocale: 'unknown',
        micPermissionGranted: false,
        apiLevel: 0,
      );
    } catch (e) {
      return VoiceCapabilities(
        onDeviceRecognitionAvailable: false,
        offlineTtsAvailable: false,
        selectedVoiceName: 'error',
        selectedLocale: 'error',
        micPermissionGranted: false,
        apiLevel: 0,
      );
    }
  }

  Future<SpeechResult> startListening() async {
    try {
      final dynamic result = await _methodChannel.invokeMethod('startListening');
      if (result is Map) {
        return SpeechResult.fromMap(result);
      }
      return const SpeechResult(
        status: 'error',
        errorCode: 'INVALID_RESULT_PAYLOAD',
        errorMessage: 'Invalid response from speech recognizer.',
      );
    } on PlatformException catch (e) {
      return SpeechResult(
        status: 'error',
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      return SpeechResult(
        status: 'error',
        errorCode: 'UNEXPECTED_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> stopListening() async {
    try {
      final dynamic result = await _methodChannel.invokeMethod('stopListening');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelListening() async {
    try {
      final dynamic result = await _methodChannel.invokeMethod('cancelListening');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<TtsResult> speakOffline(String text) async {
    try {
      final dynamic result = await _methodChannel.invokeMethod('speakOffline', {'text': text});
      if (result is Map) {
        return TtsResult.fromMap(result);
      }
      return const TtsResult(
        status: 'error',
        errorCode: 'INVALID_RESULT_PAYLOAD',
        errorMessage: 'Invalid response from offline TTS.',
      );
    } on PlatformException catch (e) {
      return TtsResult(
        status: 'error',
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      return TtsResult(
        status: 'error',
        errorCode: 'UNEXPECTED_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> openVoiceInputSettings() async {
    try {
      final dynamic result = await _methodChannel.invokeMethod('openVoiceInputSettings');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openTtsSettings() async {
    try {
      final dynamic result = await _methodChannel.invokeMethod('openTtsSettings');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    cancelListening();
    _eventSubscription?.cancel();
    _eventStreamController.close();
  }
}
