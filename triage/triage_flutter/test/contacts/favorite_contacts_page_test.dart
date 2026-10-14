import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_flutter/contacts/favorite_contacts_repository.dart';
import 'package:triage_flutter/ui/favorite_contacts_page.dart';

void main() {
  const channel = MethodChannel('triage.native_actions');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('manual Save adds the first pinned contact', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = FavoriteContactsRepository(
      await SharedPreferences.getInstance(),
    );
    await tester.pumpWidget(MaterialApp(
      home: FavoriteContactsPage(repository: repository),
    ));
    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Demo Contact');
    await tester.enterText(find.byType(TextField).at(1), '+911234567890');
    await tester.ensureVisible(find.text('Save contact'));
    await tester.tap(find.text('Save contact'));
    await tester.pumpAndSettle();
    expect(repository.getAll().single.displayName, 'Demo Contact');
    expect(find.text('Demo Contact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native picker selection adds the first pinned contact', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = FavoriteContactsRepository(
      await SharedPreferences.getInstance(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pickContact');
      return {'status': 'selected', 'name': 'Picked Contact', 'phone': '+911234567891'};
    });
    await tester.pumpWidget(MaterialApp(
      home: FavoriteContactsPage(repository: repository),
    ));
    await tester.tap(find.text('Pick from contacts'));
    await tester.pumpAndSettle();
    expect(repository.getAll().single.phoneNumber, '+911234567891');
    expect(find.text('Picked Contact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
