import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_client/triage_client.dart';
import 'local_outbox_repository.dart';
import 'outbox_event.dart';
import 'uuid_util.dart';

/// Manages background synchronization of local durable outbox audit events to Serverpod.
/// Enforces user-account ownership, automatic backlog draining, network reconnect triggering,
/// and privacy-first transcript gating.
class OutboxSyncManager {
  final LocalOutboxRepository repository;
  final SharedPreferences preferences;
  final Connectivity? connectivity;

  static const keyDeviceId = 'triage_device_id';
  static const keyDeviceToken = 'triage_device_token';
  static const keyRegisteredUserId = 'triage_registered_user_id';
  static const keySyncTranscripts = 'triage_sync_transcripts_enabled';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  OutboxSyncManager({
    required this.repository,
    required this.preferences,
    this.connectivity,
  });

  /// The persistent client hardware-bound UUID for this device.
  String get deviceId {
    var id = preferences.getString(keyDeviceId);
    if (id == null || id.isEmpty) {
      id = UuidUtil.generate();
      preferences.setString(keyDeviceId, id);
    }
    return id;
  }

  /// Scoped device auth token issued by Serverpod.
  String? get deviceToken => preferences.getString(keyDeviceToken);

  /// Authenticated user ID under which this device is registered.
  String? get registeredUserId => preferences.getString(keyRegisteredUserId);

  /// Whether device has registered and received a scoped token.
  bool get isRegistered => deviceToken != null && deviceToken!.trim().isNotEmpty;

  /// Checks if current authenticated user matches registered user. If changed, clears device token.
  Future<bool> checkAccountAndInvalidateIfChanged(String? currentUserId) async {
    if (currentUserId == null || currentUserId.isEmpty) {
      await clearRegistration();
      return false;
    }
    final registered = registeredUserId;
    if (registered != null && registered != currentUserId) {
      // User changed! Invalidate registration to prevent cross-account sync
      await clearRegistration();
      return false;
    }
    return isRegistered;
  }

  /// Clears stored device token and account binding (e.g. on sign out or account switch).
  Future<void> clearRegistration() async {
    await preferences.remove(keyDeviceToken);
    await preferences.remove(keyRegisteredUserId);
  }

  /// Privacy boundary: raw transcripts remain strictly local on the device unless opted in.
  bool get isTranscriptSyncEnabled =>
      preferences.getBool(keySyncTranscripts) ?? false;

  set isTranscriptSyncEnabled(bool enabled) {
    preferences.setBool(keySyncTranscripts, enabled);
  }

  /// Registers this device with Serverpod under the authenticated user session.
  /// Binds device identity to server ownership and receives a scoped device token.
  Future<DeviceRegistrationResponse> registerDevice(
    Client client, {
    required String userId,
    String? deviceName,
  }) async {
    final response = await client.device.registerDevice(
      deviceId,
      deviceName: deviceName ?? 'Android Device',
    );
    await preferences.setString(keyDeviceToken, response.deviceToken);
    await preferences.setString(keyRegisteredUserId, userId);
    return response;
  }

  /// Synchronizes all pending outbox audit records to Serverpod, draining the entire backlog in batches.
  /// Deduplicated by eventId on the server; raw transcripts omitted unless opted in.
  Future<VoiceCommandSyncResult> syncPendingEvents(
    Client client, {
    String? currentUserId,
    int batchSize = 100,
  }) async {
    if (currentUserId != null) {
      final valid = await checkAccountAndInvalidateIfChanged(currentUserId);
      if (!valid) {
        throw StateError(
          'Active user account ($currentUserId) does not match registered device account ($registeredUserId). Re-registration required.',
        );
      }
    }

    final token = deviceToken;
    if (token == null || token.isEmpty) {
      throw StateError(
        'Device is not registered with Serverpod. Call registerDevice() first.',
      );
    }

    final syncTranscripts = isTranscriptSyncEnabled;
    var totalSynced = 0;
    var totalDuplicates = 0;
    var totalFailed = 0;
    final allSyncedIds = <String>[];

    // Loop until the entire backlog is drained
    while (true) {
      final pending = await repository.getPendingSyncEvents(limit: batchSize);
      if (pending.isEmpty) {
        break;
      }

      final entries = pending.map((event) {
        return VoiceCommandSyncEntry(
          eventId: event.eventId,
          intent: event.intent,
          actionTarget: _deriveActionTarget(event.intent),
          resultType: event.status,
          executionLatencyMs: event.execLatencyMs,
          executedOffline: true,
          timestamp: event.createdAt,
          // Privacy safeguard: raw transcript is strictly null unless opt-in is enabled
          transcript: syncTranscripts ? event.rawTranscript : null,
        );
      }).toList();

      final batch = VoiceCommandSyncBatch(
        deviceId: deviceId,
        deviceToken: token,
        entries: entries,
      );

      final result = await client.commandSync.syncBatch(batch);

      if (result.syncedEventIds.isNotEmpty) {
        await repository.markEventsSynced(result.syncedEventIds);
        allSyncedIds.addAll(result.syncedEventIds);
      }

      totalSynced += result.syncedCount;
      totalDuplicates += result.duplicateCount;
      totalFailed += result.failedCount;

      // Break if no records were acknowledged to prevent infinite loop on persistent failure
      if (result.syncedCount == 0 && result.duplicateCount == 0) {
        break;
      }
    }

    return VoiceCommandSyncResult(
      syncedCount: totalSynced,
      duplicateCount: totalDuplicates,
      failedCount: totalFailed,
      syncedEventIds: allSyncedIds,
    );
  }

  /// Retries a batch of events to verify idempotent server deduplication.
  Future<VoiceCommandSyncResult> resendBatch(
    Client client,
    List<OutboxEvent> events,
  ) async {
    final token = deviceToken;
    if (token == null || token.isEmpty) {
      throw StateError(
        'Device is not registered with Serverpod. Call registerDevice() first.',
      );
    }
    if (events.isEmpty) {
      return VoiceCommandSyncResult(
        syncedCount: 0,
        duplicateCount: 0,
        failedCount: 0,
        syncedEventIds: [],
      );
    }

    final syncTranscripts = isTranscriptSyncEnabled;
    final entries = events.map((event) {
      return VoiceCommandSyncEntry(
        eventId: event.eventId,
        intent: event.intent,
        actionTarget: _deriveActionTarget(event.intent),
        resultType: event.status,
        executionLatencyMs: event.execLatencyMs,
        executedOffline: true,
        timestamp: event.createdAt,
        transcript: syncTranscripts ? event.rawTranscript : null,
      );
    }).toList();

    final batch = VoiceCommandSyncBatch(
      deviceId: deviceId,
      deviceToken: token,
      entries: entries,
    );

    return await client.commandSync.syncBatch(batch);
  }

  /// Starts listening for network reconnects and triggers automatic sync of pending backlog.
  void startAutoSync(
    Client client, {
    String? Function()? getCurrentUserId,
    void Function(VoiceCommandSyncResult)? onSyncCompleted,
    void Function(Object error)? onSyncError,
  }) {
    stopAutoSync();
    final conn = connectivity ?? Connectivity();
    _connectivitySubscription = conn.onConnectivityChanged.listen((results) async {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && isRegistered) {
        try {
          final res = await syncPendingEvents(
            client,
            currentUserId: getCurrentUserId?.call(),
          );
          if (res.syncedCount > 0 || res.duplicateCount > 0) {
            onSyncCompleted?.call(res);
          }
        } catch (e) {
          onSyncError?.call(e);
        }
      }
    });
  }

  /// Stops automatic reconnect listener.
  void stopAutoSync() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  void dispose() {
    stopAutoSync();
  }

  static String _deriveActionTarget(String intent) {
    switch (intent) {
      case 'set_volume':
        return 'volume';
      case 'set_brightness':
        return 'brightness';
      case 'set_dnd':
        return 'dnd';
      case 'set_timer':
        return 'timer';
      case 'set_alarm':
        return 'alarm';
      case 'open_app':
        return 'app';
      case 'media_control':
        return 'media';
      default:
        return 'device';
    }
  }
}

