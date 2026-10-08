import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';

/// Shared authorization and event construction, also used by internal reminders.
class InboxService {
  static UuidValue userId(Session session) {
    // Serverpod 4's authenticated property is synchronous. The official auth
    // extension parses its verified identifier as the AuthUser UUID.
    final id = session.authenticated?.authUserId;
    if (id == null) {
      throw TriageException(code: 'unauthorized', message: 'Sign in required.');
    }
    return id;
  }

  static String channel(UuidValue userId) => 'triage.inbox.$userId';

  static InboxItemInclude get include => InboxItem.include(
    reminder: Reminder.include(),
    recording: Recording.include(),
  );

  static Future<void> publish(
    Session session,
    UuidValue owner,
    String operation,
    int itemId, {
    InboxItem? item,
  }) async {
    await session.messages.postMessage(
      channel(owner),
      InboxEvent(
        operation: operation,
        itemId: itemId,
        item: item,
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }

  static TriageException notFound() => TriageException(
    code: 'not_found',
    message: 'Item not found.',
  );

  static void validate(
    InboxItem item,
    UuidValue owner,
    bool allowRecording, {
    bool checkReminderTime = true,
  }) {
    void invalid(String message) =>
        throw TriageException(code: 'invalid_input', message: message);
    if (!const {
      'task',
      'note',
      'reminder',
      'shopping',
      'idea',
    }.contains(item.type)) {
      invalid('Invalid item type.');
    }
    if (item.title.trim().isEmpty || item.title.length > 500) {
      invalid('Title must contain 1–500 characters.');
    }
    if (item.priority != null &&
        !const {'low', 'medium', 'high'}.contains(item.priority)) {
      invalid('Invalid priority.');
    }
    if (item.confidence != null &&
        (!item.confidence!.isFinite ||
            item.confidence! < 0 ||
            item.confidence! > 1)) {
      invalid('Confidence must be between 0 and 1.');
    }
    if (item.redactedTranscript.length > 16000 ||
        (item.body?.length ?? 0) > 16000) {
      invalid('Text exceeds 16000 characters.');
    }
    if ((item.tags?.length ?? 0) > 32 ||
        (item.tags?.any((tag) => tag.trim().isEmpty || tag.length > 50) ??
            false)) {
      invalid('Invalid tags.');
    }
    final reminder = item.reminder;
    if (item.type == 'reminder' && reminder == null) {
      invalid('Reminder requires a resolved trigger time.');
    }
    if (reminder != null) {
      if (!const {'none', 'daily', 'weekly'}.contains(reminder.recurring)) {
        invalid('Invalid recurrence.');
      }
      if (checkReminderTime &&
          !reminder.triggerAt.isAfter(DateTime.now().toUtc())) {
        invalid('Reminder must be scheduled in the future.');
      }
    }
    final recording = item.recording;
    if (recording != null) {
      if (!allowRecording) invalid('Audio storage requires explicit opt-in.');
      // A private storage reference, never an arbitrary/public download URL.
      final prefix = 'private://users/$owner/audio/';
      final suffix = recording.storageUrl.startsWith(prefix)
          ? recording.storageUrl.substring(prefix.length)
          : '';
      if (!RegExp(r'^[a-zA-Z0-9_-]+\.(wav|m4a|aac)$').hasMatch(suffix) ||
          recording.durationMs < 0) {
        invalid('Invalid owned audio storage reference.');
      }
    }
  }
}
