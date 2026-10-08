import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:test/test.dart';
import 'package:triage_server/server.dart';
import 'package:triage_server/src/endpoints/sync_endpoint.dart';
import 'package:triage_server/src/generated/protocol.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Triage authenticated inbox', (builder, endpoints) {
    late TestSessionBuilder a, b;
    late UuidValue userA, userB;
    late Session db;
    InboxItem draft({
      String type = 'task',
      String title = 'Email Sarah',
      Reminder? reminder,
      Recording? recording,
    }) => InboxItem(
      id: 987654,
      userId: userB,
      type: type,
      title: title,
      redactedTranscript: 'Email [PERSON] about the proposal',
      isCompleted: true,
      completedAt: DateTime.utc(2000),
      confidence: null,
      createdAt: DateTime.utc(2000),
      reminder: reminder,
      recording: recording,
    );
    Reminder reminder({int? id, int parent = 987654}) => Reminder(
      id: id,
      inboxItemId: parent,
      triggerAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      recurring: 'none',
      isFired: true,
      createdAt: DateTime.utc(2000),
    );
    Recording recording(UuidValue owner) => Recording(
      id: 987654,
      inboxItemId: 987654,
      storageUrl: 'private://users/$owner/audio/sample.wav',
      durationMs: 4000,
      createdAt: DateTime.utc(2000),
    );
    Matcher failure(String code) =>
        isA<TriageException>().having((e) => e.code, 'code', code);

    setUp(() async {
      db = builder.build();
      configureAuthentication(db.serverpod);
      userA = (await AuthServices.instance.authUsers.create(db)).id;
      userB = (await AuthServices.instance.authUsers.create(db)).id;
      a = builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          userA.toString(),
          {},
        ),
      );
      b = builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          userB.toString(),
          {},
        ),
      );
    });

    test(
      'official JWT manager validates identity and rejects invalid tokens',
      () async {
        final token = await AuthServices.instance.tokenManager.issueToken(
          db,
          authUserId: userA,
          method: 'email',
          scopes: {},
        );
        final info = await db.serverpod.authenticationHandler!(db, token.token);
        expect(info!.authUserId, userA);
        expect(
          await db.serverpod.authenticationHandler!(db, 'invalid-token'),
          isNull,
        );
        final authenticated = builder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            info.userIdentifier,
            info.scopes,
            authId: info.authId,
          ),
        );
        final saved = await endpoints.inbox.createItem(authenticated, draft());
        expect(saved.userId, userA);
      },
    );
    test(
      'database rejects reminder referencing nonexistent inbox row',
      () async {
        await expectLater(
          Reminder.db.insertRow(db, reminder(parent: 987654)),
          throwsA(isA<DatabaseQueryException>()),
        );
      },
    );
    test('database rejects inbox owner not in official auth table', () async {
      await expectLater(
        InboxItem.db.insertRow(
          db,
          draft().copyWith(
            userId: UuidValue.withValidation(
              '00000000-0000-4000-8000-000000000001',
            ),
          ),
        ),
        throwsA(isA<DatabaseQueryException>()),
      );
    });
    test('update rejects unauthenticated access', () async {
      await expectLater(
        endpoints.inbox.updateItem(builder, 1, 'Title', null, null, null, null),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });
    test(
      'create account precondition rejects switched session without assigning ownership',
      () async {
        await expectLater(
          endpoints.inbox.createItem(b, draft(), expectedUserId: userA),
          throwsA(failure('session_changed')),
        );
        expect(await endpoints.inbox.listItems(b), isEmpty);
        final saved = await endpoints.inbox.createItem(
          a,
          draft(),
          expectedUserId: userA,
        );
        expect(saved.userId, userA);
      },
    );
    test(
      'update cannot touch another owner or distinguish missing id',
      () async {
        final saved = await endpoints.inbox.createItem(
          b,
          draft(title: 'Private B'),
        );
        for (final id in [saved.id!, 987654]) {
          await expectLater(
            endpoints.inbox.updateItem(a, id, 'Stolen', null, null, null, null),
            throwsA(failure('not_found')),
          );
        }
        expect(
          (await InboxItem.db.findById(db, saved.id!))!.title,
          'Private B',
        );
      },
    );
    test(
      'update edits allowed fields, clears nulls, preserves identity',
      () async {
        final saved = await endpoints.inbox.createItem(
          a,
          draft().copyWith(
            body: 'Old',
            priority: 'high',
            tags: ['old'],
            dueDate: DateTime.now(),
          ),
        );
        final completed = await endpoints.inbox.completeItem(a, saved.id!);
        final updated = await endpoints.inbox.updateItem(
          a,
          saved.id!,
          '  New title  ',
          null,
          null,
          null,
          null,
        );
        expect(updated.title, 'New title');
        expect(updated.body, isNull);
        expect(updated.tags, isNull);
        expect(updated.priority, isNull);
        expect(updated.dueDate, isNull);
        expect(updated.userId, userA);
        expect(updated.id, saved.id);
        expect(updated.type, saved.type);
        expect(updated.createdAt, saved.createdAt);
        expect(updated.completedAt, completed.completedAt);
        expect(updated.isCompleted, isTrue);
        expect(updated.redactedTranscript, saved.redactedTranscript);
      },
    );
    test('update rejects invalid fields and rolls back', () async {
      final saved = await endpoints.inbox.createItem(a, draft());
      await expectLater(
        endpoints.inbox.updateItem(
          a,
          saved.id!,
          '',
          null,
          'urgent',
          null,
          null,
        ),
        throwsA(failure('invalid_input')),
      );
      expect((await InboxItem.db.findById(db, saved.id!))!.title, saved.title);
    });
    test(
      'reminder reschedule replaces queue atomically with resolved date',
      () async {
        final initial = reminder();
        final saved = await endpoints.inbox.createItem(
          a,
          draft(
            type: 'reminder',
            reminder: initial,
          ).copyWith(dueDate: initial.triggerAt),
        );
        final trigger = DateTime.now().toUtc().add(const Duration(days: 2));
        final updated = await endpoints.inbox.updateItem(
          a,
          saved.id!,
          'Dentist moved',
          null,
          null,
          trigger,
          ['personal'],
        );
        expect(updated.dueDate, trigger);
        expect(updated.reminder!.triggerAt, trigger);
        expect(updated.reminder!.isFired, isFalse);
        final queued = await FutureCallEntry.db.find(
          db,
          where: (t) =>
              t.identifier.equals('triage.reminder.${saved.reminder!.id}'),
        );
        expect(queued, hasLength(1));
        expect(queued.single.time, trigger);
        await expectLater(
          endpoints.inbox.updateItem(
            a,
            saved.id!,
            'Bad reschedule',
            null,
            null,
            null,
            null,
          ),
          throwsA(failure('invalid_input')),
        );
        expect(
          (await Reminder.db.findById(db, saved.reminder!.id!))!.triggerAt,
          trigger,
        );
      },
    );
    test(
      'editing fired reminder without date change preserves fired state',
      () async {
        final initial = reminder();
        final saved = await endpoints.inbox.createItem(
          a,
          draft(
            type: 'reminder',
            reminder: initial,
          ).copyWith(dueDate: initial.triggerAt),
        );
        await Reminder.db.updateRow(
          db,
          saved.reminder!.copyWith(isFired: true),
        );
        final updated = await endpoints.inbox.updateItem(
          a,
          saved.id!,
          'Edited',
          null,
          null,
          saved.dueDate,
          null,
        );
        expect(updated.reminder!.isFired, isTrue);
      },
    );
    test('database enforces one recording per item', () async {
      final saved = await endpoints.inbox.createItem(
        a,
        draft(recording: recording(userA)),
        allowRecording: true,
      );
      await expectLater(
        Recording.db.insertRow(
          db,
          recording(userA).copyWith(inboxItemId: saved.id!),
        ),
        throwsA(isA<DatabaseQueryException>()),
      );
    });
    test('deleting auth user cascades only owned data', () async {
      await endpoints.inbox.createItem(
        a,
        draft(
          type: 'reminder',
          reminder: reminder(),
          recording: recording(userA),
        ),
        allowRecording: true,
      );
      await endpoints.inbox.createItem(b, draft(title: 'Retain B'));
      await AuthServices.instance.authUsers.delete(db, authUserId: userA);
      expect(
        await InboxItem.db.count(db, where: (t) => t.userId.equals(userA)),
        0,
      );
      expect(await Reminder.db.count(db), 0);
      expect(await Recording.db.count(db), 0);
      expect((await endpoints.inbox.listItems(b)).single.title, 'Retain B');
    });
    test('all CRUD methods reject unauthenticated sessions', () async {
      expect(
        endpoints.inbox.createItem(builder, draft()),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
      expect(
        endpoints.inbox.listItems(builder),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
      expect(
        endpoints.inbox.completeItem(builder, 1),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
      expect(
        endpoints.inbox.deleteItem(builder, 1),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });
    test('stream rejects unauthenticated sessions', () async {
      await expectLater(
        endpoints.sync.streamInbox(builder),
        emitsError(isA<ServerpodUnauthenticatedException>()),
      );
    });
    test(
      'creation stamps session UUID, ID, clock and completion state',
      () async {
        final before = DateTime.now().toUtc();
        final saved = await endpoints.inbox.createItem(a, draft());
        expect(saved.userId, userA);
        expect(saved.id, isNot(987654));
        expect(saved.isCompleted, isFalse);
        expect(saved.completedAt, isNull);
        expect(saved.confidence, isNull);
        expect(saved.createdAt.isBefore(before), isFalse);
        expect(saved.createdAt.isUtc, isTrue);
        expect((await InboxItem.db.findById(db, saved.id!))!.userId, userA);
      },
    );
    test(
      'User A lists only A rows, including filtered and paginated queries',
      () async {
        final first = await endpoints.inbox.createItem(
          a,
          draft(title: 'First'),
        );
        final second = await endpoints.inbox.createItem(
          a,
          draft(type: 'shopping', title: 'Milk'),
        );
        await endpoints.inbox.createItem(
          b,
          draft(type: 'shopping', title: 'Private B'),
        );
        expect((await endpoints.inbox.listItems(a)).map((row) => row.id), [
          second.id,
          first.id,
        ]);
        expect(
          (await endpoints.inbox.listItems(a, type: 'shopping')).single.id,
          second.id,
        );
        expect(
          (await endpoints.inbox.listItems(a, limit: 1, offset: 1)).single.id,
          first.id,
        );
        expect((await endpoints.inbox.listItems(b)).single.title, 'Private B');
      },
    );
    test(
      'User A cannot complete B, with same response as missing item',
      () async {
        final saved = await endpoints.inbox.createItem(b, draft());
        await expectLater(
          endpoints.inbox.completeItem(a, saved.id!),
          throwsA(failure('not_found')),
        );
        await expectLater(
          endpoints.inbox.completeItem(a, 987654),
          throwsA(failure('not_found')),
        );
        expect(
          (await InboxItem.db.findById(db, saved.id!))!.isCompleted,
          isFalse,
        );
      },
    );
    test(
      'User A cannot delete B or distinguish missing item through delete',
      () async {
        final saved = await endpoints.inbox.createItem(b, draft());
        expect(await endpoints.inbox.deleteItem(a, saved.id!), isFalse);
        expect(await endpoints.inbox.deleteItem(a, 987654), isFalse);
        expect(await InboxItem.db.findById(db, saved.id!), isNotNull);
      },
    );
    test(
      'owner completes item; repeats preserve original completedAt',
      () async {
        final saved = await endpoints.inbox.createItem(a, draft());
        final first = await endpoints.inbox.completeItem(a, saved.id!);
        final repeated = await endpoints.inbox.completeItem(a, saved.id!);
        expect(first.isCompleted, isTrue);
        expect(first.completedAt, isNotNull);
        expect(repeated.completedAt, first.completedAt);
      },
    );
    test(
      'all related IDs are stamped and children are loaded through formal relations',
      () async {
        final saved = await endpoints.inbox.createItem(
          a,
          draft(
            type: 'reminder',
            reminder: reminder(),
            recording: recording(userA),
          ),
          allowRecording: true,
        );
        expect(saved.reminder!.inboxItemId, saved.id);
        expect(saved.reminder!.isFired, isFalse);
        expect(saved.reminder!.createdAt, saved.createdAt);
        expect(saved.recording!.inboxItemId, saved.id);
        expect(saved.recording!.id, isNot(987654));
        final loaded = (await endpoints.inbox.listItems(a)).single;
        expect(loaded.reminder!.id, saved.reminder!.id);
        expect(loaded.recording!.id, saved.recording!.id);
        final queue = await FutureCallEntry.db.findFirstRow(
          db,
          where: (t) =>
              t.identifier.equals('triage.reminder.${saved.reminder!.id}'),
        );
        expect(queue!.name, 'ReminderFireFutureCall');
        expect(queue.time, saved.reminder!.triggerAt);
        expect(
          jsonDecode(queue.serializedObject!)['reminderId'],
          saved.reminder!.id,
        );
      },
    );
    test('nested B IDs cannot reparent or modify B reminder', () async {
      final other = await endpoints.inbox.createItem(
        b,
        draft(type: 'reminder', reminder: reminder()),
      );
      final spoofed = other.reminder!.copyWith(inboxItem: other);
      final own = await endpoints.inbox.createItem(
        a,
        draft(type: 'reminder', reminder: spoofed),
      );
      expect(own.reminder!.id, isNot(other.reminder!.id));
      expect(own.reminder!.inboxItemId, own.id);
      expect(
        (await Reminder.db.findById(db, other.reminder!.id!))!.inboxItemId,
        other.id,
      );
    });
    test(
      'audio is denied without explicit opt-in or for another owner path',
      () async {
        await expectLater(
          endpoints.inbox.createItem(a, draft(recording: recording(userA))),
          throwsA(failure('invalid_input')),
        );
        await expectLater(
          endpoints.inbox.createItem(
            a,
            draft(recording: recording(userB)),
            allowRecording: true,
          ),
          throwsA(failure('invalid_input')),
        );
        expect(await InboxItem.db.count(db), 0);
      },
    );
    test(
      'deleting owner item cascades reminder and recording; stale job is harmless',
      () async {
        final saved = await endpoints.inbox.createItem(
          a,
          draft(
            type: 'reminder',
            reminder: reminder(),
            recording: recording(userA),
          ),
          allowRecording: true,
        );
        expect(await endpoints.inbox.deleteItem(a, saved.id!), isTrue);
        expect(await Reminder.db.findById(db, saved.reminder!.id!), isNull);
        expect(await Recording.db.findById(db, saved.recording!.id!), isNull);
        await endpoints.futureCalls.reminder.fire(builder, saved.reminder!.id!);
        expect(await InboxItem.db.count(db), 0);
      },
    );
    test(
      'database enforces one reminder per item',
      () async {
        final saved = await endpoints.inbox.createItem(
          a,
          draft(type: 'reminder', reminder: reminder()),
        );
        await expectLater(
          Reminder.db.insertRow(db, reminder(parent: saved.id!)),
          throwsA(isA<DatabaseQueryException>()),
        );
        // The next case gets a fresh test transaction.
      },
    );
    test(
      'protocol excludes original transcript and discards unknown raw fields',
      () async {
        final input = draft().toJson()
          ..['originalTranscript'] = 'Private raw speech';
        final saved = await endpoints.inbox.createItem(
          a,
          InboxItem.fromJson(input),
        );
        final encoded = jsonEncode(saved.toJsonForProtocol());
        expect(encoded, isNot(contains('originalTranscript')));
        expect(encoded, isNot(contains('Private raw speech')));
        expect(encoded, contains('redactedTranscript'));
      },
    );
    test(
      'valid nullable confidence persists without becoming a validity flag',
      () async {
        final saved = await endpoints.inbox.createItem(
          a,
          draft().copyWith(confidence: 0.1566),
        );
        expect(saved.confidence, 0.1566);
      },
    );
    for (final input in <InboxItem Function()>[
      () => draft(type: 'invalid'),
      () => draft(title: '  '),
      () => draft().copyWith(priority: 'urgent'),
      () => draft().copyWith(confidence: -0.1),
      () => draft().copyWith(confidence: 1.1),
      () => draft(type: 'reminder'),
      () => draft(
        type: 'reminder',
        reminder: reminder().copyWith(triggerAt: DateTime.utc(2000)),
      ),
      () => draft(
        type: 'reminder',
        reminder: reminder().copyWith(recurring: 'hourly'),
      ),
    ].indexed) {
      test('invalid data ${input.$1} is rejected before insertion', () async {
        await expectLater(
          endpoints.inbox.createItem(a, input.$2()),
          throwsA(failure('invalid_input')),
        );
        expect(await InboxItem.db.count(db), 0);
      });
    }
    for (final limit in [0, -1, 101]) {
      test('invalid pagination limit $limit is rejected', () async {
        await expectLater(
          endpoints.inbox.listItems(a, limit: limit),
          throwsA(failure('invalid_input')),
        );
      });
    }
    test('invalid offset and type filter are rejected', () async {
      await expectLater(
        endpoints.inbox.listItems(a, offset: -1),
        throwsA(failure('invalid_input')),
      );
      await expectLater(
        endpoints.inbox.listItems(a, type: 'invalid'),
        throwsA(failure('invalid_input')),
      );
    });
    test(
      'created, updated, deleted events reach both A sessions and never B',
      () async {
        final sessionA1 = a.build(),
            sessionA2 = a.build(),
            sessionB = b.build();
        final eventsA1 = <InboxEvent>[],
            eventsA2 = <InboxEvent>[],
            eventsB = <InboxEvent>[];
        final done = Completer<void>();
        final sub1 = SyncEndpoint().streamInbox(sessionA1).listen(eventsA1.add);
        final sub2 = SyncEndpoint().streamInbox(sessionA2).listen((event) {
          eventsA2.add(event);
          if (event.operation == 'deleted') done.complete();
        });
        final receiveB = Completer<void>();
        final subB = SyncEndpoint().streamInbox(sessionB).listen((event) {
          eventsB.add(event);
          if (!receiveB.isCompleted) receiveB.complete();
        });
        try {
          final saved = await endpoints.inbox.createItem(a, draft());
          await endpoints.inbox.completeItem(a, saved.id!);
          await endpoints.inbox.deleteItem(a, saved.id!);
          await done.future.timeout(const Duration(seconds: 5));
          expect(eventsA1.map((event) => event.operation), [
            'created',
            'updated',
            'deleted',
          ]);
          expect(eventsA2.map((event) => event.itemId), [
            saved.id,
            saved.id,
            saved.id,
          ]);
          expect(eventsB, isEmpty);
          expect(eventsA1.last.item, isNull);
          expect(eventsA1.first.item!.userId, userA);
          final ownB = await endpoints.inbox.createItem(
            b,
            draft(title: 'Private B'),
          );
          await receiveB.future.timeout(const Duration(seconds: 5));
          expect(eventsB.single.itemId, ownB.id);
          expect(eventsB.single.item!.userId, userB);
          expect(eventsA1.length, 3);
          expect(eventsA2.length, 3);
        } finally {
          await sub1.cancel();
          await sub2.cancel();
          await subB.cancel();
        }
      },
    );
    test(
      'due reminder fires once, publishes owner event, never fires early',
      () async {
        final saved = await endpoints.inbox.createItem(
          a,
          draft(type: 'reminder', reminder: reminder()),
        );
        await endpoints.futureCalls.reminder.fire(builder, saved.reminder!.id!);
        expect(
          (await Reminder.db.findById(db, saved.reminder!.id!))!.isFired,
          isFalse,
        );
        await Reminder.db.updateRow(
          db,
          saved.reminder!.copyWith(
            triggerAt: DateTime.now().toUtc().subtract(
              const Duration(seconds: 1),
            ),
          ),
        );
        final events = <InboxEvent>[];
        final notification = Completer<void>();
        final streamSession = a.build();
        final sub = SyncEndpoint().streamInbox(streamSession).listen((event) {
          events.add(event);
          if (!notification.isCompleted) notification.complete();
        });
        try {
          await endpoints.futureCalls.reminder.fire(
            builder,
            saved.reminder!.id!,
          );
          await notification.future.timeout(const Duration(seconds: 5));
          await endpoints.futureCalls.reminder.fire(
            builder,
            saved.reminder!.id!,
          );
          expect(events.single.operation, 'reminder_fired');
          expect(events.single.item!.reminder!.isFired, isTrue);
        } finally {
          await sub.cancel();
        }
      },
    );
    test('completed item reminder is never fired', () async {
      final saved = await endpoints.inbox.createItem(
        a,
        draft(type: 'reminder', reminder: reminder()),
      );
      await endpoints.inbox.completeItem(a, saved.id!);
      await Reminder.db.updateRow(
        db,
        saved.reminder!.copyWith(triggerAt: DateTime.utc(2000)),
      );
      await endpoints.futureCalls.reminder.fire(builder, saved.reminder!.id!);
      expect(
        (await Reminder.db.findById(db, saved.reminder!.id!))!.isFired,
        isFalse,
      );
    });
  });
}
