import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_client/triage_client.dart';
import 'package:triage_flutter/actions/native_action_client.dart';
import 'package:triage_flutter/byok/byok_gateway.dart';
import 'package:triage_flutter/byok/byok_key_store.dart';
import 'package:triage_flutter/byok/llm_provider_adapter.dart';
import 'package:triage_flutter/demo/hackathon_demo_harness.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';
import 'package:triage_flutter/routines/local_routine_scheduler.dart';
import 'package:triage_flutter/telemetry/device_telemetry_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final mockKeys = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          final key = call.arguments['key'] as String?;
          switch (call.method) {
            case 'write':
              mockKeys[key!] = call.arguments['value'] as String;
              return null;
            case 'read':
              return mockKeys[key];
            case 'delete':
              mockKeys.remove(key);
              return null;
          }
          return null;
        },
      );

  group('Ticket 07: Core 4-Scene Hackathon Demo Verification Tests', () {
    late LocalOutboxRepository repository;
    late NativeActionClient actionClient;
    late LocalRoutineScheduler routineScheduler;
    late ByokKeyStore keyStore;
    late ByokGateway byokGateway;
    late DeviceTelemetryManager telemetryManager;
    late HackathonDemoHarness harness;
    final List<MethodCall> nativeCalls = [];

    setUp(() async {
      nativeCalls.clear();
      mockKeys.clear();
      repository = LocalOutboxRepository();
      final inMemoryDb = sqlite3.openInMemory();
      await repository.initialize(customDb: inMemoryDb);

      actionClient = NativeActionClient();
      routineScheduler = LocalRoutineScheduler(
        repository: repository,
        actionClient: actionClient,
      );
      keyStore = ByokKeyStore();
      await keyStore.saveApiKey(LlmProviderType.gemini, 'test-gemini-key');
      byokGateway = ByokGateway(keyStore: keyStore);
      telemetryManager = DeviceTelemetryManager(actionClient: actionClient);

      harness = HackathonDemoHarness(
        repository: repository,
        actionClient: actionClient,
        routineScheduler: routineScheduler,
        byokGateway: byokGateway,
        telemetryManager: telemetryManager,
      );

      // Mock Android native bridge
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/battery'),
            (MethodCall call) async {
              if (call.method == 'getBatteryLevel') {
                return 85;
              }
              if (call.method == 'getBatteryState') {
                return 'charging';
              }
              return null;
            },
          );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('triage.native_actions'),
            (MethodCall call) async {
              nativeCalls.add(call);
              switch (call.method) {
                case 'canScheduleExactAlarms':
                  return true;
                case 'scheduleExactAlarm':
                  return {
                    'status': 'success',
                    'action': 'schedule_exact_alarm',
                    'targetValue': call.arguments['epochMs'],
                    'executionLatencyMs': 5,
                  };
                case 'cancelExactAlarm':
                  return {'status': 'success', 'action': 'cancel_exact_alarm'};
                case 'setVolume':
                  return {
                    'status': 'success',
                    'action': 'set_volume',
                    'previousValue': 15,
                    'targetValue': call.arguments['percent'],
                    'executionLatencyMs': 10,
                  };
                case 'setBrightness':
                  return {
                    'status': 'success',
                    'action': 'set_brightness',
                    'previousValue': 40,
                    'targetValue': call.arguments['percent'],
                    'executionLatencyMs': 12,
                  };
                case 'setDoNotDisturb':
                  return {
                    'status': 'success',
                    'action': 'set_dnd',
                    'previousValue': 0,
                    'targetValue': call.arguments['enabled'] == true ? 1 : 0,
                    'executionLatencyMs': 14,
                  };
                case 'getVolume':
                  return {
                    'status': 'success',
                    'action': 'get_volume',
                    'targetValue': 25,
                    'executionLatencyMs': 6,
                  };
                case 'getBrightness':
                  return {
                    'status': 'success',
                    'action': 'get_brightness',
                    'targetValue': 60,
                    'executionLatencyMs': 8,
                  };
                case 'getDoNotDisturb':
                  return {
                    'status': 'success',
                    'action': 'get_dnd',
                    'targetValue': 0,
                    'executionLatencyMs': 7,
                  };
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('triage.native_actions'),
            null,
          );
      await repository.dispose();
    });

    test(
      'Scene 1: Airplane Mode offline commands execute locally and stage into SQLite',
      () async {
        final result = await harness.runScene1OfflineCommands();

        expect(result.isPassed, isTrue);
        expect(result.metrics['commandsExecuted'], equals(3));
        expect(result.metrics['sqliteOutboxAdded'], equals(3));
        expect(result.metrics['totalExecLatencyMs'], isNotNull);

        // Verify records are pending in SQLite
        final pendingEvents = await repository.getPendingSyncEvents();
        expect(pendingEvents.length, equals(3));
        expect(pendingEvents.every((e) => !e.isSynced), isTrue);

        // Verify native calls invoked setVolume, setBrightness, and setDoNotDisturb
        final methods = nativeCalls.map((c) => c.method).toList();
        expect(methods, contains('setVolume'));
        expect(methods, contains('setBrightness'));
        expect(methods, contains('setDoNotDisturb'));
      },
    );

    test(
      'Scene 2: Reconnect flushes pending outbox records to Serverpod deduplicated',
      () async {
        // First populate outbox via Scene 1
        await harness.runScene1OfflineCommands();

        final scene2Result = await harness.runScene2ReconnectAndSync(
          deviceId: 'registered-test-device',
          deviceToken: 'scoped-test-token',
          customSyncHandler: (batch) async {
            expect(batch.entries.length, equals(3));
            expect(batch.deviceId, isNotEmpty);
            return VoiceCommandSyncResult(
              syncedCount: 3,
              duplicateCount: 0,
              failedCount: 0,
              syncedEventIds: batch.entries.map((e) => e.eventId).toList(),
            );
          },
        );

        expect(scene2Result.isPassed, isTrue);
        expect(scene2Result.metrics['syncedCount'], equals(3));
        expect(scene2Result.metrics['remainingPending'], equals(0));

        // Verify SQLite reflects isSynced = true
        final remaining = await repository.getPendingSyncCount();
        expect(remaining, equals(0));
      },
    );

    test(
      'Scene 2 leaves events pending when no authenticated server is available',
      () async {
        await harness.runScene1OfflineCommands();

        final result = await harness.runScene2ReconnectAndSync();

        expect(result.isPassed, isFalse);
        expect(await repository.getPendingSyncCount(), equals(3));
      },
    );

    test(
      'Scene 3: Scheduled routine claims atomic occurrence and dispatches completed ACK',
      () async {
        final scene3Result = await harness.runScene3ScheduledRoutine(
          routineId: 'routine-meeting-prep',
          occurrenceId: 'occ-001',
        );

        expect(scene3Result.isPassed, isTrue);
        expect(scene3Result.metrics['routineStatus'], equals('completed'));
        expect(scene3Result.metrics['stepsCount'], equals(2));
        expect(scene3Result.metrics['duplicateSuppressed'], isTrue);

        // Verify routine record in SQLite has completed status
        final localRecord = await repository.getLocalRoutine(
          'routine-meeting-prep',
        );
        expect(localRecord, isNotNull);
        expect(localRecord!.status, equals('completed'));
      },
    );

    test(
      'Scene 4: BYOK conversational chat streams tokens while firewall blocks hardware bypass',
      () async {
        final mockHttpClient = MockClient((request) async {
          final body =
              '''data: {"candidates":[{"content":{"parts":[{"text":"Offline smart assistant "}]}}]}

data: {"candidates":[{"content":{"parts":[{"text":"architectures prioritize privacy and zero-latency execution."}]}}]}

''';
          return http.Response(
            body,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        });

        final scene4Result = await harness.runScene4ByokInteraction(
          httpClient: mockHttpClient,
        );

        expect(scene4Result.isPassed, isTrue);
        expect(scene4Result.metrics['provider'], equals('Google Gemini'));
        expect(scene4Result.metrics['firewallEnforced'], isTrue);
      },
    );

    test(
      'Diagnostic Telemetry captures live device status correctly',
      () async {
        final snapshot = await harness.telemetryManager.collectSnapshot();

        expect(snapshot.volumeLevel, equals(0.25));
        expect(snapshot.brightnessLevel, equals(0.60));
        expect(snapshot.dndEnabled, isFalse);
        expect(snapshot.batteryLevel, inInclusiveRange(0, 100));
      },
    );

    test(
      'End-to-End: Runs all 4 demo scenes sequentially without error',
      () async {
        final mockHttpClient = MockClient((request) async {
          final body =
              'data: {"candidates":[{"content":{"parts":[{"text":"All systems verified."}]}}]}\n\n';
          return http.Response(
            body,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        });

        final results = await harness.runAllScenes(
          httpClient: mockHttpClient,
          deviceId: 'registered-test-device',
          deviceToken: 'scoped-test-token',
          customSyncHandler: (batch) async => VoiceCommandSyncResult(
            syncedCount: batch.entries.length,
            duplicateCount: 0,
            failedCount: 0,
            syncedEventIds: batch.entries
                .map((entry) => entry.eventId)
                .toList(),
          ),
        );

        expect(results.length, equals(4));
        for (final sceneResult in results) {
          expect(
            sceneResult.isPassed,
            isTrue,
            reason:
                'Scene ${sceneResult.sceneNumber} (${sceneResult.title}) failed',
          );
        }
      },
    );
  });
}
