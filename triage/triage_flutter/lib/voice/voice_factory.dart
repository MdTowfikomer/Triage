import 'voice_engine.dart';
import 'voice_factory_stub.dart'
    if (dart.library.io) 'voice_factory_io.dart'
    if (dart.library.js_interop) 'voice_factory_web.dart'
    as voice_platform;

VoiceEngine createVoiceEngine() => voice_platform.createVoiceEngine();
