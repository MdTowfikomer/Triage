import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/inbox_service.dart';

class SyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Stream<InboxEvent> streamInbox(Session session) {
    // Channel selection is exclusively server-side. No client userId/channel.
    final owner = InboxService.userId(session);
    return session.messages.createStream<InboxEvent>(
      InboxService.channel(owner),
    );
  }
}
