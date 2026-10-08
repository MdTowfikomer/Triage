import 'dart:async';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:test/test.dart';
import 'package:triage_server/server.dart';
import 'package:triage_server/src/endpoints/sync_endpoint.dart';
import 'package:triage_server/src/generated/protocol.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Authenticated voice action funnel', (builder, endpoints) {
    late TestSessionBuilder owner, other;
    late UuidValue user;
    setUp(() async {
      final db = builder.build();
      configureAuthentication(db.serverpod);
      user = (await AuthServices.instance.authUsers.create(db)).id;
      final second = (await AuthServices.instance.authUsers.create(db)).id;
      owner = builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          user.toString(),
          {},
        ),
      );
      other = builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          second.toString(),
          {},
        ),
      );
    });
    test(
      'unauthenticated voice routing is rejected by generated dispatch',
      () async {
        await expectLater(
          endpoints.voice.routeVoice(builder, 'Open WhatsApp'),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      },
    );
    test(
      'routing does not persist an item or broadcast an unapproved capture',
      () async {
        final action = await endpoints.voice.routeVoice(owner, 'Buy milk');
        expect(action.tool, 'add_shopping_item');
        expect(action.title, 'Milk');
        expect(await endpoints.inbox.listItems(owner), isEmpty);
        expect(await endpoints.inbox.listItems(other), isEmpty);
        final json = action.toJson();
        expect(json.containsKey('originalTranscript'), isFalse);
        expect(json.containsKey('userId'), isFalse);
      },
    );
    test('approved routed card persists and syncs only to its owner', () async {
      final action = await endpoints.voice.routeVoice(
        owner,
        'Fix the login bug by Friday, high priority',
      );
      final received = Completer<InboxEvent>();
      final stream = SyncEndpoint().streamInbox(owner.build()).listen((event) {
        if (!received.isCompleted) received.complete(event);
      });
      try {
        final saved = await endpoints.inbox.createItem(
          owner,
          InboxItem(
            userId: user,
            type: action.category,
            title: action.title,
            priority: action.priority,
            redactedTranscript: 'Fix the login bug by Friday, high priority',
            createdAt: DateTime.now().toUtc(),
            confidence: action.confidence,
          ),
        );
        expect(
          (await received.future.timeout(const Duration(seconds: 5))).itemId,
          saved.id,
        );
        expect(
          (await endpoints.inbox.listItems(owner)).single.title,
          'Fix the login bug',
        );
        expect(await endpoints.inbox.listItems(other), isEmpty);
      } finally {
        await stream.cancel();
      }
    });
    test(
      'open_app is a response for the phone, never an inbox mutation',
      () async {
        final action = await endpoints.voice.routeVoice(owner, 'Open WhatsApp');
        expect(action.actionType, 'device_action');
        expect(action.appName, 'whatsapp');
        expect(await endpoints.inbox.listItems(owner), isEmpty);
      },
    );
  });
}
