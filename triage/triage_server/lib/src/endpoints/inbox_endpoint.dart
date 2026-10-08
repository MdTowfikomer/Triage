import 'package:serverpod/serverpod.dart';
import 'package:serverpod/protocol.dart' show FutureCallEntry;

import '../generated/protocol.dart';
import '../generated/future_calls_generated_models/reminder_future_call_fire_model.dart';
import '../services/inbox_service.dart';

class InboxEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<InboxItem> createItem(
    Session session,
    InboxItem item, {
    bool? allowRecording,
    UuidValue? expectedUserId,
  }) async {
    final owner = InboxService.userId(session);
    // Optional concurrency precondition, never an ownership assignment. Prevent
    // a delayed client draft from being saved under a newly switched account.
    if (expectedUserId != null && expectedUserId != owner) {
      throw TriageException(
        code: 'session_changed',
        message: 'Session changed. Retry under the original account.',
      );
    }
    InboxService.validate(item, owner, allowRecording ?? false);
    final now = DateTime.now().toUtc();
    final saved = await session.db.transaction((transaction) async {
      // Construct fresh rows. Submitted ids, ownership, completion state,
      // timestamps, and nested foreign-key graphs are never reused.
      final parent = await InboxItem.db.insertRow(
        session,
        InboxItem(
          userId: owner,
          type: item.type,
          title: item.title.trim(),
          body: item.body,
          tags: item.tags,
          priority: item.priority,
          emoji: item.emoji,
          dueDate: item.dueDate?.toUtc(),
          redactedTranscript: item.redactedTranscript,
          isCompleted: false,
          confidence: item.confidence,
          createdAt: now,
        ),
        transaction: transaction,
      );
      final reminder = item.reminder;
      if (reminder != null) {
        final savedReminder = await Reminder.db.insertRow(
          session,
          Reminder(
            inboxItemId: parent.id!,
            triggerAt: reminder.triggerAt.toUtc(),
            recurring: reminder.recurring,
            isFired: false,
            createdAt: now,
          ),
          transaction: transaction,
        );
        // The typed scheduling facade in 4.0.4 uses an independent session.
        // Persist its generated payload in the framework queue in this same
        // transaction so a reminder and its scheduled work commit together.
        await FutureCallEntry.db.insertRow(
          session,
          FutureCallEntry(
            name: 'ReminderFireFutureCall',
            serializedObject: SerializationManager.encode(
              ReminderFutureCallFireModel(
                reminderId: savedReminder.id!,
              ).toJson(),
            ),
            time: savedReminder.triggerAt,
            serverId: session.serverpod.serverId,
            identifier: 'triage.reminder.${savedReminder.id}',
          ),
          transaction: transaction,
        );
      }
      final recording = item.recording;
      if (recording != null) {
        await Recording.db.insertRow(
          session,
          Recording(
            inboxItemId: parent.id!,
            storageUrl: recording.storageUrl,
            durationMs: recording.durationMs,
            createdAt: now,
          ),
          transaction: transaction,
        );
      }
      return (await InboxItem.db.findById(
        session,
        parent.id!,
        include: InboxService.include,
        transaction: transaction,
      ))!;
    });
    await InboxService.publish(
      session,
      owner,
      'created',
      saved.id!,
      item: saved,
    );
    return saved;
  }

  Future<List<InboxItem>> listItems(
    Session session, {
    String? type,
    int? limit,
    int? offset,
  }) async {
    final owner = InboxService.userId(session);
    if ((limit != null && (limit < 1 || limit > 100)) ||
        (offset != null && offset < 0) ||
        (type != null &&
            !const {
              'task',
              'note',
              'reminder',
              'shopping',
              'idea',
            }.contains(type))) {
      throw TriageException(
        code: 'invalid_input',
        message: 'Invalid list filter or pagination.',
      );
    }
    return InboxItem.db.find(
      session,
      where: (t) =>
          t.userId.equals(owner) &
          (type == null ? Constant.bool(true) : t.type.equals(type)),
      orderByList: (t) => [t.createdAt.desc(), t.id.desc()],
      limit: limit ?? 50,
      offset: offset ?? 0,
      include: InboxService.include,
    );
  }

  Future<InboxItem> completeItem(Session session, int itemId) async {
    final owner = InboxService.userId(session);
    final saved = await session.db.transaction((transaction) async {
      final item = await InboxItem.db.findFirstRow(
        session,
        where: (t) => t.id.equals(itemId) & t.userId.equals(owner),
        transaction: transaction,
        lockMode: LockMode.forUpdate,
      );
      if (item == null) throw InboxService.notFound();
      if (!item.isCompleted) {
        await InboxItem.db.updateRow(
          session,
          item.copyWith(isCompleted: true, completedAt: DateTime.now().toUtc()),
          columns: (t) => [t.isCompleted, t.completedAt],
          transaction: transaction,
        );
      }
      return (await InboxItem.db.findById(
        session,
        itemId,
        include: InboxService.include,
        transaction: transaction,
      ))!;
    });
    await InboxService.publish(session, owner, 'updated', itemId, item: saved);
    return saved;
  }

  /// Replaces only editable fields; all identity and lifecycle fields stay put.
  Future<InboxItem> updateItem(
    Session session,
    int itemId,
    String title,
    String? body,
    String? priority,
    DateTime? dueDate,
    List<String>? tags,
  ) async {
    final owner = InboxService.userId(session);
    final saved = await session.db.transaction((transaction) async {
      final item = await InboxItem.db.findFirstRow(
        session,
        where: (t) => t.id.equals(itemId) & t.userId.equals(owner),
        transaction: transaction,
        lockMode: LockMode.forUpdate,
      );
      if (item == null) throw InboxService.notFound();
      final reminder = await Reminder.db.findFirstRow(
        session,
        where: (t) => t.inboxItemId.equals(itemId),
        transaction: transaction,
      );
      final changedDate = item.dueDate != dueDate?.toUtc();
      if (reminder != null &&
          changedDate &&
          (dueDate == null || !dueDate.isAfter(DateTime.now().toUtc()))) {
        throw TriageException(
          code: 'invalid_input',
          message: 'Reminder needs a future date.',
        );
      }
      final updated = item.copyWith(
        title: title.trim(),
        body: body,
        priority: priority,
        dueDate: dueDate?.toUtc(),
        tags: tags,
        reminder: reminder,
      );
      // Unchanged fired reminders can still have their title edited. A changed
      // reminder date was checked above and cannot bypass the future-time rule.
      InboxService.validate(updated, owner, false, checkReminderTime: false);
      await InboxItem.db.updateRow(
        session,
        updated,
        columns: (t) => [t.title, t.body, t.priority, t.dueDate, t.tags],
        transaction: transaction,
      );
      if (reminder != null && changedDate) {
        await Reminder.db.updateRow(
          session,
          reminder.copyWith(
            triggerAt: dueDate!.toUtc(),
            isFired: false,
          ),
          columns: (t) => [t.triggerAt, t.isFired],
          transaction: transaction,
        );
        await FutureCallEntry.db.deleteWhere(
          session,
          where: (t) => t.identifier.equals('triage.reminder.${reminder.id}'),
          transaction: transaction,
        );
        if (!item.isCompleted) {
          await FutureCallEntry.db.insertRow(
            session,
            FutureCallEntry(
              name: 'ReminderFireFutureCall',
              serializedObject: SerializationManager.encode(
                ReminderFutureCallFireModel(reminderId: reminder.id!).toJson(),
              ),
              time: dueDate.toUtc(),
              serverId: session.serverpod.serverId,
              identifier: 'triage.reminder.${reminder.id}',
            ),
            transaction: transaction,
          );
        }
      }
      return (await InboxItem.db.findById(
        session,
        itemId,
        include: InboxService.include,
        transaction: transaction,
      ))!;
    });
    await InboxService.publish(session, owner, 'updated', itemId, item: saved);
    return saved;
  }

  Future<bool> deleteItem(Session session, int itemId) async {
    final owner = InboxService.userId(session);
    final deleted = await session.db.transaction((transaction) async {
      final item = await InboxItem.db.findFirstRow(
        session,
        where: (t) => t.id.equals(itemId) & t.userId.equals(owner),
        transaction: transaction,
        lockMode: LockMode.forUpdate,
      );
      if (item == null) return false;
      await InboxItem.db.deleteRow(session, item, transaction: transaction);
      return true;
    });
    if (deleted) {
      await InboxService.publish(session, owner, 'deleted', itemId);
    }
    return deleted;
  }
}
