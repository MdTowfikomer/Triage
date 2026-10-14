import 'dart:async';
import 'package:flutter/material.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_client/triage_client.dart';
import 'core/redact.dart';
import 'data/inbox_repository.dart';
import 'data/local_cache.dart';
import 'data/voice_action_router.dart';
import 'notifications/reminder_scheduler.dart';
import 'state/inbox_controller.dart';
import 'ui/auth_view.dart';
import 'ui/inbox_view.dart';
import 'ui/triage_app_shell.dart';
import 'ui/offline_voice_spike_screen.dart';
import 'ui/theme.dart';
import 'voice/voice_factory.dart';

const demoMode = bool.fromEnvironment('TRIAGE_DEMO');
const voiceSpikeMode = bool.fromEnvironment(
  'TRIAGE_VOICE_SPIKE',
  defaultValue: true,
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client =
      Client(
          const String.fromEnvironment(
            'SERVER_URL',
            defaultValue: 'https://triage.api.serverpod.space/',
          ),
        )
        ..connectivityMonitor = FlutterConnectivityMonitor()
        ..authSessionManager = FlutterAuthSessionManager();
  if (const bool.fromEnvironment('TRIAGE_COOKIE_AUTH')) {
    client.cookieAuth = true;
  }
  final prefs = await SharedPreferences.getInstance();
  if (!demoMode) await client.auth.initialize();
  if (voiceSpikeMode) {
    runApp(
      MaterialApp(
        title: 'Triage — Offline Voice Assistant',
        debugShowCheckedModeBanner: false,
        theme: triageTheme(),
        home: TriageAppShell(serverpodClient: client),
      ),
    );
    return;
  }
  runApp(TriageApp(client: client, preferences: prefs, demo: demoMode));
}

class TriageApp extends StatelessWidget {
  const TriageApp({
    super.key,
    required this.client,
    required this.preferences,
    this.demo = false,
  });
  final Client client;
  final SharedPreferences preferences;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Triage',
      debugShowCheckedModeBanner: false,
      theme: triageTheme(),
      home: voiceSpikeMode
          ? const OfflineVoiceSpikeScreen()
          : (demo
                ? _InboxMount(
                    client: client,
                    preferences: preferences,
                    demo: true,
                  )
                : ValueListenableBuilder<AuthSuccess?>(
                    valueListenable: client.auth.authInfoListenable,
                    builder: (context, auth, child) => auth == null
                        ? AuthView(client: client)
                        : _InboxMount(
                            key: ValueKey(auth.authUserId),
                            client: client,
                            preferences: preferences,
                            owner: auth.authUserId,
                          ),
                  )),
      routes: {'/voice_spike': (context) => const OfflineVoiceSpikeScreen()},
    );
  }
}

class _InboxMount extends StatefulWidget {
  const _InboxMount({
    super.key,
    required this.client,
    required this.preferences,
    this.owner,
    this.demo = false,
  });
  final Client client;
  final SharedPreferences preferences;
  final UuidValue? owner;
  final bool demo;
  @override
  State<_InboxMount> createState() => _InboxMountState();
}

class _InboxMountState extends State<_InboxMount> {
  late final InboxRepository repository = widget.demo
      ? DemoInboxRepository()
      : ServerInboxRepository(widget.client, widget.owner!);
  late final InboxController controller = InboxController(
    repository: repository,
    cache: LocalCache(
      widget.preferences,
      widget.demo ? 'demo' : repository.owner.toString(),
    ),
    voice: createVoiceEngine(),
    reminders: LocalReminderScheduler(),
    redactor: DesertAntPayloadRedactor(),
    actionRouter: widget.demo ? null : ServerVoiceActionRouter(widget.client),
  );
  @override
  void initState() {
    super.initState();
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    controller.dispose();
    if (repository is DemoInboxRepository) {
      unawaited((repository as DemoInboxRepository).dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InboxView(
    controller: controller,
    demo: widget.demo,
    onSignOut: widget.demo ? null : () => widget.client.auth.signOutDevice(),
  );
}
