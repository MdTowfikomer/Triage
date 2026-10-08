import 'dart:io';

import 'voice_engine.dart';
import 'voice_factory_stub.dart' as stub;
import 'voice_engine_android.dart' as android;

VoiceEngine createVoiceEngine() => Platform.isAndroid
    ? android.AndroidNeedleVoiceEngine()
    : stub.createVoiceEngine();
