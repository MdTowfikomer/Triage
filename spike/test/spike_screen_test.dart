import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triage_spike/main.dart';

void main() {
  testWidgets('tap toggles recording and passes stopped audio to the bridge', (
    tester,
  ) async {
    final actions = <String>[];
    Future<String> fake(String request) async {
      final action = (jsonDecode(request) as Map)['action'] as String;
      actions.add(action);
      return jsonEncode({'transcript': action == 'stop' ? 'buy milk' : ''});
    }

    await tester.pumpWidget(SpikeApp(invoke: fake));
    await tester.pumpAndSettle();
    final initialRecord = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Record'),
    );
    expect(initialRecord.onPressed, isNull);
    await tester.tap(find.text('Initialize models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Stop recording'), findsOneWidget);
    final silence = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Inject mock audio (silence)'),
    );
    expect(silence.onPressed, isNull);
    await tester.tap(find.text('Stop recording'));
    await tester.pumpAndSettle();
    expect(actions, ['init', 'start', 'stop']);
    expect(find.text('Record'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('raw-result')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final raw =
        tester.widget<SelectableText>(find.byKey(const Key('raw-result')));
    expect(raw.data, contains('buy milk'));
  });

  testWidgets(
    'microphone denial leaves capture retryable and fixture available',
    (tester) async {
      Future<String> fake(String request) async {
        if ((jsonDecode(request) as Map)['action'] == 'start') {
          throw Exception('Microphone permission denied');
        }
        return '{}';
      }

      await tester.pumpWidget(SpikeApp(invoke: fake));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Initialize models'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Microphone permission denied'),
        findsOneWidget,
      );
      expect(find.text('Stop recording'), findsNothing);
      final record = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Record'),
      );
      expect(record.onPressed, isNotNull);
      final silence = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Inject mock audio (silence)'),
      );
      expect(silence.onPressed, isNotNull);
    },
  );
}
