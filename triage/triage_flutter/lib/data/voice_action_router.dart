import 'package:triage_client/triage_client.dart';

const _rpcTimeoutMs = int.fromEnvironment(
  'VOICE_RPC_TIMEOUT_MS',
  defaultValue: 800,
);
Duration get voiceRpcTimeout =>
    Duration(milliseconds: _rpcTimeoutMs.clamp(100, 10000));

abstract interface class VoiceActionRouter {
  Future<VoiceActionResult> route(String sanitizedTranscript);
}

class ServerVoiceActionRouter implements VoiceActionRouter {
  const ServerVoiceActionRouter(this.client);
  final Client client;
  @override
  Future<VoiceActionResult> route(String sanitizedTranscript) =>
      client.voice.routeVoice(sanitizedTranscript).timeout(voiceRpcTimeout);
}
