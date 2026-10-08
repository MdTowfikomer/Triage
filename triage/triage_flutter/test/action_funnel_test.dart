import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_client/triage_client.dart';
import 'package:triage_flutter/core/app_launcher.dart';
import 'package:triage_flutter/data/local_cache.dart';
import 'package:triage_flutter/data/voice_action_router.dart';
import 'package:triage_flutter/state/inbox_controller.dart';
import 'package:triage_flutter/ui/inbox_view.dart';
import 'package:triage_flutter/ui/theme.dart';
import 'ui_test.dart' show TestRepository, FakeVoice, FakePayloadRedactor;

VoiceActionResult task({double score = .85}) => VoiceActionResult(
  actionType: 'inbox_item',
  tool: 'add_task',
  title: 'Email Sarah',
  category: 'task',
  priority: 'medium',
  confidence: score,
  latencyMs: 12,
);

class FakeRouter implements VoiceActionRouter {
  VoiceActionResult response = task();
  final transcripts = <String>[];
  bool fail = false;
  Completer<VoiceActionResult>? waiting;
  @override
  Future<VoiceActionResult> route(String sanitizedTranscript) async {
    transcripts.add(sanitizedTranscript);
    if (fail) throw StateError('Offline');
    return waiting == null ? response : await waiting!.future;
  }
}

class FakeAppLauncher implements AppLauncher {
  final launched = <String>[];
  bool available = true;
  @override
  Future<bool> launch(String appName) async {
    launched.add(appName);
    return available;
  }
}

void main() {
  late InboxController controller;
  late TestRepository repo;
  late LocalCache cache;
  late FakeRouter router;
  late FakeVoice voice;
  late FakeAppLauncher launcher;
  late FakePayloadRedactor redactor;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = TestRepository();
    cache = LocalCache(
      await SharedPreferences.getInstance(),
      repo.owner.toString(),
    );
    router = FakeRouter();
    voice = FakeVoice();
    launcher = FakeAppLauncher();
    redactor = FakePayloadRedactor();
    controller = InboxController(
      repository: repo,
      cache: cache,
      voice: voice,
      actionRouter: router,
      appLauncher: launcher,
      redactor: redactor,
    );
  });
  tearDown(() async {
    controller.dispose();
    await repo.dispose();
  });
  Future<void> mount(WidgetTester tester) async {
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: triageTheme(),
        home: InboxView(controller: controller),
      ),
    );
  }

  testWidgets('backgrounding during inference blocks autosave and app launch', (
    tester,
  ) async {
    await mount(tester);
    router.waiting = Completer<VoiceActionResult>();
    final capture = controller.captureText('Email Sarah');
    for (var i = 0; i < 10 && router.transcripts.isEmpty; i++) {
      await tester.pump();
    }
    controller.pauseForBackground();
    router.waiting!.complete(task());
    await capture;
    expect(controller.phase, CapturePhase.review);
    expect(controller.countdownMs, isNull);
    await tester.pump(const Duration(seconds: 4));
    expect(repo.creates, 0);
    controller.resumeFromBackground();
    await controller.cancel();
    router.transcripts.clear();
    router.waiting = Completer<VoiceActionResult>();
    final appCapture = controller.captureText('Open WhatsApp');
    for (var i = 0; i < 10 && router.transcripts.isEmpty; i++) {
      await tester.pump();
    }
    controller.pauseForBackground();
    router.waiting!.complete(
      task().copyWith(
        actionType: 'device_action',
        tool: 'open_app',
        appName: 'whatsapp',
      ),
    );
    await appCapture;
    expect(launcher.launched, isEmpty);
    expect(controller.phase, CapturePhase.review);
  });

  testWidgets('Whistle result bypasses Needle routing and calls the backend', (
    tester,
  ) async {
    await mount(tester);
    voice.response = {
      'transcript': 'Email Sarah about the proposal',
      'routing': {
        'parsed': {
          'function_calls': [
            {
              'name': 'open_app',
              'arguments': {'appName': 'browser'},
            },
          ],
        },
      },
    };
    await controller.toggleRecording();
    await controller.toggleRecording();
    expect(router.transcripts, ['Email Sarah about the proposal']);
    expect(controller.current!.title, 'Email Sarah');
    expect(controller.phase, CapturePhase.confirmation);
    expect(launcher.launched, isEmpty);
  });
  testWidgets('PII is scrubbed before routing and again before persistence', (
    tester,
  ) async {
    await mount(tester);
    const raw =
        'Email sarah@example.com at 123 Main Street, phone +1 415 555 2671';
    router.response = task().copyWith(title: 'Email sarah@example.com');
    await controller.routeTranscript(raw);
    expect(router.transcripts.single, contains('[EMAIL]'));
    expect(router.transcripts.single, contains('[ADDRESS]'));
    expect(router.transcripts.single, contains('[PHONE]'));
    expect(router.transcripts.single, isNot(contains('sarah@example.com')));
    expect(cache.drafts.single.originalTranscript, raw);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(repo.creates, 1);
    expect(repo.submitted!.title, 'Email [EMAIL]');
    expect(repo.submitted!.redactedTranscript, router.transcripts.single);
    expect(cache.original(repo.items.single.id!), raw);
  });
  testWidgets('Edit cancels a server-routed card countdown', (tester) async {
    await mount(tester);
    await controller.routeTranscript('Email Sarah');
    controller.edit();
    await tester.pump(const Duration(seconds: 4));
    expect(controller.phase, CapturePhase.review);
    expect(controller.current!.title, isNotEmpty);
    expect(repo.creates, 0);
    expect(controller.countdownMs, isNull);
  });
  testWidgets('low confidence shows a populated form and one Save button', (
    tester,
  ) async {
    await mount(tester);
    router.response = task(score: .05);
    await controller.routeTranscript('Email Sarah');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.phase, CapturePhase.review);
    expect(controller.current!.title, 'Email Sarah');
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save Now'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(repo.creates, 0);
  });
  testWidgets('offline routing preserves shopping slots without Needle', (
    tester,
  ) async {
    await mount(tester);
    router.fail = true;
    await controller.captureText('Buy 3 bananas from Whole Foods');
    expect(controller.current!.type, 'shopping');
    expect(controller.current!.title, 'Bananas');
    expect(controller.current!.body, 'Quantity: 3 · Store: Whole Foods');
    expect(controller.current!.priority, 'medium');
    expect(voice.started, isFalse);
    controller.edit();
  });
  testWidgets(
    'clear device action launches immediately without an inbox write',
    (tester) async {
      await mount(tester);
      router.response = task().copyWith(
        actionType: 'device_action',
        tool: 'open_app',
        appName: 'whatsapp',
        title: 'Open WhatsApp',
      );
      await controller.captureText('Open WhatsApp');
      expect(launcher.launched, ['whatsapp']);
      expect(controller.phase, CapturePhase.idle);
      expect(controller.status, 'Launching WhatsApp…');
      expect(cache.drafts, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      expect(repo.creates, 0);
    },
  );
  testWidgets('backend cannot authorize an unrequested app launch', (
    tester,
  ) async {
    await mount(tester);
    router.response = task().copyWith(
      actionType: 'device_action',
      tool: 'open_app',
      appName: 'browser',
    );
    await controller.captureText('Fix login');
    expect(launcher.launched, isEmpty);
    expect(controller.phase, CapturePhase.review);
    expect(controller.current!.title, 'Fix login');
    expect(controller.countdownMs, isNull);
  });
  testWidgets('uninstalled app leaves a populated review card', (tester) async {
    await mount(tester);
    router.fail = true;
    launcher.available = false;
    await controller.captureText('Open WhatsApp');
    expect(launcher.launched, ['whatsapp']);
    expect(controller.phase, CapturePhase.review);
    expect(controller.current!.title, 'Open whatsapp');
    expect(controller.current!.reviewReason, contains('unavailable'));
    expect(controller.countdownMs, isNull);
  });
  testWidgets('privacy failure prevents both server inference and app launch', (
    tester,
  ) async {
    await mount(tester);
    redactor.fail = true;
    await controller.captureText('Open WhatsApp');
    expect(router.transcripts, isEmpty);
    expect(launcher.launched, isEmpty);
    expect(controller.phase, CapturePhase.review);
    expect(repo.creates, 0);
    expect(controller.current!.title, isNotEmpty);
  });
  testWidgets('late routing result cannot resurrect a cancelled capture', (
    tester,
  ) async {
    await mount(tester);
    router.waiting = Completer<VoiceActionResult>();
    final capture = controller.captureText('Email Sarah');
    for (var i = 0; i < 10 && router.transcripts.isEmpty; i++) {
      await tester.pump();
    }
    expect(router.transcripts, hasLength(1));
    await controller.cancel();
    router.waiting!.complete(task());
    await capture;
    expect(controller.phase, CapturePhase.idle);
    expect(controller.pending, isEmpty);
    expect(repo.creates, 0);
  });
  testWidgets(
    'relative reminder date resolves against the captured device clock',
    (tester) async {
      await mount(tester);
      router.response = task().copyWith(
        tool: 'add_reminder',
        category: 'reminder',
        title: 'Call dentist',
        dateText: 'tomorrow at 3pm',
      );
      final reference = DateTime.now();
      await controller.routeTranscript(
        'Remind me to call dentist tomorrow at 3pm',
        reference: reference,
      );
      expect(
        controller.current!.resolvedDate!.dateTime,
        DateTime(reference.year, reference.month, reference.day + 1, 15),
      );
      expect(controller.phase, CapturePhase.confirmation);
      controller.edit();
    },
  );
  testWidgets(
    'empty and mixed captures never show a blank or autosaving form',
    (tester) async {
      await mount(tester);
      router.fail = true;
      for (final text in [
        '',
        'Um, so, email Sarah about the proposal, and oh, grab milk',
      ]) {
        await controller.captureText(text);
        expect(controller.current!.title, isNotEmpty);
        expect(controller.current!.priority, 'medium');
        expect(controller.phase, CapturePhase.review);
        expect(controller.countdownMs, isNull);
        await controller.cancel();
      }
    },
  );
}
