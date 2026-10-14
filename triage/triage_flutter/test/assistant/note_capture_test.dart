import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:triage_flutter/actions/native_action_client.dart';
import 'package:triage_flutter/assistant/offline_assistant_controller.dart';
import 'package:triage_flutter/notes/local_notes_repository.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';
import 'package:triage_flutter/voice/offline_voice_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('triage.offline_voice');
  late LocalNotesRepository notes;
  late LocalOutboxRepository outbox;
  late OfflineVoiceClient voice;
  late OfflineAssistantController assistant;
  final spoken = <String>[];
  var answer = 'idea';

  setUp(() async {
    spoken.clear();
    notes = LocalNotesRepository();
    await notes.initialize(customDb: sqlite3.openInMemory());
    outbox = LocalOutboxRepository();
    await outbox.initialize(customDb: sqlite3.openInMemory());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('triage.offline_voice_events'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'startListening') {
            expect(await notes.getNotes(), isEmpty);
            return {'status': 'success', 'transcript': answer};
          }
          if (call.method == 'speakOffline') {
            spoken.add((call.arguments as Map)['text'] as String);
            return {'status': 'success'};
          }
          return null;
        });
    voice = OfflineVoiceClient();
    assistant = OfflineAssistantController(
      voiceClient: voice,
      actionClient: NativeActionClient(),
      outboxRepository: outbox,
      notesRepository: notes,
    );
  });

  tearDown(() async {
    await notes.dispose();
    await outbox.dispose();
    voice.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final category in ['idea', 'note', 'reminder']) {
    test('asks category before saving exactly one $category', () async {
      answer = category;
      final result = await assistant.executeVoiceLoop(
        overrideTranscript: 'Take a note: Buy fresh bread',
      );
      expect(result.isSuccess, isTrue);
      final saved = await notes.getNotes();
      expect(saved, hasLength(1));
      expect(saved.single.category, category);
      expect(saved.single.content.toLowerCase(), 'buy fresh bread');
      expect(spoken, [
        'Is this an idea, note, or reminder?',
        'Saved to ${category}s.',
      ]);
    });
  }

  test('unknown category does not silently save a note', () async {
    answer = 'something else';
    final result = await assistant.executeVoiceLoop(
      overrideTranscript: 'Remember to fix the garage door',
    );
    expect(result.isSuccess, isFalse);
    expect(await notes.getNotes(), isEmpty);
  });
}
