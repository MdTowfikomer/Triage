import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/inbox_service.dart';

class ReminderFutureCall extends FutureCall {
  Future<void> fire(Session session, int reminderId) async {
    final updated = await session.db.transaction((transaction) async {
      final reminder = await Reminder.db.findById(
        session,
        reminderId,
        transaction: transaction,
      );
      if (reminder == null) {
        return null; // Deletion cascaded; stale queue entry.
      }
      final item = await InboxItem.db.findFirstRow(
        session,
        where: (t) => t.id.equals(reminder.inboxItemId),
        transaction: transaction,
        lockMode: LockMode.forUpdate,
      );
      if (item == null || item.isCompleted) return null;
      final current = await Reminder.db.findById(
        session,
        reminderId,
        transaction: transaction,
      );
      if (current == null ||
          current.isFired ||
          current.triggerAt.isAfter(DateTime.now().toUtc())) {
        return null;
      }
      await Reminder.db.updateRow(
        session,
        current.copyWith(isFired: true),
        columns: (t) => [t.isFired],
        transaction: transaction,
      );
      return InboxItem.db.findById(
        session,
        item.id!,
        include: InboxService.include,
        transaction: transaction,
      );
    });
    if (updated != null) {
      await InboxService.publish(
        session,
        updated.userId,
        'reminder_fired',
        updated.id!,
        item: updated,
      );
    }
  }
}
