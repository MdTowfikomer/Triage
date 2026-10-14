import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triage_flutter/ui/assist_home.dart';
import 'package:triage_flutter/ui/components/illustrated_cat.dart';
import 'package:triage_flutter/ui/theme.dart';

void main() {
  testWidgets('Assist remains usable at large text and reduced motion', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: triageTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: AssistHome(
            catState: CatState.idle,
            status: 'Ready to help',
            pendingSync: 4,
            favorites: const ['Open WhatsApp', 'Set a timer', 'Set volume'],
            onSpeak: () => tapped = true,
            onShortcut: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.byType(IllustratedCat), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Speak to Triage'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
