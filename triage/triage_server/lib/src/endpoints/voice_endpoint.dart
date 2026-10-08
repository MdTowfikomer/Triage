import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/action_router_service.dart';
import '../services/inbox_service.dart';

class VoiceEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Expects on-device sanitized text. Does not persist or broadcast the input.
  Future<VoiceActionResult> routeVoice(
    Session session,
    String sanitizedTranscript,
  ) async {
    InboxService.userId(session);
    return ActionRouterService.fromSession(session).route(sanitizedTranscript);
  }
}
