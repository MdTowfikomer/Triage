import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:triage_client/triage_client.dart';
import 'package:triage_flutter/ui/auth_view.dart';
import 'package:triage_flutter/ui/theme.dart';

class MemoryAuthStorage implements ClientAuthSuccessStorage {
  AuthSuccess? value;
  @override
  Future<AuthSuccess?> get() async => value;
  @override
  Future<void> set(AuthSuccess? data) async {
    value = data;
  }
}

void main() {
  late Client client;
  late MemoryAuthStorage storage;
  late List<(String, Map<String, dynamic>)> requests;
  late AuthSuccess success;
  bool reject = false;
  setUp(() {
    requests = [];
    storage = MemoryAuthStorage();
    reject = false;
    success = AuthSuccess(
      authStrategy: 'session',
      token: 'test-session-token',
      authUserId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
      scopeNames: {},
    );
    client = Client(
      'http://unit.test/',
      httpClientOverride: MockClient((request) async {
        final method = request.url.path.split('/').last;
        requests.add((
          method,
          Map<String, dynamic>.from(jsonDecode(request.body) as Map),
        ));
        if (reject) return http.Response('', 401);
        final Object? response = switch (method) {
          'login' || 'finishRegistration' => success.toJsonForProtocol(),
          'startRegistration' ||
          'startPasswordReset' => '00000000-0000-4000-8000-000000000002',
          'verifyRegistrationCode' => 'registration-token',
          'verifyPasswordResetCode' => 'reset-token',
          'isSignedIn' => true,
          _ => null,
        };
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..authSessionManager = FlutterAuthSessionManager(storage: storage);
  });
  tearDown(() => client.close());
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: triageTheme(),
        home: AuthView(client: client),
      ),
    );
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'me@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'a long passphrase',
    );
  }

  testWidgets(
    'email/password login uses generated emailIdp and persists auth',
    (tester) async {
      await mount(tester);
      await fill(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(requests.single.$1, 'login');
      expect(requests.single.$2['email'], 'me@example.com');
      expect(requests.single.$2['password'], 'a long passphrase');
      expect(storage.value!.authUserId, success.authUserId);
      expect(client.auth.isAuthenticated, isTrue);
    },
  );
  testWidgets('registration completes official code verification flow', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();
    await fill(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email.'), findsOneWidget);
    expect(requests.single.$1, 'startRegistration');
    await tester.enterText(find.byKey(const Key('auth-code')), '123456');
    await tester.tap(find.text('Verify and sign in'));
    await tester.pumpAndSettle();
    expect(requests.map((r) => r.$1), [
      'startRegistration',
      'verifyRegistrationCode',
      'finishRegistration',
    ]);
    expect(storage.value, isNotNull);
  });
  testWidgets('invalid login validates inline without network request', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(requests, isEmpty);
  });
  testWidgets('rejected auth preserves input and displays safe error', (
    tester,
  ) async {
    reject = true;
    await mount(tester);
    await fill(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
    expect(find.textContaining('Check your details'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('auth-email')))
          .controller!
          .text,
      'me@example.com',
    );
  });
  testWidgets('password reveal is available and does not clear it', (
    tester,
  ) async {
    await mount(tester);
    await fill(tester);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('auth-password')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isFalse,
    );
  });
  testWidgets('password reset uses official IDP endpoints', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'me@example.com',
    );
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-code')), '123456');
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'a new passphrase',
    );
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(requests.map((r) => r.$1), [
      'startPasswordReset',
      'verifyPasswordResetCode',
      'finishPasswordReset',
    ]);
    expect(requests.last.$2['newPassword'], 'a new passphrase');
    expect(find.text('Sign in'), findsOneWidget);
  });
  test('session manager restores and validates persisted identity', () async {
    storage.value = success;
    await client.auth.initialize();
    expect(client.auth.authInfo!.authUserId, success.authUserId);
    expect(requests.single.$1, 'isSignedIn');
    await client.auth.signOutDevice();
    expect(storage.value, isNull);
    expect(client.auth.isAuthenticated, isFalse);
  });
  testWidgets('auth stays usable at 320px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
