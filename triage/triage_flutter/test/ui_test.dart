import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_client/triage_client.dart';
import 'package:triage_flutter/core/draft.dart';
import 'package:triage_flutter/core/redact.dart';
import 'package:triage_flutter/data/inbox_repository.dart';
import 'package:triage_flutter/data/local_cache.dart';
import 'package:triage_flutter/state/inbox_controller.dart';
import 'package:triage_flutter/ui/inbox_view.dart';
import 'package:triage_flutter/ui/theme.dart';
import 'package:triage_flutter/voice/voice_engine.dart';
import 'package:triage_flutter/notifications/reminder_scheduler.dart';

Map<String, dynamic> result({
  double? score = .2,
  List<Map<String, dynamic>>? calls,
  List<Map<String, dynamic>> suppressed = const [],
  bool schema = true,
}) => {
  'transcript': 'Email Sarah about the proposal',
  'routing': {
    'schema': {'valid': schema},
    'parsed': {
      'type': 'call',
      'success': true,
      'confidence': score,
      'function_calls':
          calls ??
          [
            {
              'name': 'add_task',
              'arguments': {'title': 'Email Sarah'},
            },
          ],
      'suppressed_calls': suppressed,
    },
  },
};

class FakeVoice implements VoiceEngine {
  Map<String, dynamic> response = result();
  bool started = false, cancelled = false;
  bool fail = false;
  @override
  Future<void> initialize() async {
    if (fail) throw StateError('Failed');
  }

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<Map<String, dynamic>> stop() async {
    started = false;
    return response;
  }

  @override
  Future<Map<String, dynamic>> route(String text) async => response;
  @override
  Future<List<double>> levels() async => List.filled(12, .5);
  @override
  Future<void> cancel() async {
    cancelled = true;
    started = false;
  }
}

class TestRepository extends DemoInboxRepository {
  TestRepository({super.seed = false});
  int creates = 0, completes = 0, deletes = 0;
  bool failCreate = false;
  bool failDelete = false;
  InboxItem? submitted;
  @override
  Future<InboxItem> create(InboxItem item) async {
    creates++;
    submitted = item;
    if (failCreate) throw StateError('Offline');
    return super.create(item);
  }

  @override
  Future<InboxItem> complete(int id) async {
    completes++;
    return super.complete(id);
  }

  @override
  Future<bool> delete(int id) async {
    deletes++;
    if (failDelete) throw StateError('Offline');
    return super.delete(id);
  }
}

class FakeReminderScheduler implements ReminderScheduler {
  final scheduled = <int, DateTime>{};
  int initialized = 0;
  @override
  Future<void> initialize() async => initialized++;
  @override
  Future<void> schedule(int id, String title, DateTime triggerAt) async {
    scheduled[id] = triggerAt;
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

class FakePayloadRedactor implements PayloadRedactor {
  final batches = <List<String>>[];
  bool fail = false;
  @override
  Future<List<String>> redact(List<String> inputs) async {
    batches.add(List.of(inputs));
    if (fail) throw StateError('Redaction unavailable');
    return inputs.map(redactKnownPii).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRepository repo;
  late FakeVoice voice;
  late LocalCache cache;
  late InboxController c;
  late FakeReminderScheduler reminders;
  late FakePayloadRedactor redactor;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = TestRepository();
    voice = FakeVoice();
    cache = LocalCache(
      await SharedPreferences.getInstance(),
      repo.owner.toString(),
    );
    reminders = FakeReminderScheduler();
    redactor = FakePayloadRedactor();
    c = InboxController(
      repository: repo,
      cache: cache,
      voice: voice,
      reminders: reminders,
      redactor: redactor,
    );
  });
  tearDown(() async {
    c.dispose();
    await repo.dispose();
  });
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(900, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await c.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: triageTheme(),
        home: InboxView(controller: c),
      ),
    );
    await tester.pump();
  }

  Future<void> confirm(WidgetTester tester, Map<String, dynamic> output) async {
    await c.acceptResult(output);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
  }

  testWidgets('idle → recording with timer and waveform → confirmation', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Tap to speak'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-toggle')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(c.phase, CapturePhase.recording);
    expect(voice.started, isTrue);
    expect(find.text('0:01'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    expect(c.phase, CapturePhase.confirmation);
    expect(find.byKey(const Key('confirmation-card')), findsOneWidget);
    expect(find.text('Email Sarah about the proposal'), findsOneWidget);
  });
  testWidgets('three-second expiration performs exactly one save', (
    tester,
  ) async {
    await mount(tester);
    await c.acceptResult(result());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2999));
    expect(repo.creates, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repo.creates, 1);
    expect(c.phase, CapturePhase.idle);
    expect(
      cache.original(repo.items.single.id!),
      'Email Sarah about the proposal',
    );
    await tester.pump(const Duration(seconds: 4));
    expect(repo.creates, 1);
  });
  testWidgets('Edit cancels auto-save permanently, fields ready', (
    tester,
  ) async {
    await mount(tester);
    await confirm(tester, result());
    await tester.tap(find.byKey(const Key('edit-capture')));
    await tester.pump();
    expect(c.phase, CapturePhase.review);
    expect(c.countdownMs, isNull);
    expect(find.byKey(const Key('draft-title')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(repo.creates, 0);
    expect(find.byKey(const Key('autosave-progress')), findsNothing);
  });
  testWidgets('Cancel discards pending capture without save', (tester) async {
    await mount(tester);
    await confirm(tester, result());
    await tester.tap(find.byKey(const Key('cancel-capture')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(repo.creates, 0);
    expect(c.pending, isEmpty);
    expect(cache.drafts, isEmpty);
    expect(c.phase, CapturePhase.idle);
  });
  for (final score in <double?>[.099, 0, null, double.nan, 1.01]) {
    testWidgets('confidence $score disables auto-save', (tester) async {
      await mount(tester);
      await confirm(tester, result(score: score));
      expect(c.phase, CapturePhase.review);
      expect(c.countdownMs, isNull);
      await tester.pump(const Duration(seconds: 4));
      expect(repo.creates, 0);
      expect(find.byKey(const Key('autosave-progress')), findsNothing);
    });
  }
  testWidgets('exact 0.1 threshold is actionable', (tester) async {
    await mount(tester);
    await confirm(tester, result(score: .1));
    expect(c.phase, CapturePhase.confirmation);
    expect(c.countdownMs, isNotNull);
  });
  testWidgets('suppressed calls are not promoted even at high confidence', (
    tester,
  ) async {
    await mount(tester);
    await confirm(
      tester,
      result(
        calls: [],
        score: .9,
        suppressed: [
          {
            'name': 'add_task',
            'arguments': {'title': 'Unsafe'},
          },
        ],
      ),
    );
    expect(c.phase, CapturePhase.review);
    expect(c.current!.title, 'Email Sarah about the proposal');
    expect(c.current!.title, isNot('Unsafe'));
    await tester.pump(const Duration(seconds: 4));
    expect(repo.creates, 0);
  });
  testWidgets('invalid schema pauses the timer', (tester) async {
    await mount(tester);
    await confirm(tester, result(schema: false));
    expect(c.phase, CapturePhase.review);
    expect(c.countdownMs, isNull);
  });
  testWidgets('manual Save Now and timer cannot double submit', (tester) async {
    await mount(tester);
    await confirm(tester, result());
    await tester.tap(find.byKey(const Key('save-now')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(repo.creates, 1);
  });
  testWidgets('backgrounding pauses a pending auto-save', (tester) async {
    await mount(tester);
    await confirm(tester, result());
    c.pauseForBackground();
    await tester.pump(const Duration(seconds: 4));
    expect(repo.creates, 0);
    expect(c.phase, CapturePhase.review);
  });
  testWidgets('invalid reminder date enters review', (tester) async {
    await mount(tester);
    await confirm(
      tester,
      result(
        calls: [
          {
            'name': 'add_reminder',
            'arguments': {'title': 'Dentist', 'remind_at': 'banana'},
          },
        ],
      ),
    );
    expect(c.phase, CapturePhase.review);
    expect(c.current!.validationError, isNotNull);
  });
  testWidgets('benchmark reminder date resolves and saves UTC', (tester) async {
    await mount(tester);
    await confirm(
      tester,
      result(
        calls: [
          {
            'name': 'add_reminder',
            'arguments': {'title': 'Dentist', 'remind_at': 'tomorrow at 3pm'},
          },
        ],
      ),
    );
    expect(c.phase, CapturePhase.confirmation);
    await tester.tap(find.byKey(const Key('save-now')));
    await tester.pump();
    expect(repo.submitted!.dueDate!.isUtc, isTrue);
    expect(repo.submitted!.reminder!.triggerAt, repo.submitted!.dueDate);
  });
  testWidgets('Friday date-only explicitly reviews the 09:00 default', (
    tester,
  ) async {
    await mount(tester);
    await confirm(
      tester,
      result(
        calls: [
          {
            'name': 'add_task',
            'arguments': {'title': 'Fix login', 'due_date': 'Friday'},
          },
        ],
      ),
    );
    expect(c.phase, CapturePhase.review);
    expect(c.current!.reviewReason, contains('09:00'));
    expect(c.countdownMs, isNull);
  });
  testWidgets('filter chips and count badges select category', (tester) async {
    await repo.create(
      InboxItem(
        userId: repo.owner,
        type: 'task',
        title: 'Task one',
        redactedTranscript: 'Safe',
        createdAt: DateTime.now(),
      ),
    );
    await repo.create(
      InboxItem(
        userId: repo.owner,
        type: 'note',
        title: 'Note one',
        redactedTranscript: 'Safe',
        createdAt: DateTime.now(),
      ),
    );
    await mount(tester);
    expect(c.count('all'), 2);
    expect(find.text('Task one'), findsOneWidget);
    expect(find.text('Note one'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-task')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Task one'), findsOneWidget);
    expect(find.text('Note one'), findsNothing);
    await tester.tap(find.byKey(const Key('filter-reminder')));
    await tester.pump();
    expect(find.text('No reminders yet.'), findsOneWidget);
  });
  testWidgets('right swipe calls complete; left swipe calls delete', (
    tester,
  ) async {
    final item = await repo.create(
      InboxItem(
        userId: repo.owner,
        type: 'task',
        title: 'Swipe me',
        redactedTranscript: 'Safe',
        createdAt: DateTime.now(),
      ),
    );
    await mount(tester);
    await tester.drag(
      find.byKey(ValueKey('item-${item.id}')),
      const Offset(800, 0),
    );
    await tester.pumpAndSettle();
    expect(repo.completes, 1);
    expect(c.items.single.isCompleted, isTrue);
    await tester.drag(
      find.byKey(ValueKey('item-${item.id}')),
      const Offset(-800, 0),
    );
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(c.items, isEmpty);
  });
  testWidgets('failed delete retains item and explains failure', (
    tester,
  ) async {
    final item = await repo.create(
      InboxItem(
        userId: repo.owner,
        type: 'task',
        title: 'Keep me',
        redactedTranscript: 'Safe',
        createdAt: DateTime.now(),
      ),
    );
    repo.failDelete = true;
    await mount(tester);
    await tester.drag(
      find.byKey(ValueKey('item-${item.id}')),
      const Offset(-800, 0),
    );
    await tester.pumpAndSettle();
    expect(c.items.single.id, item.id);
    expect(c.error, isNotEmpty);
  });
  testWidgets('unconfirmed save retains local draft without automatic retry', (
    tester,
  ) async {
    repo.failCreate = true;
    await mount(tester);
    await confirm(tester, result());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(repo.creates, 1);
    expect(cache.drafts, hasLength(1));
    expect(c.phase, CapturePhase.review);
    await tester.pump(const Duration(seconds: 10));
    expect(repo.creates, 1);
  });
  testWidgets('recovered drafts never restart auto-save', (tester) async {
    await cache.saveDrafts([
      Draft(
        title: 'Recovered',
        type: 'task',
        originalTranscript: 'local raw',
        confidence: .9,
      ),
    ]);
    await mount(tester);
    expect(c.phase, CapturePhase.review);
    expect(c.countdownMs, isNull);
    await tester.pump(const Duration(seconds: 4));
    expect(repo.creates, 0);
  });
  testWidgets('320px feed and review fit without overflow', (tester) async {
    await mount(tester, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
    await confirm(tester, result(score: .01));
    expect(tester.takeException(), isNull);
  });
  test('client raw cache is account scoped', () async {
    await cache.putOriginal(7, 'private A');
    final other = LocalCache(cache.preferences, 'other-user');
    expect(other.original(7), isNull);
  });
  testWidgets(
    'detail edits persist and unchanged date precision is preserved',
    (tester) async {
      final date = DateTime.now().toUtc().add(
        const Duration(days: 1, milliseconds: 123),
      );
      final item = await repo.create(
        InboxItem(
          userId: repo.owner,
          type: 'task',
          title: 'Editable item',
          body: 'Body',
          priority: 'high',
          tags: ['work'],
          dueDate: date,
          redactedTranscript: 'Safe server text',
          createdAt: DateTime.now(),
        ),
      );
      await cache.putOriginal(item.id!, 'Raw stays here');
      await mount(tester);
      await tester.tap(find.text('Editable item'));
      await tester.pumpAndSettle();
      expect(find.text('Raw stays here'), findsOneWidget);
      expect(find.text('Safe server text'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('draft-title')),
        'Updated item',
      );
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.items.single.title, 'Updated item');
      expect(repo.items.single.dueDate, date);
      expect(c.items.single.id, item.id);
    },
  );
  testWidgets('detail can edit a fired reminder without moving its date', (
    tester,
  ) async {
    final date = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final item = await repo.create(
      InboxItem(
        userId: repo.owner,
        type: 'reminder',
        title: 'Past reminder',
        dueDate: date,
        redactedTranscript: 'Safe',
        createdAt: date,
        reminder: Reminder(
          inboxItemId: 0,
          triggerAt: date,
          recurring: 'none',
          isFired: true,
          createdAt: date,
        ),
      ),
    );
    await mount(tester);
    await tester.tap(find.text('Past reminder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('draft-title')),
      'Updated past reminder',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repo.items.single.title, 'Updated past reminder');
    expect(repo.items.single.dueDate, item.dueDate);
  });
  testWidgets('native multi-call batch advances one countdown at a time', (
    tester,
  ) async {
    await mount(tester);
    await c.acceptResult(
      result(
        calls: [
          {
            'name': 'add_shopping_item',
            'arguments': {'item': 'eggs'},
          },
          {
            'name': 'add_shopping_item',
            'arguments': {'item': 'milk'},
          },
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(repo.creates, 1);
    expect(c.current!.title, 'milk');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(repo.creates, 2);
    expect(c.pending, isEmpty);
  });
  testWidgets('keyboard-sized viewport and reduced motion keep review usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await c.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: triageTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 424),
            disableAnimations: true,
          ),
          child: InboxView(controller: c),
        ),
      ),
    );
    await c.acceptResult(result(score: .01));
    await tester.pump();
    expect(c.countdownMs, isNull);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('save-now')));
    expect(find.byKey(const Key('save-now')), findsOneWidget);
  });
  test('outgoing payload never serializes original transcript', () {
    const raw =
        'Email sarah@example.com at 123 Main Street, call +1 555 123 4567';
    final draft = Draft(
      title: raw,
      type: 'task',
      body: raw,
      tags: raw,
      originalTranscript: raw,
    );
    final json = draft.toItem(repo.owner).toJson();
    expect(json.containsKey('originalTranscript'), isFalse);
    expect(json['redactedTranscript'], contains('[EMAIL]'));
    expect(json['redactedTranscript'], contains('[ADDRESS]'));
    expect(json['redactedTranscript'], contains('[PHONE]'));
    expect(json['redactedTranscript'], isNot(contains('sarah@example.com')));
    expect(json['redactedTranscript'], isNot(contains('123 Main Street')));
    expect(json['redactedTranscript'], isNot(contains('+1 555')));
    expect(json['title'], contains('[EMAIL]'));
    expect(json['title'], contains('[ADDRESS]'));
    expect(json['title'], contains('[PHONE]'));
    expect(json['body'], isNot(contains('sarah@example.com')));
    expect((json['tags'] as List).join(', '), contains('[EMAIL]'));
    final full = redactKnownPii(
      'SSN 123-45-6789, card 4111 1111 1111 1111, home 42 Oak Street Apt 4',
    );
    expect(full, contains('[SSN]'));
    expect(full, contains('[CARD]'));
    expect(full, contains('[ADDRESS]'));
  });

  testWidgets(
    'audio transcript is scrubbed before funnel routing and reminder persistence',
    (tester) async {
      await mount(tester);
      const raw =
          'Remind me to email Sarah at sarah@example.com tomorrow at 3pm';
      voice.response = {'transcript': raw};
      await c.toggleRecording();
      await tester.pump();
      await c.toggleRecording();
      await tester.pump();
      expect(c.current!.originalTranscript, raw);
      expect(redactor.batches.first.first, raw);
      final expectedTrigger = c.current!.resolvedDate!.dateTime.toUtc();
      await c.saveCurrent();
      final sent = repo.submitted!;
      final saved = repo.items.single;
      expect(sent.redactedTranscript, contains('[EMAIL]'));
      expect(sent.title, isNot(contains('sarah@example.com')));
      expect(sent.reminder, isNotNull);
      expect(sent.reminder!.triggerAt.isAfter(DateTime.now()), isTrue);
      expect(reminders.scheduled[saved.id], sent.reminder!.triggerAt);
      expect(sent.reminder!.triggerAt, expectedTrigger);
      expect(cache.original(saved.id!), raw);
    },
  );

  testWidgets('completion and deletion cancel scheduled local reminder', (
    tester,
  ) async {
    await mount(tester);
    final date = DateTime.now().add(const Duration(days: 1));
    final item = await repo.create(
      InboxItem(
        userId: repo.owner,
        type: 'reminder',
        title: 'Call dentist',
        createdAt: DateTime.now(),
        dueDate: date,
        redactedTranscript: '[Transcript]',
        reminder: Reminder(
          inboxItemId: 0,
          triggerAt: date,
          recurring: 'none',
          isFired: false,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await c.acceptResult(result(score: .01));
    // Reconcile through the same event path used by a second signed-in client.
    expect(reminders.scheduled[item.id], date);
    await c.complete(item);
    expect(reminders.scheduled.containsKey(item.id), isFalse);
    final another = await repo.create(
      item.copyWith(id: null, isCompleted: false),
    );
    expect(reminders.scheduled.containsKey(another.id), isTrue);
    await c.delete(another);
    expect(reminders.scheduled.containsKey(another.id), isFalse);
  });

  testWidgets('failed on-device redaction never reaches repository', (
    tester,
  ) async {
    await mount(tester);
    redactor.fail = true;
    await c.acceptResult(result());
    await tester.pump();
    expect(c.phase, CapturePhase.review);
    expect(c.current!.reviewReason, contains('privacy check failed'));
    await c.saveCurrent();
    expect(repo.creates, 0);
    expect(c.error, contains('Nothing was sent'));
  });

  testWidgets(
    'two active inbox clients apply create, complete, and delete events',
    (tester) async {
      await mount(tester);
      final laptop = InboxController(
        repository: repo,
        cache: LocalCache(
          await SharedPreferences.getInstance(),
          '${repo.owner}-laptop',
        ),
        voice: FakeVoice(),
        reminders: FakeReminderScheduler(),
      );
      addTearDown(laptop.dispose);
      await laptop.initialize();
      final created = await repo.create(
        InboxItem(
          userId: repo.owner,
          type: 'task',
          title: 'Live from the phone',
          createdAt: DateTime.now(),
          redactedTranscript: '[Transcript]',
        ),
      );
      await tester.pump();
      expect(laptop.items.single.id, created.id);
      await repo.complete(created.id!);
      await tester.pump();
      expect(laptop.items.single.isCompleted, isTrue);
      await repo.delete(created.id!);
      await tester.pump();
      expect(laptop.items, isEmpty);
    },
  );
  test('multi-call candidates remain separate, no conjunction splitting', () {
    final drafts = parseVoiceResult(
      result(
        calls: [
          {
            'name': 'add_shopping_item',
            'arguments': {'item': 'eggs'},
          },
          {
            'name': 'add_shopping_item',
            'arguments': {'item': 'milk'},
          },
        ],
      ),
      DateTime.now(),
    );
    expect(drafts.map((d) => d.title), ['eggs', 'milk']);
    expect(drafts.every((d) => d.canAutoSave), isTrue);
  });
  test('malformed result safely becomes review draft', () {
    expect(
      parseVoiceResult({
        'routing': 'broken',
        'transcript': 123,
      }, DateTime.now()).single.canAutoSave,
      isFalse,
    );
  });
}
