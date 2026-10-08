import 'dart:async';
import 'package:triage_client/triage_client.dart';
import '../core/draft.dart';

abstract class InboxRepository {
  UuidValue get owner;
  Future<List<InboxItem>> list({int offset = 0});
  Future<InboxItem> create(InboxItem item);
  Future<InboxItem> complete(int id);
  Future<bool> delete(int id);
  Future<InboxItem> update(InboxItem item);
  Stream<InboxEvent> watch();
}

class ServerInboxRepository implements InboxRepository {
  ServerInboxRepository(this.client, this.owner);
  final Client client;
  @override
  final UuidValue owner;
  @override
  Future<List<InboxItem>> list({int offset = 0}) =>
      client.inbox.listItems(limit: 100, offset: offset);
  @override
  Future<InboxItem> create(InboxItem item) =>
      client.inbox.createItem(item, expectedUserId: owner);
  @override
  Future<InboxItem> complete(int id) => client.inbox.completeItem(id);
  @override
  Future<bool> delete(int id) => client.inbox.deleteItem(id);
  @override
  Future<InboxItem> update(InboxItem item) => client.inbox.updateItem(
    item.id!,
    item.title,
    item.body,
    item.priority,
    item.dueDate,
    item.tags,
  );
  @override
  Stream<InboxEvent> watch() => client.sync.streamInbox();
}

/// Explicit --dart-define=TRIAGE_DEMO=true; never masquerades as cloud storage.
class DemoInboxRepository implements InboxRepository {
  DemoInboxRepository({bool seed = true}) {
    if (seed) {
      final examples = [
        ('task', 'Ship the new onboarding', 'high', ['work', 'product']),
        ('note', 'Q4 budget approved', '', ['meeting', 'finance']),
        ('reminder', 'Call the dentist', '', ['personal']),
        ('shopping', 'Oat milk', '', ['groceries']),
        ('idea', 'Make onboarding feel like a game', '', ['product']),
      ];
      for (final e in examples) {
        final id = _next++;
        items.add(
          InboxItem(
            id: id,
            userId: owner,
            type: e.$1,
            title: e.$2,
            priority: e.$3.isEmpty ? null : e.$3,
            tags: e.$4,
            emoji: categoryEmoji(e.$1),
            createdAt: DateTime.now(),
            dueDate: e.$1 == 'task' || e.$1 == 'reminder'
                ? DateTime.now().add(const Duration(days: 1))
                : null,
            redactedTranscript: 'Demo content. No recording was made.',
          ),
        );
      }
    }
  }
  @override
  UuidValue get owner =>
      UuidValue.fromString('00000000-0000-4000-8000-000000000001');
  final List<InboxItem> items = [];
  final _events = StreamController<InboxEvent>.broadcast();
  int _next = 1;
  void _event(String op, InboxItem item) => _events.add(
    InboxEvent(
      operation: op,
      itemId: item.id!,
      item: op == 'deleted' ? null : item,
      occurredAt: DateTime.now(),
    ),
  );
  @override
  Future<List<InboxItem>> list({int offset = 0}) async =>
      items.skip(offset).take(100).toList();
  @override
  Future<InboxItem> create(InboxItem item) async {
    final saved = item.copyWith(id: _next++, userId: owner);
    items.insert(0, saved);
    _event('created', saved);
    return saved;
  }

  @override
  Future<InboxItem> complete(int id) async {
    final item = items
        .firstWhere((i) => i.id == id)
        .copyWith(isCompleted: true, completedAt: DateTime.now());
    return update(item);
  }

  @override
  Future<InboxItem> update(InboxItem item) async {
    final index = items.indexWhere((i) => i.id == item.id);
    if (index < 0) throw StateError('Item not found');
    items[index] = item;
    _event('updated', item);
    return item;
  }

  @override
  Future<bool> delete(int id) async {
    final item = items.firstWhere((i) => i.id == id);
    items.remove(item);
    _event('deleted', item);
    return true;
  }

  @override
  Stream<InboxEvent> watch() => _events.stream;
  Future<void> dispose() => _events.close();
}
