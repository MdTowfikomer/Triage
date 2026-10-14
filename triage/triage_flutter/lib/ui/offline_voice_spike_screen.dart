import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_client/triage_client.dart';
import '../actions/action_result.dart';
import '../actions/native_action_client.dart';
import '../assistant/offline_assistant_controller.dart';
import '../byok/byok_gateway.dart';
import '../byok/byok_key_store.dart';
import '../demo/hackathon_demo_harness.dart';
import '../outbox/local_outbox_repository.dart';
import '../outbox/outbox_event.dart';
import '../outbox/outbox_sync_manager.dart';
import '../outbox/uuid_util.dart';
import '../routines/local_routine_scheduler.dart';
import '../routines/routine_execution_manager.dart';
import '../telemetry/device_telemetry_manager.dart';
import '../voice/offline_voice_client.dart';
import '../parser/deterministic_action_parser.dart';
import 'components/byok_card.dart';
import 'components/hackathon_demo_card.dart';
import 'components/local_routine_card.dart';
import 'components/thinking_orb_widget.dart';
import 'components/border_beam_container.dart';
import 'components/telemetry_card.dart';
import 'auth_view.dart';

class OfflineVoiceSpikeScreen extends StatefulWidget {
  const OfflineVoiceSpikeScreen({super.key, this.serverpodClient});

  final Client? serverpodClient;

  @override
  State<OfflineVoiceSpikeScreen> createState() =>
      _OfflineVoiceSpikeScreenState();
}

class _OfflineVoiceSpikeScreenState extends State<OfflineVoiceSpikeScreen> {
  final OfflineVoiceClient _client = OfflineVoiceClient();
  final NativeActionClient _actionClient = NativeActionClient();
  late final LocalOutboxRepository _outboxRepo;
  late final OfflineAssistantController _assistantController;
  late final Client _serverpodClient;
  late final DeviceTelemetryManager _telemetryManager;
  late final LocalRoutineScheduler _localRoutineScheduler;
  late final ByokKeyStore _byokKeyStore;
  late final ByokGateway _byokGateway;
  late final HackathonDemoHarness _demoHarness;
  OutboxSyncManager? _syncManager;
  RoutineExecutionManager? _routineManager;
  RoutineExecutionReport? _lastRoutineReport;
  bool _isSchedulingRoutine = false;
  String? _routineStatusMessage;
  RoutineSchedule? _lastScheduledRoutine;
  bool _isRoutineStreamConnected = false;
  bool _isRepoInitialized = false;
  List<OutboxEvent> _recentOutboxEvents = [];
  bool _isExecutingLoop = false;
  AssistantLoopResult? _lastLoopResult;
  bool _isAuthSignedIn = false;
  String? _authUserId;
  bool _isRegisteringDevice = false;
  bool _isSyncing = false;
  String? _syncStatusMessage;
  VoiceCommandSyncResult? _lastSyncResult;
  int _pendingSyncCount = 0;

  VoiceCapabilities? _capabilities;
  bool _isLoadingCapabilities = true;

  bool _isListening = false;
  String _listeningStatus = 'Idle';
  double _currentRms = 0.0;
  String? _lastTranscript;
  List<String> _alternatives = [];
  int? _lastSttLatencyMs;
  String? _sttError;

  // Ticket 12 Unified Product Experience fields
  OrbState _orbState = OrbState.idle;
  String _orbStatusLine = 'Ready offline';
  bool _showDetailsArea = false;

  final TextEditingController _ttsInputController = TextEditingController(
    text: 'Offline voice verification successful. System volume adjusted.',
  );
  bool _isSpeaking = false;
  int? _lastTtsDoneLatencyMs;
  int? _lastTtsStartLatencyMs;
  String? _ttsError;

  ActionResult? _lastVolumeResult;
  List<ActionResult> _rapidResults = [];
  bool _isSettingVolume = false;
  int? _currentDeviceVolume;

  int? _currentBrightness;
  bool? _currentDndEnabled;
  bool _canWriteSettings = false;
  bool _isNotificationPolicyAccessGranted = false;
  ActionResult? _lastExpandedActionResult;
  bool _isExecutingExpandedAction = false;

  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _outboxRepo = LocalOutboxRepository();
    _assistantController = OfflineAssistantController(
      voiceClient: _client,
      actionClient: _actionClient,
      outboxRepository: _outboxRepo,
    );
    _routineManager = RoutineExecutionManager(
      repository: _outboxRepo,
      actionClient: _actionClient,
    );
    _serverpodClient =
        widget.serverpodClient ??
        (Client(
            const String.fromEnvironment(
              'SERVER_URL',
              defaultValue: 'https://triage.api.serverpod.space/',
            ),
          )
          ..connectivityMonitor = FlutterConnectivityMonitor()
          ..authSessionManager = FlutterAuthSessionManager());
    _telemetryManager = DeviceTelemetryManager(actionClient: _actionClient);
    _localRoutineScheduler = LocalRoutineScheduler(
      repository: _outboxRepo,
      actionClient: _actionClient,
    );
    _byokKeyStore = ByokKeyStore();
    _byokGateway = ByokGateway(keyStore: _byokKeyStore);
    _demoHarness = HackathonDemoHarness(
      repository: _outboxRepo,
      actionClient: _actionClient,
      routineScheduler: _localRoutineScheduler,
      byokGateway: _byokGateway,
      telemetryManager: _telemetryManager,
    );
    _localRoutineScheduler.listenToHardwareAlarms(
      serverpodClient: _serverpodClient,
      deviceId: _syncManager?.deviceId,
      deviceToken: _syncManager?.deviceToken,
      onExecuted: (report) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alarm Routine: ${report.status}')),
        );
        _initOutboxAndReconcile();
      },
    );
    _subscribeToEvents();
    _refreshCapabilities();
    _fetchCurrentVolume();
    _initOutboxAndReconcile();
    _initSyncManager();
    _startShakeListener();
  }

  void _startShakeListener() {
    unawaited(
      _actionClient.startShakeDetection(
        onShaken: () {
          if (!mounted) return;
          if (!_isListening && !_isExecutingLoop) {
            _startUnifiedVoiceAssistant();
          }
        },
      ),
    );
  }

  Future<void> _initOutboxAndReconcile() async {
    try {
      await _outboxRepo.initialize();
      await _outboxRepo.reconcileBootAttempts();
      final events = await _outboxRepo.getRecentEvents(limit: 20);
      final pending = await _outboxRepo.getPendingSyncEvents();
      if (!mounted) return;
      setState(() {
        _isRepoInitialized = true;
        _recentOutboxEvents = events;
        _pendingSyncCount = pending.length;
      });
    } catch (e, stack) {
      debugPrint('[OutboxInit] Error initializing outbox: $e\n$stack');
    }
  }

  Future<void> _initSyncManager() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mgr = OutboxSyncManager(
        repository: _outboxRepo,
        preferences: prefs,
      );
      final currentUid = _serverpodClient
          .auth
          .authInfoListenable
          .value
          ?.authUserId
          .toString();
      mgr.checkAccountAndInvalidateIfChanged(currentUid);

      mgr.startAutoSync(
        _serverpodClient,
        getCurrentUserId: () => _authUserId,
        onSyncCompleted: (res) {
          if (!mounted) return;
          _refreshOutboxEvents();
          setState(() {
            _lastSyncResult = res;
            _syncStatusMessage =
                'Auto-sync on reconnect: Synced: ${res.syncedCount}, Duplicates: ${res.duplicateCount}';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _syncManager = mgr;
        _isAuthSignedIn = _serverpodClient.auth.isAuthenticated;
        _authUserId = currentUid;
      });

      if (mgr.isRegistered) {
        _connectRoutineStream();
      }
    } catch (e) {
      debugPrint('[SyncInit] Error initializing sync manager: $e');
    }
  }

  Future<void> _refreshOutboxEvents() async {
    if (!_isRepoInitialized) return;
    try {
      final events = await _outboxRepo.getRecentEvents(limit: 20);
      final pending = await _outboxRepo.getPendingSyncEvents();
      if (!mounted) return;
      setState(() {
        _recentOutboxEvents = events;
        _pendingSyncCount = pending.length;
      });
    } catch (_) {}
  }

  Future<void> _authenticatePilot() async {
    setState(() => _isSyncing = true);
    try {
      if (!_serverpodClient.auth.isAuthenticated) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AuthView(client: _serverpodClient),
          ),
        );
      }
      final uid = _serverpodClient.auth.authInfoListenable.value?.authUserId
          .toString();
      if (uid == null) return;
      await _syncManager?.checkAccountAndInvalidateIfChanged(uid);
      if (!mounted) return;
      setState(() {
        _isAuthSignedIn = true;
        _authUserId = uid;
        _syncStatusMessage = 'Signed in (User: ${uid.substring(0, 8)}...)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncStatusMessage = 'Auth failed: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _registerDevice() async {
    final mgr = _syncManager;
    if (mgr == null) return;
    final uid =
        _authUserId ??
        _serverpodClient.auth.authInfoListenable.value?.authUserId.toString();
    if (uid == null) {
      setState(
        () => _syncStatusMessage = 'Please sign in before registering device.',
      );
      return;
    }
    setState(() => _isRegisteringDevice = true);
    try {
      final resp = await mgr.registerDevice(
        _serverpodClient,
        userId: uid,
        deviceName: 'Nothing Phone 2a',
      );
      _connectRoutineStream();
      if (!mounted) return;
      setState(() {
        _syncStatusMessage =
            'Device registered! Scoped token: ${resp.deviceToken.substring(0, 8)}...';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncStatusMessage = 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isRegisteringDevice = false);
    }
  }

  void _connectRoutineStream() {
    final mgr = _syncManager;
    if (mgr == null || !mgr.isRegistered || mgr.deviceToken == null) return;
    final deviceId = mgr.deviceId;
    final deviceToken = mgr.deviceToken!;

    _routineManager?.startListening(
      _serverpodClient,
      deviceId: deviceId,
      deviceToken: deviceToken,
      onExecuted: (report) async {
        if (!mounted) return;
        _fetchCurrentVolume();
        _refreshOutboxEvents();
        try {
          final serverRoutine = await _serverpodClient.routine.getRoutine(
            report.event.routineId,
          );
          if (mounted && serverRoutine != null) {
            setState(() {
              _lastScheduledRoutine = serverRoutine;
            });
          }
        } catch (_) {}
        setState(() {
          _lastRoutineReport = report;
          _routineStatusMessage =
              'Routine executed: ${report.status} (${report.event.name})';
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isRoutineStreamConnected = false;
          _routineStatusMessage = 'Routine stream error: $err';
        });
      },
    );
    setState(() {
      _isRoutineStreamConnected = true;
    });
  }

  Future<void> _scheduleMeetingPrepRoutine() async {
    final mgr = _syncManager;
    if (!_isAuthSignedIn || mgr?.isRegistered != true) {
      setState(
        () => _routineStatusMessage = 'Authenticate & register device first.',
      );
      return;
    }
    setState(() => _isSchedulingRoutine = true);
    try {
      final scheduledTime = DateTime.now().toUtc().add(
        const Duration(seconds: 5),
      );
      final stepsJson = jsonEncode([
        {
          'stepId': 'step-mute-1',
          'action': 'set_volume',
          'targetValue': 0,
          'unattended': true,
        },
      ]);

      final res = await _serverpodClient.routine.scheduleRoutine(
        deviceId: mgr!.deviceId,
        name: 'Meeting Prep: Set volume to 0%',
        scheduledTime: scheduledTime,
        stepsJson: stepsJson,
      );

      if (!mounted) return;
      setState(() {
        _routineStatusMessage =
            'Scheduled routine #${res.routineId.substring(0, 8)} for 5s in future (status: ${res.status})';
      });

      // Poll getRoutine after 7s to verify server status updated to completed
      Future.delayed(const Duration(seconds: 7), () async {
        try {
          final serverRoutine = await _serverpodClient.routine.getRoutine(
            res.routineId,
          );
          if (mounted && serverRoutine != null) {
            setState(() {
              _lastScheduledRoutine = serverRoutine;
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routineStatusMessage = 'Schedule error: $e';
      });
    } finally {
      if (mounted) setState(() => _isSchedulingRoutine = false);
    }
  }

  Future<void> _syncOutbox() async {
    final mgr = _syncManager;
    if (mgr == null) return;
    setState(() => _isSyncing = true);
    try {
      final res = await mgr.syncPendingEvents(
        _serverpodClient,
        currentUserId: _authUserId,
      );
      await _refreshOutboxEvents();
      if (!mounted) return;
      setState(() {
        _lastSyncResult = res;
        _syncStatusMessage = (res.syncedCount == 0 && res.duplicateCount == 0)
            ? 'No pending records to sync'
            : 'Sync completed! Synced: ${res.syncedCount}, Duplicates: ${res.duplicateCount}, Failed: ${res.failedCount}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncStatusMessage = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _simulateNetworkRetry() async {
    final mgr = _syncManager;
    if (mgr == null) return;
    if (_recentOutboxEvents.isEmpty) {
      setState(() => _syncStatusMessage = 'No events available to resend');
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final res = await mgr.resendBatch(_serverpodClient, _recentOutboxEvents);
      await _refreshOutboxEvents();
      if (!mounted) return;
      setState(() {
        _lastSyncResult = res;
        _syncStatusMessage =
            'Idempotent Retry Verified! Synced: ${res.syncedCount}, Duplicates: ${res.duplicateCount}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncStatusMessage = 'Retry failed: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _startUnifiedVoiceAssistant({String? overrideTranscript}) async {
    if (_isExecutingLoop || _isListening) return;

    // Trigger immediate tactile haptic pulse on invocation (shake or tap)
    _actionClient.triggerHapticFeedback(type: 'medium');

    setState(() {
      _isExecutingLoop = true;
      _orbState = OrbState.listening;
      _orbStatusLine = 'Listening...';
      _sttError = null;
    });

    try {
      if (overrideTranscript != null) {
        // Fast test path / direct voice simulation
        setState(() {
          _orbState = OrbState.processing;
          _orbStatusLine = 'Processing...';
        });
      }

      final res = await _assistantController.executeVoiceLoop(
        overrideTranscript: overrideTranscript,
      );

      if (!mounted) return;

      // Map outcome to Orb state and human-readable product status
      OrbState nextOrbState;
      String nextStatusLine;

      if (res.isSuccess) {
        nextOrbState = OrbState.success;
        if (res.intent.type == ActionType.volume) {
          nextStatusLine =
              'Volume adjusted to ${res.actionResult?.targetValue ?? res.intent.targetPercent}%';
        } else if (res.intent.type == ActionType.brightness) {
          nextStatusLine =
              'Brightness set to ${res.actionResult?.targetValue ?? res.intent.brightnessPercent}%';
        } else if (res.intent.type == ActionType.dnd) {
          nextStatusLine = res.intent.dndEnabled == true
              ? 'Do Not Disturb active'
              : 'Do Not Disturb off';
        } else if (res.intent.type == ActionType.timer) {
          nextStatusLine = 'Timer running';
        } else if (res.intent.type == ActionType.alarm) {
          nextStatusLine = 'Alarm configured';
        } else if (res.intent.type == ActionType.openApp) {
          nextStatusLine = 'App launched';
        } else {
          nextStatusLine = 'Done';
        }
      } else if (res.actionResult?.status == ActionStatus.permissionRequired) {
        nextOrbState = OrbState.permissionRequired;
        nextStatusLine = 'Permission needed — Tap to grant';
      } else if (res.actionResult?.status == ActionStatus.handedOff) {
        nextOrbState = OrbState.success;
        nextStatusLine = 'Handed off to system';
      } else {
        nextOrbState = OrbState.error;
        nextStatusLine = res.status == 'recognition_failed'
            ? 'Could not hear you'
            : 'Action failed';
      }

      setState(() {
        _lastLoopResult = res;
        _orbState = nextOrbState;
        _orbStatusLine = nextStatusLine;
        if (res.rawTranscript.isNotEmpty) {
          _lastTranscript = res.rawTranscript;
        }
      });

      await _fetchCurrentVolume();
      await _refreshOutboxEvents();

      // Return orb to idle breathing state after short status display window
      Future.delayed(const Duration(milliseconds: 3400), () {
        if (mounted &&
            _orbState != OrbState.listening &&
            _orbState != OrbState.processing) {
          setState(() {
            _orbState = OrbState.idle;
            _orbStatusLine = 'Ready offline';
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orbState = OrbState.error;
        _orbStatusLine = 'Error occurred';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExecutingLoop = false;
        });
      }
    }
  }

  Future<void> _runAssistantLoop({String? overrideTranscript}) async {
    await _startUnifiedVoiceAssistant(overrideTranscript: overrideTranscript);
  }

  Future<void> _stageOrphanAndKillProcess() async {
    final eventId = UuidUtil.generate();
    final orphan = OutboxEvent(
      eventId: eventId,
      createdAt: DateTime.now(),
      intent: 'set_volume',
      rawTranscript: 'staged orphan before process kill',
      requestedValue: 99,
      status: 'attempted',
      sttLatencyMs: 0,
      parseLatencyMs: 1,
    );
    await _outboxRepo.recordAttempt(orphan);
    await _refreshOutboxEvents();

    // Give short delay for SQLite WAL sync to disk then terminate process
    await Future.delayed(const Duration(milliseconds: 250));
    exit(0);
  }

  Future<void> _simulateInterruptedAttempt() async {
    final eventId = UuidUtil.generate();
    final dummy = OutboxEvent(
      eventId: eventId,
      createdAt: DateTime.now(),
      intent: 'set_volume',
      rawTranscript: 'simulated crash before execution',
      requestedValue: 99,
      status: 'attempted',
      sttLatencyMs: 0,
      parseLatencyMs: 1,
    );
    await _outboxRepo.recordAttempt(dummy);
    await _refreshOutboxEvents();

    // Simulate recovery on boot
    await Future.delayed(const Duration(milliseconds: 400));
    await _outboxRepo.reconcileBootAttempts();
    await _refreshOutboxEvents();
  }

  Future<void> _fetchCurrentVolume() async {
    final result = await _actionClient.getVolume();
    if (!mounted) return;
    setState(() {
      if (result.isSuccess && result.targetValue is int) {
        _currentDeviceVolume = result.targetValue as int;
      }
    });
  }

  Future<void> _testSetVolume(dynamic level) async {
    setState(() {
      _isSettingVolume = true;
      _rapidResults = [];
    });
    final result = await _actionClient.setVolume(level);
    if (!mounted) return;
    setState(() {
      _isSettingVolume = false;
      _lastVolumeResult = result;
      if (result.isSuccess && result.targetValue is int) {
        _currentDeviceVolume = result.targetValue as int;
      }
    });
  }

  Future<void> _testRapidCalls() async {
    setState(() {
      _isSettingVolume = true;
      _rapidResults = [];
    });

    // Fire 3 concurrent calls without waiting: set 30% -> set 70% -> getVolume
    final f1 = _actionClient.setVolume(30);
    final f2 = _actionClient.setVolume(70);
    final f3 = _actionClient.getVolume();

    final results = await Future.wait([f1, f2, f3]);
    if (!mounted) return;

    setState(() {
      _isSettingVolume = false;
      _rapidResults = results;
      _lastVolumeResult = results.last;
      if (results.last.isSuccess && results.last.targetValue is int) {
        _currentDeviceVolume = results.last.targetValue as int;
      }
    });
  }

  Future<void> _refreshExpandedCapabilities() async {
    try {
      final caps = await _actionClient.checkCapabilities();
      final brightRes = await _actionClient.getBrightness();
      final dndRes = await _actionClient.getDoNotDisturb();
      if (!mounted) return;
      setState(() {
        _canWriteSettings = caps['canWriteSettings'] == true;
        _isNotificationPolicyAccessGranted =
            caps['isNotificationPolicyAccessGranted'] == true;
        if (brightRes.isSuccess && brightRes.targetValue is num) {
          _currentBrightness = (brightRes.targetValue as num).toInt();
        }
        if (dndRes.isSuccess && dndRes.targetValue != null) {
          _currentDndEnabled =
              dndRes.targetValue == 1 || dndRes.targetValue == true;
        }
      });
    } catch (_) {}
  }

  Future<void> _executeDirectAction(
    Future<ActionResult> Function() actionCall,
  ) async {
    setState(() => _isExecutingExpandedAction = true);
    try {
      final res = await actionCall();
      if (!mounted) return;
      setState(() {
        _lastExpandedActionResult = res;
      });
      await _refreshExpandedCapabilities();
      await _refreshOutboxEvents();
    } finally {
      if (mounted) setState(() => _isExecutingExpandedAction = false);
    }
  }

  void _subscribeToEvents() {
    _eventSubscription = _client.events.listen((event) {
      final eventName = event['event'] as String?;
      if (!mounted) return;

      setState(() {
        switch (eventName) {
          case 'ready_for_speech':
            _listeningStatus = 'Listening (Speak now)...';
            _orbState = OrbState.listening;
            _orbStatusLine = 'Listening...';
            break;
          case 'beginning_of_speech':
            _listeningStatus = 'Speech detected...';
            _orbState = OrbState.listening;
            _orbStatusLine = 'Listening...';
            break;
          case 'rms_changed':
            _currentRms = (event['rms'] as num?)?.toDouble() ?? 0.0;
            break;
          case 'end_of_speech':
            _listeningStatus = 'Processing speech on-device...';
            _orbState = OrbState.processing;
            _orbStatusLine = 'Processing...';
            break;
          case 'partial_result':
            _lastTranscript = event['text'] as String?;
            if (_lastTranscript != null && _lastTranscript!.isNotEmpty) {
              _orbStatusLine = 'Hearing: "$_lastTranscript"';
            }
            break;
          case 'tts_start':
            _isSpeaking = true;
            _lastTtsStartLatencyMs = (event['startLatencyMs'] as num?)?.toInt();
            break;
          case 'tts_done':
            _isSpeaking = false;
            _lastTtsDoneLatencyMs = (event['ttsLatencyMs'] as num?)?.toInt();
            break;
          case 'tts_stopped':
            _isSpeaking = false;
            break;
        }
      });
    });
  }

  Future<void> _refreshCapabilities() async {
    setState(() => _isLoadingCapabilities = true);
    final caps = await _client.checkCapabilities();
    if (!mounted) return;
    setState(() {
      _capabilities = caps;
      _isLoadingCapabilities = false;
    });
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    await _refreshCapabilities();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _listeningStatus = 'Initializing on-device recognizer...';
      _sttError = null;
      _lastTranscript = null;
      _alternatives = [];
      _lastSttLatencyMs = null;
      _currentRms = 0.0;
    });

    final result = await _client.startListening();
    if (!mounted) return;

    setState(() {
      _isListening = false;
      _listeningStatus = 'Idle';
      if (result.isSuccess) {
        _lastTranscript = result.transcript;
        _alternatives = result.alternatives;
        _lastSttLatencyMs = result.sttLatencyMs;
      } else {
        _sttError =
            '${result.errorCode ?? result.status}: ${result.errorMessage ?? "Recognition failed"}';
      }
    });
  }

  Future<void> _cancelListening() async {
    await _client.cancelListening();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _listeningStatus = 'Cancelled';
      _currentRms = 0.0;
    });
  }

  Future<void> _speakOffline() async {
    final text = _ttsInputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSpeaking = true;
      _ttsError = null;
      _lastTtsDoneLatencyMs = null;
      _lastTtsStartLatencyMs = null;
    });

    final result = await _client.speakOffline(text);
    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      if (result.isSuccess) {
        _lastTtsDoneLatencyMs = result.ttsLatencyMs;
        _lastTtsStartLatencyMs = result.startLatencyMs;
      } else {
        _ttsError =
            '${result.errorCode ?? result.status}: ${result.errorMessage ?? "TTS failed"}';
      }
    });
  }

  @override
  void dispose() {
    if (_isListening) {
      _client.cancelListening();
    }
    _eventSubscription?.cancel();
    _client.dispose();
    _routineManager?.stopListening();
    _syncManager?.dispose();
    _outboxRepo.dispose();
    _ttsInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF121212);
    const cardColor = Color(0xFF1E1E1E);
    const accentColor = Color(0xFF6C5CE7);
    const successColor = Color(0xFF00B894);
    const warningColor = Color(0xFFFDCB6E);
    const errorColor = Color(0xFFFF7675);

    final caps = _capabilities;
    final hasMissingAssets =
        caps != null &&
        (!caps.onDeviceRecognitionAvailable ||
            !caps.offlineTtsAvailable ||
            !caps.micPermissionGranted);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E272E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.airplanemode_active,
                    color: Color(0xFF74B9FF),
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '100% OFFLINE',
                    style: TextStyle(
                      color: Color(0xFF74B9FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _syncStatusMessage ??
                    (_pendingSyncCount > 0
                        ? '$_pendingSyncCount pending sync'
                        : 'Outbox synced'),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDetailsArea ? Icons.tune : Icons.tune_outlined,
              color: _showDetailsArea ? accentColor : Colors.white60,
            ),
            tooltip: _showDetailsArea
                ? 'Hide developer details'
                : 'Show developer details',
            onPressed: () =>
                setState(() => _showDetailsArea = !_showDetailsArea),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white60, size: 20),
            onPressed: _refreshCapabilities,
            tooltip: 'Re-probe capabilities',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // TICKET 12: UNIFIED PRODUCT HERO EXPERIENCE
            // ==========================================
            const SizedBox(height: 12),

            // 1. Prominent Thinking Orb with Restrained Violet Light
            Center(
              child: ThinkingOrbWidget(
                state: _orbState,
                rmsDb: _currentRms,
                size: 210.0,
              ),
            ),

            const SizedBox(height: 18),

            // 2. Short status line directly beneath Orb
            Center(
              child: SizedBox(
                height: 28,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Text(
                    _orbStatusLine,
                    key: ValueKey<String>(_orbStatusLine),
                    style: TextStyle(
                      color: _orbState == OrbState.error
                          ? errorColor
                          : (_orbState == OrbState.permissionRequired
                                ? warningColor
                                : (_orbState == OrbState.success
                                      ? successColor
                                      : Colors.white70)),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Large "Tap to speak" capsule with Border Beam
            Center(
              child: BorderBeamContainer(
                isActive: _isListening || _isExecutingLoop,
                borderRadius: 32.0,
                borderWidth: 2.0,
                beamColor: const Color(0xFFA29BFE),
                backgroundColor: const Color(0xFF1E1E24),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32.0),
                    onTap: (_isExecutingLoop || _isListening)
                        ? null
                        : () => _startUnifiedVoiceAssistant(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36.0,
                        vertical: 16.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isListening ? Icons.graphic_eq : Icons.mic_rounded,
                            color: _isListening
                                ? const Color(0xFFA29BFE)
                                : Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isListening
                                ? 'Listening on device...'
                                : 'Tap to speak',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Quick hardware action chips for zero-typing accessibility
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  backgroundColor: const Color(0xFF1E1E24),
                  side: const BorderSide(color: Colors.white12),
                  label: const Text(
                    'Volume 40%',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  onPressed: (_isExecutingLoop || _isListening)
                      ? null
                      : () => _startUnifiedVoiceAssistant(
                          overrideTranscript: 'Set volume to 40%',
                        ),
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF1E1E24),
                  side: const BorderSide(color: Colors.white12),
                  label: const Text(
                    'Brightness 70%',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  onPressed: (_isExecutingLoop || _isListening)
                      ? null
                      : () => _startUnifiedVoiceAssistant(
                          overrideTranscript: 'Set brightness to 70%',
                        ),
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF1E1E24),
                  side: const BorderSide(color: Colors.white12),
                  label: const Text(
                    'Turn on DND',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  onPressed: (_isExecutingLoop || _isListening)
                      ? null
                      : () => _startUnifiedVoiceAssistant(
                          overrideTranscript: 'Turn on do not disturb',
                        ),
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF1E1E24),
                  side: const BorderSide(color: Colors.white12),
                  label: const Text(
                    'Timer 5m',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  onPressed: (_isExecutingLoop || _isListening)
                      ? null
                      : () => _startUnifiedVoiceAssistant(
                          overrideTranscript: 'Set a timer for 5 minutes',
                        ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. Transcript and Most Recent Action Result HUD
            if (_lastTranscript != null || _lastLoopResult != null) ...[
              BorderBeamContainer(
                isActive: _lastLoopResult != null && _orbState != OrbState.idle,
                borderRadius: 16.0,
                borderWidth: 1.5,
                beamColor: _lastLoopResult?.isSuccess == true
                    ? successColor
                    : warningColor,
                backgroundColor: cardColor,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transcript line
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.record_voice_over_outlined,
                          color: Color(0xFFA29BFE),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Transcript',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '"${_lastTranscript ?? _lastLoopResult?.rawTranscript ?? ""}"',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.white10, height: 24),

                    // Truthful Execution Result
                    if (_lastLoopResult != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _lastLoopResult!.isSuccess
                                  ? successColor.withValues(alpha: 0.2)
                                  : (_lastLoopResult!.actionResult?.status ==
                                            ActionStatus.permissionRequired
                                        ? warningColor.withValues(alpha: 0.2)
                                        : errorColor.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _lastLoopResult!.status.toUpperCase(),
                              style: TextStyle(
                                color: _lastLoopResult!.isSuccess
                                    ? successColor
                                    : (_lastLoopResult!.actionResult?.status ==
                                              ActionStatus.permissionRequired
                                          ? warningColor
                                          : errorColor),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _lastLoopResult!.spokenFeedback,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // User next-step guidance for permission or hand-off
                      if (_lastLoopResult!.actionResult?.status ==
                          ActionStatus.permissionRequired) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C1E10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: warningColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: warningColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _lastLoopResult!.intent.type ==
                                          ActionType.brightness
                                      ? 'System permission needed: Tap below to enable "Modify system settings".'
                                      : 'Notification Policy access required: Tap below to grant DND access.',
                                  style: const TextStyle(
                                    color: Color(0xFFFDCB6E),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: warningColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: () {
                                  if (_lastLoopResult!.intent.type ==
                                      ActionType.brightness) {
                                    _actionClient.openWriteSettings();
                                  } else {
                                    _actionClient
                                        .openNotificationPolicySettings();
                                  }
                                },
                                child: const Text(
                                  'Open Settings',
                                  style: TextStyle(
                                    color: warningColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Truthful Latency Breakdown
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _buildMetricChip(
                            'STT',
                            '${_lastLoopResult!.sttLatencyMs}ms',
                            const Color(0xFF74B9FF),
                          ),
                          _buildMetricChip(
                            'Parse',
                            '${_lastLoopResult!.parseLatencyMs}ms',
                            const Color(0xFFA29BFE),
                          ),
                          _buildMetricChip(
                            'Exec',
                            '${_lastLoopResult!.execLatencyMs}ms',
                            successColor,
                          ),
                          _buildMetricChip(
                            'TTS',
                            '${_lastLoopResult!.ttsLatencyMs}ms',
                            const Color(0xFF00CEC9),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 5. Details Section Toggle Divider
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onPressed: () =>
                    setState(() => _showDetailsArea = !_showDetailsArea),
                icon: Icon(
                  _showDetailsArea ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _showDetailsArea
                      ? 'Hide Secondary Details'
                      : 'Show Secondary Details (Audit, BYOK, Routines, Telemetry)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ==========================================
            // SECONDARY DETAILS AREA (TICKETS 04, 06, 08, 09, 10, 11)
            // ==========================================
            if (_showDetailsArea) ...[
              // Mode Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16222F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2C3E50)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.airplanemode_active,
                      color: Color(0xFF74B9FF),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Target Validation: 100% Offline (Airplane Mode Compatible). No network sockets invoked.',
                        style: TextStyle(
                          color: Color(0xFFDFE6E9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Diagnostic & Recovery Card (if any capability is missing)
              if (hasMissingAssets) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: errorColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: errorColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Offline Assets Setup Needed',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (caps.onDeviceRecognitionAvailable == false) ...[
                        const Text(
                          '• On-device speech recognizer missing: Android requires an offline speech recognition model (e.g. Google offline speech recognition data).',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF74B9FF),
                            side: const BorderSide(color: Color(0xFF74B9FF)),
                          ),
                          onPressed: () => _client.openVoiceInputSettings(),
                          icon: const Icon(Icons.settings_voice, size: 16),
                          label: const Text(
                            'Open Voice Input Settings',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (caps.offlineTtsAvailable == false) ...[
                        const Text(
                          '• Verified offline TTS voice missing: Ensure a voice pack without network requirement (isNetworkConnectionRequired == false) is installed.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF74B9FF),
                            side: const BorderSide(color: Color(0xFF74B9FF)),
                          ),
                          onPressed: () => _client.openTtsSettings(),
                          icon: const Icon(Icons.record_voice_over, size: 16),
                          label: const Text(
                            'Open TTS Settings',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (caps.micPermissionGranted == false) ...[
                        const Text(
                          '• Microphone permission denied: Speech recognition requires RECORD_AUDIO.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF74B9FF),
                            side: const BorderSide(color: Color(0xFF74B9FF)),
                          ),
                          onPressed: _requestMicrophonePermission,
                          icon: const Icon(Icons.mic, size: 16),
                          label: const Text(
                            'Grant Microphone Permission',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Card 1: Capabilities Pre-flight Check
              _buildCard(
                cardColor: cardColor,
                title: '1. On-Device Capabilities Pre-flight',
                child: _isLoadingCapabilities
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _buildCapabilitiesList(
                        warningColor,
                        successColor,
                        errorColor,
                      ),
              ),
              const SizedBox(height: 16),

              // Card 2: Offline STT Recognition
              _buildCard(
                cardColor: cardColor,
                title: '2. Offline Speech Recognition Probe',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Status: $_listeningStatus',
                      style: TextStyle(
                        color: _isListening ? successColor : Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // RMS Level indicator
                    if (_isListening)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ((_currentRms + 2.0) / 12.0).clamp(0.05, 1.0),
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isListening
                                  ? errorColor
                                  : accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isListening
                                ? _cancelListening
                                : _startListening,
                            icon: Icon(_isListening ? Icons.stop : Icons.mic),
                            label: Text(
                              _isListening
                                  ? 'Cancel Listening'
                                  : 'Tap & Speak in Airplane Mode',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Result display
                    if (_lastTranscript != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recognized Transcript:',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '"$_lastTranscript"',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: successColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    't_stt: ${_lastSttLatencyMs ?? 0} ms (Transcription latency after speech end — 0 network round-trip)',
                                    style: const TextStyle(
                                      color: successColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_alternatives.length > 1) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Alternatives: ${_alternatives.sublist(1).join(" • ")}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    if (_sttError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF7675),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: errorColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _sttError!,
                          style: const TextStyle(
                            color: errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Offline TTS Synthesis Probe
              _buildCard(
                cardColor: cardColor,
                title: '3. Offline TTS Synthesis Probe',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _ttsInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black45,
                        hintText: 'Enter text to synthesize offline...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D3436),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSpeaking ? null : _speakOffline,
                      icon: Icon(
                        _isSpeaking ? Icons.volume_up : Icons.play_arrow,
                        color: successColor,
                      ),
                      label: Text(
                        _isSpeaking
                            ? 'Playing Audio...'
                            : 'Play Spoken Confirmation',
                      ),
                    ),
                    if (_lastTtsDoneLatencyMs != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.flash_on,
                                  color: successColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    't_tts_start: ${_lastTtsStartLatencyMs ?? 0} ms (Time to first audio frame)',
                                    style: const TextStyle(
                                      color: successColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: successColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    't_playback_done: $_lastTtsDoneLatencyMs ms (Full utterance playback completion)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_ttsError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _ttsError!,
                        style: const TextStyle(color: errorColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 4: Native Volume Bridge & Result Contract (Ticket 02)
              _buildCard(
                cardColor: cardColor,
                title: '4. Native Volume Bridge & Result Contract (Ticket 02)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Media Volume: ${_currentDeviceVolume != null ? "$_currentDeviceVolume%" : "unknown"}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isSettingVolume
                              ? null
                              : _fetchCurrentVolume,
                          icon: const Icon(
                            Icons.refresh,
                            size: 14,
                            color: Color(0xFF74B9FF),
                          ),
                          label: const Text(
                            'Read',
                            style: TextStyle(
                              color: Color(0xFF74B9FF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: _isSettingVolume
                              ? null
                              : () => _testSetVolume(0),
                          child: const Text(
                            'Mute (0%)',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: _isSettingVolume
                              ? null
                              : () => _testSetVolume(30),
                          child: const Text(
                            'Set 30%',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: _isSettingVolume
                              ? null
                              : () => _testSetVolume(50),
                          child: const Text(
                            'Set 50%',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: _isSettingVolume
                              ? null
                              : () => _testSetVolume(80),
                          child: const Text(
                            'Set 80%',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: _isSettingVolume
                              ? null
                              : () => _testSetVolume(100),
                          child: const Text(
                            'Max (100%)',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: errorColor),
                          ),
                          onPressed: _isSettingVolume
                              ? null
                              : () => _testSetVolume(-20),
                          child: const Text(
                            'Invalid (-20%)',
                            style: TextStyle(color: errorColor, fontSize: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isSettingVolume ? null : _testRapidCalls,
                          icon: const Icon(Icons.bolt, size: 14),
                          label: const Text(
                            'Test Rapid Calls (30% -> 70% -> Read)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_rapidResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF6C5CE7,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.bolt,
                                  color: Color(0xFF6C5CE7),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Rapid Calls Verification (Serialized Queue)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < _rapidResults.length; i++) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Call ${i + 1} (${_rapidResults[i].action}): ',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _rapidResults[i].action == 'get_volume'
                                          ? 'current=${_rapidResults[i].targetValue}%'
                                          : '${_rapidResults[i].previousValue}% -> ${_rapidResults[i].targetValue}%',
                                      style: const TextStyle(
                                        color: successColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      't_exec: ${_rapidResults[i].executionLatencyMs} ms',
                                      style: const TextStyle(
                                        color: successColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (_lastVolumeResult != null && _rapidResults.isEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _lastVolumeResult!.isSuccess
                                ? successColor.withValues(alpha: 0.5)
                                : errorColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _lastVolumeResult!.isSuccess
                                        ? successColor.withValues(alpha: 0.2)
                                        : errorColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'status: ${_lastVolumeResult!.status.toValue()}',
                                    style: TextStyle(
                                      color: _lastVolumeResult!.isSuccess
                                          ? successColor
                                          : errorColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'action: ${_lastVolumeResult!.action}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_lastVolumeResult!.isSuccess) ...[
                              Text(
                                'Volume: ${_lastVolumeResult!.previousValue}% -> ${_lastVolumeResult!.targetValue}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Error: [${_lastVolumeResult!.errorCode}] ${_lastVolumeResult!.errorMessage}',
                                style: const TextStyle(
                                  color: errorColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.speed,
                                  color: successColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  't_exec: ${_lastVolumeResult!.executionLatencyMs} ms',
                                  style: const TextStyle(
                                    color: successColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 5: End-to-End Offline Assistant Loop & Pre-Execution Outbox (Ticket 03)
              _buildCard(
                cardColor: cardColor,
                title:
                    '5. Offline Assistant Loop & Pre-Execution Outbox (Ticket 03)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Orchestrates: STT -> Deterministic Parse -> Pre-Execution SQLite Write -> Native Bridge -> Post-Execution SQLite Update -> Truthful TTS.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Capsule Voice Trigger
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isRepoInitialized
                            ? Colors.grey.shade700
                            : _isExecutingLoop
                            ? const Color(0xFFE17055)
                            : const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (!_isRepoInitialized || _isExecutingLoop)
                          ? null
                          : () => _runAssistantLoop(),
                      icon: !_isRepoInitialized
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : _isExecutingLoop
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.record_voice_over, size: 20),
                      label: Text(
                        !_isRepoInitialized
                            ? 'Initializing Outbox & Reconciling...'
                            : _isExecutingLoop
                            ? 'Running Assistant Cycle...'
                            : 'Tap & Speak Assistant Command',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Utterance Simulator Quick Buttons
                    const Text(
                      'Simulated Utterances (Bypasses STT for deterministic testing):',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: (!_isRepoInitialized || _isExecutingLoop)
                              ? null
                              : () => _runAssistantLoop(
                                  overrideTranscript: 'Set volume to 50%',
                                ),
                          child: const Text(
                            '"Set volume to 50%"',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: (!_isRepoInitialized || _isExecutingLoop)
                              ? null
                              : () => _runAssistantLoop(
                                  overrideTranscript: 'Mute volume',
                                ),
                          child: const Text(
                            '"Mute volume"',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: (!_isRepoInitialized || _isExecutingLoop)
                              ? null
                              : () => _runAssistantLoop(
                                  overrideTranscript:
                                      'Set volume to eighty percent',
                                ),
                          child: const Text(
                            '"Set volume to eighty percent"',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3436),
                          ),
                          onPressed: (!_isRepoInitialized || _isExecutingLoop)
                              ? null
                              : () => _runAssistantLoop(
                                  overrideTranscript: 'Turn it up to 25%',
                                ),
                          child: const Text(
                            '"Turn it up to 25%"',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE17055)),
                          ),
                          onPressed: (!_isRepoInitialized || _isExecutingLoop)
                              ? null
                              : () => _runAssistantLoop(
                                  overrideTranscript: 'Open camera app',
                                ),
                          child: const Text(
                            '"Open camera" (Unmatched)',
                            style: TextStyle(
                              color: Color(0xFFE17055),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE17055)),
                          ),
                          onPressed: (!_isRepoInitialized || _isExecutingLoop)
                              ? null
                              : () => _runAssistantLoop(
                                  overrideTranscript: "Don't set volume to 50",
                                ),
                          child: const Text(
                            '"Don\'t set volume to 50" (Negated)',
                            style: TextStyle(
                              color: Color(0xFFE17055),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Crash Recovery Simulation Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2416),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: warningColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: warningColor,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Crash Durability & Replay Suppression Contract',
                                style: TextStyle(
                                  color: warningColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Simulates process kill between pre-execution outbox write and bridge return. Upon boot recovery, the orphan is marked outcome_unknown and NEVER replayed.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD63031),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : _stageOrphanAndKillProcess,
                                icon: const Icon(
                                  Icons.power_settings_new,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Stage Orphan & Kill App (Physical Cold Boot Test)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: warningColor,
                                  side: const BorderSide(color: warningColor),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : _simulateInterruptedAttempt,
                                icon: const Icon(Icons.flash_off, size: 14),
                                label: const Text(
                                  'Simulate In-Memory Transition',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Last Assistant Loop Result Display
                    if (_lastLoopResult != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _lastLoopResult!.isSuccess
                                ? successColor.withValues(alpha: 0.5)
                                : errorColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _lastLoopResult!.isSuccess
                                        ? successColor.withValues(alpha: 0.2)
                                        : errorColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'status: ${_lastLoopResult!.status}',
                                    style: TextStyle(
                                      color: _lastLoopResult!.isSuccess
                                          ? successColor
                                          : errorColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _lastLoopResult!.isSpeechDelivered
                                        ? successColor.withValues(alpha: 0.15)
                                        : warningColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _lastLoopResult!.isSpeechDelivered
                                            ? Icons.volume_up
                                            : Icons.volume_off,
                                        color:
                                            _lastLoopResult!.isSpeechDelivered
                                            ? successColor
                                            : warningColor,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _lastLoopResult!.isSpeechDelivered
                                            ? 'TTS Delivered'
                                            : 'TTS Failed',
                                        style: TextStyle(
                                          color:
                                              _lastLoopResult!.isSpeechDelivered
                                              ? successColor
                                              : warningColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'id: ${_lastLoopResult!.eventId ?? "N/A"}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_lastLoopResult!.isSpeechDelivered) ...[
                              Text(
                                'Spoken: "${_lastLoopResult!.spokenFeedback}"',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Speech Delivery Failed: ${_lastLoopResult!.speechError ?? "TTS playback error"}',
                                style: const TextStyle(
                                  color: warningColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_lastLoopResult!.isSuccess)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Hardware volume action executed successfully.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildMetricChip(
                                  't_stt',
                                  '${_lastLoopResult!.sttLatencyMs} ms',
                                  successColor,
                                ),
                                _buildMetricChip(
                                  't_parse',
                                  '${_lastLoopResult!.parseLatencyMs} ms',
                                  successColor,
                                ),
                                _buildMetricChip(
                                  't_exec',
                                  '${_lastLoopResult!.execLatencyMs} ms',
                                  _lastLoopResult!.isSuccess
                                      ? successColor
                                      : errorColor,
                                ),
                                _buildMetricChip(
                                  't_tts',
                                  _lastLoopResult!.isSpeechDelivered
                                      ? '${_lastLoopResult!.ttsLatencyMs} ms'
                                      : 'failed',
                                  _lastLoopResult!.isSpeechDelivered
                                      ? successColor
                                      : warningColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Live SQLite Outbox Table
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storage,
                              size: 14,
                              color: Color(0xFF74B9FF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Durable SQLite Outbox (${_recentOutboxEvents.length} events)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _refreshOutboxEvents,
                          icon: const Icon(
                            Icons.refresh,
                            size: 12,
                            color: Color(0xFF74B9FF),
                          ),
                          label: const Text(
                            'Refresh',
                            style: TextStyle(
                              color: Color(0xFF74B9FF),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_recentOutboxEvents.isEmpty)
                      const Text(
                        'No outbox records yet.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      )
                    else
                      Column(
                        children: [
                          for (final ev in _recentOutboxEvents.take(10)) ...[
                            _buildOutboxEventRow(
                              ev,
                              successColor,
                              warningColor,
                              errorColor,
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 6: Authenticated Device Registration & Deduplicated Outbox Sync (Ticket 04)
              _buildCard(
                cardColor: cardColor,
                title:
                    '6. Serverpod Device Auth & Deduplicated Sync (Ticket 04)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Derives device ownership from server auth, registers scoped device token, deduplicates audit events by eventId in PostgreSQL, and enforces transcript opt-in privacy.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Auth and Device Registration status row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isAuthSignedIn
                                    ? Icons.check_circle
                                    : Icons.account_circle,
                                color: _isAuthSignedIn
                                    ? successColor
                                    : Colors.white54,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isAuthSignedIn
                                      ? 'Signed in (ID: ${_authUserId ?? "N/A"})'
                                      : 'Not Authenticated on Serverpod',
                                  style: TextStyle(
                                    color: _isAuthSignedIn
                                        ? successColor
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C5CE7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: _isSyncing
                                    ? null
                                    : _authenticatePilot,
                                child: Text(
                                  _isAuthSignedIn ? 'Signed in' : 'Sign in',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 16),
                          Row(
                            children: [
                              Icon(
                                _syncManager?.isRegistered == true
                                    ? Icons.phonelink_ring
                                    : Icons.phonelink_erase,
                                color: _syncManager?.isRegistered == true
                                    ? successColor
                                    : warningColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Device ID: ${_syncManager != null && _syncManager!.deviceId.length > 8 ? _syncManager!.deviceId.substring(0, 8) : "..."}...',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      _syncManager?.isRegistered == true
                                          ? 'Token: ${_syncManager!.deviceToken!.substring(0, 8)}... (Registered)'
                                          : 'Device Not Registered',
                                      style: TextStyle(
                                        color:
                                            _syncManager?.isRegistered == true
                                            ? successColor
                                            : warningColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0984E3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed:
                                    (!_isAuthSignedIn ||
                                        _isRegisteringDevice ||
                                        _isSyncing)
                                    ? null
                                    : _registerDevice,
                                child: _isRegisteringDevice
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _syncManager?.isRegistered == true
                                            ? 'Re-Register'
                                            : 'Register Device',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Privacy Switch: Sync Transcripts (Opt-In)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _syncManager?.isTranscriptSyncEnabled == true
                              ? warningColor.withValues(alpha: 0.5)
                              : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _syncManager?.isTranscriptSyncEnabled == true
                                ? Icons.lock_open
                                : Icons.lock,
                            color: _syncManager?.isTranscriptSyncEnabled == true
                                ? warningColor
                                : successColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sync Raw Transcripts (Privacy Guard)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _syncManager?.isTranscriptSyncEnabled == true
                                      ? 'Transcripts WILL be uploaded to PostgreSQL'
                                      : 'Transcripts remain strictly on-device (PostgreSQL gets NULL)',
                                  style: TextStyle(
                                    color:
                                        _syncManager?.isTranscriptSyncEnabled ==
                                            true
                                        ? warningColor
                                        : Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value:
                                _syncManager?.isTranscriptSyncEnabled ?? false,
                            activeThumbColor: warningColor,
                            onChanged: (val) {
                              setState(() {
                                _syncManager?.isTranscriptSyncEnabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B894),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                (!_isAuthSignedIn ||
                                    _syncManager?.isRegistered != true ||
                                    _isSyncing)
                                ? null
                                : _syncOutbox,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload, size: 16),
                            label: Text(
                              'Sync Outbox ($_pendingSyncCount pending)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                (!_isAuthSignedIn ||
                                    _syncManager?.isRegistered != true ||
                                    _isSyncing)
                                ? null
                                : _simulateNetworkRetry,
                            icon: const Icon(Icons.replay, size: 16),
                            label: const Text(
                              'Simulate Retry (Resend)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Status / Result banner
                    if (_syncStatusMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _syncStatusMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_lastSyncResult != null) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _buildMetricChip(
                                    'Synced',
                                    '${_lastSyncResult!.syncedCount}',
                                    successColor,
                                  ),
                                  _buildMetricChip(
                                    'Duplicates',
                                    '${_lastSyncResult!.duplicateCount}',
                                    const Color(0xFF74B9FF),
                                  ),
                                  _buildMetricChip(
                                    'Failed',
                                    '${_lastSyncResult!.failedCount}',
                                    _lastSyncResult!.failedCount > 0
                                        ? errorColor
                                        : Colors.white54,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Future Calls are not available on Serverpod Cloud Starter.
              if (const bool.fromEnvironment(
                'TRIAGE_CLOUD_ROUTINES_ENABLED',
                defaultValue: false,
              )) ...[
                // Card 7: Connected Routine Delivery & Acknowledgement (Growth/local only)
                _buildCard(
                  cardColor: cardColor,
                  title:
                      '7. Connected Routine Delivery & Acknowledgement (Ticket 05)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Serverpod FutureCall dispatches unattended routines over device WebSocket. Phone claims occurrence atomically in SQLite, executes native volume mute (0%), and dispatches execution acknowledgement back to Serverpod.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      // Routine Stream & Connection Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isRoutineStreamConnected
                                ? successColor.withValues(alpha: 0.4)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isRoutineStreamConnected
                                  ? Icons.stream
                                  : Icons.portable_wifi_off,
                              color: _isRoutineStreamConnected
                                  ? successColor
                                  : warningColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isRoutineStreamConnected
                                        ? 'WebSocket Dispatch Stream: Active'
                                        : 'WebSocket Dispatch Stream: Inactive',
                                    style: TextStyle(
                                      color: _isRoutineStreamConnected
                                          ? successColor
                                          : warningColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _syncManager?.isRegistered == true
                                        ? 'Listening on channel: triage.device.${_syncManager!.deviceId.length > 8 ? _syncManager!.deviceId.substring(0, 8) : _syncManager!.deviceId}...'
                                        : 'Device must be registered first',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isRoutineStreamConnected &&
                                _syncManager?.isRegistered == true)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C5CE7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: _connectRoutineStream,
                                child: const Text(
                                  'Connect',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Schedule Routine Trigger Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed:
                            (!_isAuthSignedIn ||
                                _syncManager?.isRegistered != true ||
                                _isSchedulingRoutine)
                            ? null
                            : _scheduleMeetingPrepRoutine,
                        icon: _isSchedulingRoutine
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.schedule_send, size: 18),
                        label: Text(
                          _isSchedulingRoutine
                              ? 'Scheduling Routine...'
                              : 'Schedule "Meeting Prep: Set volume to 0%" (In 5s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      // Routine Status & Execution HUD
                      if (_routineStatusMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            _routineStatusMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      if (_lastRoutineReport != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _lastRoutineReport!.status == 'completed'
                                  ? successColor.withValues(alpha: 0.6)
                                  : warningColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _lastRoutineReport!.status ==
                                              'completed'
                                          ? successColor.withValues(alpha: 0.2)
                                          : warningColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'CLIENT ACK: ${_lastRoutineReport!.status.toUpperCase()}',
                                      style: TextStyle(
                                        color:
                                            _lastRoutineReport!.status ==
                                                'completed'
                                            ? successColor
                                            : warningColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Occurrence: ${_lastRoutineReport!.event.routineOccurrenceId.length > 8 ? _lastRoutineReport!.event.routineOccurrenceId.substring(0, 8) : _lastRoutineReport!.event.routineOccurrenceId}...',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Routine: ${_lastRoutineReport!.event.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              for (final step
                                  in _lastRoutineReport!.stepOutcomes) ...[
                                Row(
                                  children: [
                                    Icon(
                                      step.status == 'success'
                                          ? Icons.check_circle
                                          : Icons.error,
                                      size: 14,
                                      color: step.status == 'success'
                                          ? successColor
                                          : errorColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Step [${step.stepId}] (${step.action}): outcome=${step.actualValue ?? "0"} (${step.latencyMs} ms)',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_lastScheduledRoutine != null) ...[
                                const Divider(
                                  color: Colors.white12,
                                  height: 16,
                                ),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified,
                                          size: 14,
                                          color: successColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'PostgreSQL Status: ${_lastScheduledRoutine!.status.toUpperCase()}',
                                          style: const TextStyle(
                                            color: successColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      onPressed: () async {
                                        if (_lastRoutineReport == null) return;
                                        final serverRoutine =
                                            await _serverpodClient.routine
                                                .getRoutine(
                                                  _lastRoutineReport!
                                                      .event
                                                      .routineId,
                                                );
                                        if (mounted && serverRoutine != null) {
                                          setState(() {
                                            _lastScheduledRoutine =
                                                serverRoutine;
                                          });
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.refresh,
                                        size: 14,
                                        color: Color(0xFF74B9FF),
                                      ),
                                      tooltip: 'Refresh Status',
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Card 8: Native Action Matrix Expansion (Ticket 08)
              _buildCard(
                cardColor: cardColor,
                title: '8. Native Action Matrix Expansion (Ticket 08)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Direct hardware and OS actions via Kotlin bridge & scoped intents: Screen Brightness, Do Not Disturb, Timers & Alarms, App Launching, Media Controls.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Section 1: Screen Brightness
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.brightness_6,
                                    color: Color(0xFFFDCB6E),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Screen Brightness: ${_currentBrightness != null ? "$_currentBrightness%" : "unknown"}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _canWriteSettings
                                      ? successColor.withValues(alpha: 0.2)
                                      : warningColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _canWriteSettings
                                      ? 'WRITE_SETTINGS GRANTED'
                                      : 'WRITE_SETTINGS REQUIRED',
                                  style: TextStyle(
                                    color: _canWriteSettings
                                        ? successColor
                                        : warningColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setBrightness(25),
                                      ),
                                child: const Text(
                                  '25%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setBrightness(50),
                                      ),
                                child: const Text(
                                  '50%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setBrightness(80),
                                      ),
                                child: const Text(
                                  '80%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setBrightness(100),
                                      ),
                                child: const Text(
                                  '100%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (!_canWriteSettings)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: warningColor,
                                    side: const BorderSide(color: warningColor),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _actionClient.openWriteSettings(),
                                  icon: const Icon(Icons.settings, size: 14),
                                  label: const Text(
                                    'Open Write Settings',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 2: Do Not Disturb (DND)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.do_not_disturb_on,
                                    color: Color(0xFFE17055),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Do Not Disturb: ${_currentDndEnabled == true ? "ON (Priority)" : (_currentDndEnabled == false ? "OFF" : "unknown")}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _isNotificationPolicyAccessGranted
                                      ? successColor.withValues(alpha: 0.2)
                                      : warningColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _isNotificationPolicyAccessGranted
                                      ? 'POLICY ACCESS GRANTED'
                                      : 'POLICY ACCESS REQUIRED',
                                  style: TextStyle(
                                    color: _isNotificationPolicyAccessGranted
                                        ? successColor
                                        : warningColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentDndEnabled == true
                                      ? const Color(0xFFD63031)
                                      : const Color(0xFF00B894),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setDoNotDisturb(
                                          !(_currentDndEnabled ?? false),
                                        ),
                                      ),
                                child: Text(
                                  _currentDndEnabled == true
                                      ? 'Turn DND Off'
                                      : 'Turn DND On',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!_isNotificationPolicyAccessGranted)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: warningColor,
                                    side: const BorderSide(color: warningColor),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  onPressed: () => _actionClient
                                      .openNotificationPolicySettings(),
                                  icon: const Icon(
                                    Icons.notifications_off,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Open DND Settings',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 3: Clock (Timers & Alarms)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.alarm,
                                color: Color(0xFF00CEC9),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Clock: Timers & Alarms (Handed Off to System Clock)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setTimer(
                                          30,
                                          message: 'Quick 30s timer',
                                        ),
                                      ),
                                child: const Text(
                                  'Timer 30s',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setTimer(
                                          300,
                                          message: '5m timer',
                                        ),
                                      ),
                                child: const Text(
                                  'Timer 5m',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setAlarm(
                                          7,
                                          0,
                                          message: 'Morning 7 AM',
                                        ),
                                      ),
                                child: const Text(
                                  'Alarm 7:00 AM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.setAlarm(
                                          8,
                                          30,
                                          message: 'Standup Alarm',
                                        ),
                                      ),
                                child: const Text(
                                  'Alarm 8:30 AM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 4: App Launching (Scoped Queries)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.apps,
                                color: Color(0xFF74B9FF),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Application Launching (Scoped Queries)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.openApp('camera'),
                                      ),
                                child: const Text(
                                  'Camera',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.openApp('whatsapp'),
                                      ),
                                child: const Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.openApp('chrome'),
                                      ),
                                child: const Text(
                                  'Chrome',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.openApp('settings'),
                                      ),
                                child: const Text(
                                  'Settings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.openApp('youtube'),
                                      ),
                                child: const Text(
                                  'YouTube',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.openApp('maps'),
                                      ),
                                child: const Text(
                                  'Maps',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed: _isExecutingExpandedAction
                                    ? null
                                    : () => _executeDirectAction(
                                        () => _actionClient.openApp('spotify'),
                                      ),
                                child: const Text(
                                  'Spotify',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 5: Media Controls
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                color: Color(0xFFA29BFE),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Media Playback Controls (KeyEvents)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D3436),
                                  ),
                                  onPressed: _isExecutingExpandedAction
                                      ? null
                                      : () => _executeDirectAction(
                                          () => _actionClient.mediaPrevious(),
                                        ),
                                  icon: const Icon(
                                    Icons.skip_previous,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Previous',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D3436),
                                  ),
                                  onPressed: _isExecutingExpandedAction
                                      ? null
                                      : () => _executeDirectAction(
                                          () => _actionClient.mediaPlayPause(),
                                        ),
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text(
                                    'Play / Pause',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D3436),
                                  ),
                                  onPressed: _isExecutingExpandedAction
                                      ? null
                                      : () => _executeDirectAction(
                                          () => _actionClient.mediaNext(),
                                        ),
                                  icon: const Icon(Icons.skip_next, size: 16),
                                  label: const Text(
                                    'Next',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 6: Full Offline Assistant Loop Matrix Runner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E272E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.mic,
                                color: Color(0xFF6C5CE7),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Full Loop Utterance Simulator (STT -> Outbox -> Bridge -> TTS)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript:
                                            'Set brightness to 70%',
                                      ),
                                child: const Text(
                                  '"Set brightness to 70%"',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript:
                                            'Turn on do not disturb',
                                      ),
                                child: const Text(
                                  '"Turn on do not disturb"',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript:
                                            'Turn off do not disturb',
                                      ),
                                child: const Text(
                                  '"Turn off do not disturb"',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript:
                                            'Set a timer for 5 minutes',
                                      ),
                                child: const Text(
                                  '"Set a timer for 5m"',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript:
                                            'Set alarm for 7:30 am',
                                      ),
                                child: const Text(
                                  '"Set alarm for 7:30 am"',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript: 'Open camera',
                                      ),
                                child: const Text(
                                  '"Open camera"',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3436),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript: 'Next track',
                                      ),
                                child: const Text(
                                  '"Next track"',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE17055),
                                  ),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript:
                                            "Don't turn on do not disturb",
                                      ),
                                child: const Text(
                                  '"Don\'t turn on DND" (Negated)',
                                  style: TextStyle(
                                    color: Color(0xFFE17055),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE17055),
                                  ),
                                ),
                                onPressed:
                                    (!_isRepoInitialized || _isExecutingLoop)
                                    ? null
                                    : () => _runAssistantLoop(
                                        overrideTranscript:
                                            'Open camera and set volume to 50',
                                      ),
                                child: const Text(
                                  '"Open camera and set volume" (Compound)',
                                  style: TextStyle(
                                    color: Color(0xFFE17055),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section 7: Action Execution HUD
                    if (_lastExpandedActionResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                _lastExpandedActionResult!.isSuccess ||
                                    _lastExpandedActionResult!.status ==
                                        ActionStatus.handedOff
                                ? successColor.withValues(alpha: 0.5)
                                : (_lastExpandedActionResult!.status ==
                                          ActionStatus.permissionRequired
                                      ? warningColor.withValues(alpha: 0.5)
                                      : errorColor.withValues(alpha: 0.5)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _lastExpandedActionResult!.isSuccess ||
                                            _lastExpandedActionResult!.status ==
                                                ActionStatus.handedOff
                                        ? successColor.withValues(alpha: 0.2)
                                        : (_lastExpandedActionResult!.status ==
                                                  ActionStatus
                                                      .permissionRequired
                                              ? warningColor.withValues(
                                                  alpha: 0.2,
                                                )
                                              : errorColor.withValues(
                                                  alpha: 0.2,
                                                )),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'status: ${_lastExpandedActionResult!.status.toValue()}',
                                    style: TextStyle(
                                      color:
                                          _lastExpandedActionResult!
                                                  .isSuccess ||
                                              _lastExpandedActionResult!
                                                      .status ==
                                                  ActionStatus.handedOff
                                          ? successColor
                                          : (_lastExpandedActionResult!
                                                        .status ==
                                                    ActionStatus
                                                        .permissionRequired
                                                ? warningColor
                                                : errorColor),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Text(
                                  'action: ${_lastExpandedActionResult!.action}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  't_exec: ${_lastExpandedActionResult!.executionLatencyMs} ms',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_lastExpandedActionResult!.errorMessage != null)
                              Text(
                                '${_lastExpandedActionResult!.errorCode}: ${_lastExpandedActionResult!.errorMessage}',
                                style: const TextStyle(
                                  color: errorColor,
                                  fontSize: 11,
                                ),
                              )
                            else
                              Text(
                                'Value: target=${_lastExpandedActionResult!.targetValue ?? "N/A"}, prev=${_lastExpandedActionResult!.previousValue ?? "N/A"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Card 8: Telemetry Sync (Ticket 09)
              TelemetryCard(
                telemetryManager: _telemetryManager,
                serverpodClient: _serverpodClient,
                deviceId: _syncManager?.deviceId,
                deviceToken: _syncManager?.deviceToken,
                cardColor: cardColor,
                successColor: successColor,
                warningColor: warningColor,
                errorColor: errorColor,
              ),
              const SizedBox(height: 16),
              // Card 9: Local Routines & Exact Alarms (Ticket 10)
              LocalRoutineCard(
                scheduler: _localRoutineScheduler,
                repository: _outboxRepo,
                actionClient: _actionClient,
                serverpodClient: _serverpodClient,
                deviceId: _syncManager?.deviceId,
                deviceToken: _syncManager?.deviceToken,
                cardColor: cardColor,
                successColor: successColor,
                warningColor: warningColor,
                errorColor: errorColor,
              ),
              const SizedBox(height: 16),
              // Card 10: BYOK Multi-Provider & Routing Firewall (Tickets 06 & 11)
              ByokCard(
                gateway: _byokGateway,
                keyStore: _byokKeyStore,
                actionClient: _actionClient,
                cardColor: cardColor,
                successColor: successColor,
                warningColor: warningColor,
                errorColor: errorColor,
              ),
              const SizedBox(height: 16),
              // Card 11: Core 4-Scene Hackathon Demo Verification (Ticket 07)
              HackathonDemoCard(
                harness: _demoHarness,
                serverpodClient: _serverpodClient,
                deviceId: _syncManager?.deviceId,
                deviceToken: _syncManager?.deviceToken,
                cardColor: cardColor,
                successColor: successColor,
                warningColor: warningColor,
                errorColor: errorColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOutboxEventRow(
    OutboxEvent ev,
    Color successColor,
    Color warningColor,
    Color errorColor,
  ) {
    Color statusColor;
    switch (ev.status) {
      case 'success':
        statusColor = successColor;
        break;
      case 'outcome_unknown':
        statusColor = warningColor;
        break;
      case 'error':
        statusColor = errorColor;
        break;
      default:
        statusColor = const Color(0xFF74B9FF);
    }

    final shortId = ev.eventId.length > 8
        ? ev.eventId.substring(0, 8)
        : ev.eventId;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$shortId',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  ev.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: ev.isSynced
                      ? successColor.withValues(alpha: 0.2)
                      : warningColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  ev.isSynced ? 'SYNCED' : 'PENDING',
                  style: TextStyle(
                    color: ev.isSynced ? successColor : warningColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${ev.createdAt.hour.toString().padLeft(2, '0')}:${ev.createdAt.minute.toString().padLeft(2, '0')}:${ev.createdAt.second.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '"${ev.rawTranscript}" -> intent: ${ev.intent}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'Req: ${ev.requestedValue ?? "-"}% | Prev: ${ev.previousValue ?? "-"}% | Act: ${ev.actualValue ?? "-"}%',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const Spacer(),
              Text(
                't_exec: ${ev.execLatencyMs ?? 0}ms | t_tts: ${ev.ttsLatencyMs ?? 0}ms',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          if (ev.errorMessage != null) ...[
            const SizedBox(height: 2),
            Text(
              '${ev.errorCode ?? "ERROR"}: ${ev.errorMessage}',
              style: TextStyle(color: statusColor, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required Color cardColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCapabilitiesList(
    Color warningColor,
    Color successColor,
    Color errorColor,
  ) {
    final caps = _capabilities;
    if (caps == null) {
      return const Text(
        'Unable to query platform capabilities.',
        style: TextStyle(color: Colors.white54),
      );
    }

    return Column(
      children: [
        _buildCapabilityRow(
          label: 'On-Device Speech Recognizer (API 31+)',
          isOk: caps.onDeviceRecognitionAvailable,
          detail: caps.onDeviceRecognitionAvailable
              ? 'Available on this device'
              : 'Unavailable (Check Google offline speech pack)',
          successColor: successColor,
          warningColor: warningColor,
        ),
        const Divider(color: Colors.white12, height: 16),
        _buildCapabilityRow(
          label: 'Offline TTS Voice (isNetworkConnectionRequired == false)',
          isOk: caps.offlineTtsAvailable,
          detail: caps.offlineTtsAvailable
              ? 'Voice: ${caps.selectedVoiceName} (${caps.selectedLocale})'
              : 'No offline voice verified (Install voice data in TTS settings)',
          successColor: successColor,
          warningColor: warningColor,
        ),
        const Divider(color: Colors.white12, height: 16),
        _buildCapabilityRow(
          label: 'Microphone Permission',
          isOk: caps.micPermissionGranted,
          detail: caps.micPermissionGranted ? 'Granted' : 'Permission required',
          successColor: successColor,
          warningColor: errorColor,
          action: caps.micPermissionGranted
              ? null
              : TextButton(
                  onPressed: _requestMicrophonePermission,
                  child: const Text(
                    'Grant',
                    style: TextStyle(color: Color(0xFF74B9FF), fontSize: 12),
                  ),
                ),
        ),
        const Divider(color: Colors.white12, height: 16),
        Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Text(
              'Android API Level: ${caps.apiLevel}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapabilityRow({
    required String label,
    required bool isOk,
    required String detail,
    required Color successColor,
    required Color warningColor,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isOk ? Icons.check_circle : Icons.warning_amber_rounded,
          color: isOk ? successColor : warningColor,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: isOk ? Colors.white60 : warningColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}
