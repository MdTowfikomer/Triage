import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:triage_client/triage_client.dart';
import '../actions/action_result.dart';
import '../actions/native_action_client.dart';
import '../assistant/offline_assistant_controller.dart';
import '../byok/byok_gateway.dart';
import '../byok/byok_key_store.dart';
import '../outbox/local_outbox_repository.dart';
import '../outbox/outbox_event.dart';
import '../outbox/outbox_sync_manager.dart';
import '../contacts/favorite_contacts_repository.dart';
import '../voice/offline_voice_client.dart';
import 'components/illustrated_cat.dart';
import 'assist_home.dart';
import 'components/byok_card.dart';
import 'offline_voice_spike_screen.dart';
import 'auth_view.dart';
import 'favorite_contacts_page.dart';
import 'favorite_apps_page.dart';
import 'notes_page.dart';
import '../notes/local_notes_repository.dart';
import '../actions/favorite_apps_repository.dart';
import 'components/assistant_overlay_sheet.dart';
import 'components/command_guide_modal.dart';
import 'voice_session_page.dart';

/// The unified 4-destination application shell for Triage:
/// 1. Assist — Expressive Braille ASCII Cat hero, truthful status, voice glow modal sheet, favorites
/// 2. Activity — Local outbox actions & sync event timeline
/// 3. Routines — Offline scheduled routines & execution reports
/// 4. Settings — Offline assets, permissions, BYOK (Groq, Gemini, Claude), and Diagnostics
class TriageAppShell extends StatefulWidget {
  const TriageAppShell({super.key, required this.serverpodClient});

  final Client serverpodClient;

  @override
  State<TriageAppShell> createState() => _TriageAppShellState();
}

class _TriageAppShellState extends State<TriageAppShell> {
  int _selectedTabIndex = 0;

  final OfflineVoiceClient _client = OfflineVoiceClient();
  final NativeActionClient _actionClient = NativeActionClient();
  late final LocalOutboxRepository _outboxRepo;
  late final LocalNotesRepository _notesRepo;
  late final OfflineAssistantController _assistantController;
  late final ByokKeyStore _byokKeyStore;
  late final FavoriteContactsRepository _favoriteContacts;
  late final FavoriteAppsRepository _favoriteApps;
  late final ByokGateway _byokGateway;
  late final SharedPreferences _preferences;
  OutboxSyncManager? _syncManager;

  List<OutboxEvent> _recentOutboxEvents = [];
  AssistantLoopResult? _lastLoopResult;
  bool _isListening = false;

  CatState _catState = CatState.idle;
  String _statusLine = 'Ready to help';
  int _pendingSyncCount = 0;
  bool _isAccountBusy = false;
  String? _accountMessage;
  bool _servicesReady = false;
  bool _backgroundShakeEnabled = false;
  bool _backgroundShakeBusy = false;

  final List<String> _favoriteShortcuts = [
    'Open WhatsApp',
    'Call Ammi',
    'WhatsApp Ammi: I am on the way',
    'Start navigation to Home',
    'Open YouTube',
    'Set volume to 50%',
    'Set a timer for 5 minutes',
    'Turn on do not disturb',
  ];

  @override
  void initState() {
    super.initState();
    _initCoreServices();
  }

  Future<void> _initCoreServices() async {
    _outboxRepo = LocalOutboxRepository();
    await _outboxRepo.initialize();

    _notesRepo = LocalNotesRepository();
    await _notesRepo.initialize();

    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    _backgroundShakeEnabled =
        prefs.getBool('background_shake_enabled') ?? false;
    _favoriteContacts = FavoriteContactsRepository(prefs);
    _favoriteApps = FavoriteAppsRepository(prefs);

    _assistantController = OfflineAssistantController(
      voiceClient: _client,
      actionClient: _actionClient,
      outboxRepository: _outboxRepo,
      favoriteContacts: _favoriteContacts,
      favoriteApps: _favoriteApps,
      notesRepository: _notesRepo,
    );
    _syncManager = OutboxSyncManager(
      repository: _outboxRepo,
      preferences: prefs,
    );
    _syncManager!.startAutoSync(
      widget.serverpodClient,
      getCurrentUserId: () => widget
          .serverpodClient
          .auth
          .authInfoListenable
          .value
          ?.authUserId
          .toString(),
      onSyncCompleted: (_) => _refreshOutbox(),
    );

    _byokKeyStore = ByokKeyStore();
    _byokGateway = ByokGateway(keyStore: _byokKeyStore);

    if (_backgroundShakeEnabled) {
      final permission = await Permission.notification.status;
      final enabled =
          permission.isGranted &&
          await _actionClient.setBackgroundShakeEnabled(true);
      if (!enabled) {
        await _actionClient.setBackgroundShakeEnabled(false);
        _backgroundShakeEnabled = false;
        await prefs.setBool('background_shake_enabled', false);
      }
    }

    _actionClient.startShakeDetection(
      onShaken: () {
        if (!_isListening) {
          _actionClient.triggerHapticFeedback(type: 'medium');
          _openVoiceFullScreen();
        }
      },
      onBackgroundShake: () {
        if (!_isListening) _openVoiceListeningSheet();
      },
    );

    await _refreshOutbox();
    if (mounted) setState(() => _servicesReady = true);
  }

  Future<void> _refreshOutbox() async {
    final events = await _outboxRepo.getRecentEvents(limit: 50);
    final pending = await _outboxRepo.getPendingSyncEvents();
    if (mounted) {
      setState(() {
        _recentOutboxEvents = events;
        _pendingSyncCount = pending.length;
      });
    }
  }

  Future<void> _setBackgroundShakeEnabled(bool enabled) async {
    if (_backgroundShakeBusy || enabled == _backgroundShakeEnabled) return;
    setState(() => _backgroundShakeBusy = true);
    if (enabled && !await Permission.systemAlertWindow.isGranted) {
      final overlay = await Permission.systemAlertWindow.request();
      if (!overlay.isGranted) {
        if (mounted) {
          setState(() => _backgroundShakeBusy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Allow Display over other apps so a shake can open the assistant card.',
              ),
            ),
          );
        }
        return;
      }
    }
    var success = !enabled;
    if (enabled) {
      final permission = await Permission.notification.request();
      success =
          permission.isGranted &&
          await _actionClient.setBackgroundShakeEnabled(true);
    } else {
      success = await _actionClient.setBackgroundShakeEnabled(false);
    }
    if (success)
      await _preferences.setBool('background_shake_enabled', enabled);
    if (!mounted) return;
    setState(() {
      _backgroundShakeEnabled = success ? enabled : false;
      _backgroundShakeBusy = false;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow notifications to use background shake access.'),
        ),
      );
    }
  }

  Future<void> _registerAndSync() async {
    final manager = _syncManager;
    final userId = widget
        .serverpodClient
        .auth
        .authInfoListenable
        .value
        ?.authUserId
        .toString();
    if (manager == null || userId == null || _isAccountBusy) return;
    setState(() {
      _isAccountBusy = true;
      _accountMessage = null;
    });
    try {
      await manager.checkAccountAndInvalidateIfChanged(userId);
      if (!manager.isRegistered) {
        await manager.registerDevice(widget.serverpodClient, userId: userId);
      }
      final result = await manager.syncPendingEvents(
        widget.serverpodClient,
        currentUserId: userId,
      );
      await _refreshOutbox();
      if (mounted) {
        setState(
          () => _accountMessage =
              'Synced ${result.syncedCount} actions; ${result.duplicateCount} already present.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _accountMessage =
              'Could not sync. Check your connection and account, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAccountBusy = false);
    }
  }

  @override
  void dispose() {
    _actionClient.stopShakeDetection();
    _syncManager?.dispose();
    super.dispose();
  }

  void _openVoiceListeningSheet({String? initialTranscript}) {
    if (_isListening) return;
    setState(() => _isListening = true);
    _actionClient.triggerHapticFeedback(type: 'medium');
    AssistantOverlaySheet.show(
      context,
      assistant: _assistantController,
      voice: _client,
      keyStore: _byokKeyStore,
      initialTranscript: initialTranscript,
      onCommandResult: (AssistantLoopResult res) {
        if (!mounted) return;
        setState(() {
          _lastLoopResult = res;
          _catState = res.isSuccess
              ? CatState.success
              : res.actionResult?.status == ActionStatus.permissionRequired
              ? CatState.permissionRequired
              : CatState.error;
          _statusLine = res.errorMessage ?? res.spokenFeedback;
        });
        _refreshOutbox();
      },
    ).whenComplete(() {
      if (mounted) setState(() => _isListening = false);
    });
  }

  void _openVoiceFullScreen({String? initialTranscript}) {
    if (_isListening) return;
    setState(() => _isListening = true);
    _actionClient.triggerHapticFeedback(type: 'medium');
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => VoiceSessionPage(
              assistant: _assistantController,
              voice: _client,
              keyStore: _byokKeyStore,
              initialTranscript: initialTranscript,
              onCommandResult: (result) {
                if (!mounted) return;
                setState(() {
                  _lastLoopResult = result;
                  _catState = result.isSuccess
                      ? CatState.success
                      : result.actionResult?.status ==
                            ActionStatus.permissionRequired
                      ? CatState.permissionRequired
                      : CatState.error;
                  _statusLine = result.errorMessage ?? result.spokenFeedback;
                });
                _refreshOutbox();
              },
            ),
          ),
        )
        .whenComplete(() {
          if (mounted) setState(() => _isListening = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildAssistTab(),
          NotesPage(repository: _notesRepo),
          _buildActivityTab(),
          _buildRoutinesTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedTabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Assist',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_rounded),
            label: 'Routines',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ASSIST
  // ==========================================
  Widget _buildAssistTab() => AssistHome(
    catState: _catState,
    status: _statusLine,
    pendingSync: _pendingSyncCount,
    lastResult: _lastLoopResult,
    favorites: _favoriteShortcuts,
    onEditContacts: _openFavoriteContacts,
    onSpeak: _openVoiceFullScreen,
    onShortcut: (phrase) => _openVoiceFullScreen(initialTranscript: phrase),
  );

  void _openFavoriteContacts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FavoriteContactsPage(repository: _favoriteContacts),
      ),
    );
  }

  // ==========================================
  // TAB 2: ACTIVITY
  // ==========================================
  Widget _buildActivityTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Activity Timeline',
          style: TextStyle(
            color: const Color(0xFF242521),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: const Color(0xFF777971)),
            onPressed: _refreshOutbox,
          ),
        ],
      ),
      body: _recentOutboxEvents.isEmpty
          ? const Center(
              child: Text(
                'No local actions recorded yet.',
                style: TextStyle(color: const Color(0xFF999B94)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _recentOutboxEvents.length,
              separatorBuilder: (context, idx) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final ev = _recentOutboxEvents[idx];
                final isSynced = ev.isSynced;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9E8E2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        ev.isSuccess
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: ev.isSuccess
                            ? const Color(0xFF06B6D4)
                            : const Color(0xFF777971),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.intent.toUpperCase(),
                              style: const TextStyle(
                                color: const Color(0xFF242521),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '"${ev.rawTranscript}"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: const Color(0xFF777971),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSynced
                              ? const Color(0xFF064E3B)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isSynced ? 'SYNCED' : 'LOCAL',
                          style: TextStyle(
                            color: isSynced
                                ? const Color(0xFF34D399)
                                : const Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==========================================
  // TAB 3: ROUTINES
  // ==========================================
  Widget _buildRoutinesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Local Routines',
          style: TextStyle(
            color: const Color(0xFF242521),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9E8E2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Morning Focus Routine',
                      style: TextStyle(
                        color: const Color(0xFF242521),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Steps: Volume 60% → Turn off DND',
                  style: TextStyle(
                    color: const Color(0xFF777971),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF242521),
                    foregroundColor: const Color(0xFFFFFFFF),
                  ),
                  onPressed: () async {
                    _actionClient.triggerHapticFeedback(type: 'medium');
                    final volume = await _actionClient.setVolume(60);
                    final dnd = await _actionClient.setDoNotDisturb(false);
                    await _refreshOutbox();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            volume.isSuccess && dnd.isSuccess
                                ? 'Morning Focus executed locally'
                                : 'Morning Focus needs attention; check device permissions.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Execute Now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9E8E2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.bedtime_outlined,
                      color: Color(0xFF777971),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Night Standby Routine',
                      style: TextStyle(
                        color: const Color(0xFF242521),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Steps: Turn on DND → Brightness 20% → Volume 15%',
                  style: TextStyle(
                    color: const Color(0xFF777971),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF242521),
                    foregroundColor: const Color(0xFFFFFFFF),
                  ),
                  onPressed: () async {
                    _actionClient.triggerHapticFeedback(type: 'medium');
                    final dnd = await _actionClient.setDoNotDisturb(true);
                    final brightness = await _actionClient.setBrightness(20);
                    final volume = await _actionClient.setVolume(15);
                    await _refreshOutbox();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            dnd.isSuccess &&
                                    brightness.isSuccess &&
                                    volume.isSuccess
                                ? 'Night Standby executed locally'
                                : 'Night Standby needs attention; check device permissions.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Execute Now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: SETTINGS & PRESERVED DIAGNOSTICS
  // ==========================================
  Widget _buildSettingsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings & BYOK',
          style: TextStyle(
            color: const Color(0xFF242521),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          ValueListenableBuilder<AuthSuccess?>(
            valueListenable: widget.serverpodClient.auth.authInfoListenable,
            builder: (context, auth, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9E8E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SERVERPOD ACCOUNT',
                    style: TextStyle(
                      color: const Color(0xFF777971),
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth == null
                        ? 'Connect when you are ready'
                        : 'Connected to Serverpod',
                    style: const TextStyle(
                      color: const Color(0xFF242521),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    auth == null
                        ? 'Offline commands work without an account. Sign in to register this device and sync your activity.'
                        : 'Your local commands continue working offline. Device sync is available when connected.',
                    style: const TextStyle(
                      color: const Color(0xFF777971),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () async {
                      if (auth == null) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AuthView(client: widget.serverpodClient),
                          ),
                        );
                      } else {
                        await widget.serverpodClient.auth.signOutDevice();
                        await _syncManager?.clearRegistration();
                      }
                    },
                    icon: Icon(auth == null ? Icons.login : Icons.logout),
                    label: Text(
                      auth == null ? 'Sign in or create account' : 'Sign out',
                    ),
                  ),
                  if (auth != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isAccountBusy ? null : _registerAndSync,
                      icon: _isAccountBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Register device & sync activity'),
                    ),
                  ],
                  if (_accountMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _accountMessage!,
                      style: const TextStyle(
                        color: const Color(0xFF777971),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: const Color(0xFFFFFFFF),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE9E8E2)),
            ),
            child: SwitchListTile.adaptive(
              value: _backgroundShakeEnabled,
              onChanged: _backgroundShakeBusy
                  ? null
                  : _setBackgroundShakeEnabled,
              secondary: _backgroundShakeBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.vibration_rounded),
              title: const Text(
                'Volume Up + shake in background',
                style: TextStyle(
                  color: Color(0xFF242521),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Hold Volume Up and shake while unlocked. Enable volume-key access below and allow display over other apps.',
                style: TextStyle(color: Color(0xFF777971), fontSize: 12),
              ),
              activeTrackColor: const Color(0xFF242521),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Permission.systemAlertWindow.request();
            },
            icon: const Icon(Icons.picture_in_picture_alt),
            label: const Text('Allow assistant over other apps'),
          ),
          TextButton.icon(
            onPressed: _actionClient.openTriggerAccessibilitySettings,
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Enable Triage volume key trigger'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9E8E2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE78A4E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.offline_bolt_rounded,
                    color: Color(0xFFE78A4E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Command Guide',
                        style: TextStyle(
                          color: Color(0xFF242521),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Examples for calls, messages, volume & tools.',
                        style: TextStyle(color: Color(0xFF777971), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => CommandGuideModal.show(context),
                  child: const Text('View guide'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9E8E2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pinned Contacts & Spoken Aliases',
                  style: TextStyle(
                    color: Color(0xFF242521),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set names Triage should recognize for calls and messages.',
                  style: TextStyle(color: Color(0xFF777971), fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openFavoriteContacts,
                  icon: const Icon(Icons.people_outline_rounded),
                  label: const Text('Manage contacts'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9E8E2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pinned Favorite Apps & Voice Aliases',
                  style: TextStyle(
                    color: Color(0xFF242521),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Triage can launch any app. Pin favorites here to assign quick voice aliases.',
                  style: TextStyle(color: Color(0xFF777971), fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FavoriteAppsPage(repository: _favoriteApps),
                      ),
                    );
                  },
                  icon: const Icon(Icons.apps_rounded),
                  label: const Text('Manage favorite apps'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // BYOK Card with Groq preserved
          ByokCard(
            gateway: _byokGateway,
            keyStore: _byokKeyStore,
            actionClient: _actionClient,
            cardColor: const Color(0xFF242521),
            successColor: const Color(0xFF06B6D4),
            warningColor: const Color(0xFFF59E0B),
            errorColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 20),

          // Preserved Full Diagnostics Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9E8E2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.developer_mode_outlined,
                      color: Color(0xFF06B6D4),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Advanced Diagnostics',
                      style: TextStyle(
                        color: const Color(0xFF242521),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Device checks, action verification, telemetry, and outbox sync logs.',
                  style: TextStyle(
                    color: const Color(0xFF777971),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE9E8E2),
                    foregroundColor: const Color(0xFF242521),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfflineVoiceSpikeScreen(
                          serverpodClient: widget.serverpodClient,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Full Diagnostics & Demo Harness'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
