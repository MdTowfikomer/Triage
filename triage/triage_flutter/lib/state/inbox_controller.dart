import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:triage_client/triage_client.dart';
import '../core/draft.dart';
import '../core/redact.dart';
import '../data/inbox_repository.dart';
import '../data/local_cache.dart';
import '../notifications/reminder_scheduler.dart';
import '../voice/voice_engine.dart';

enum CapturePhase {
  idle,
  preparing,
  recording,
  processing,
  confirmation,
  review,
  saving,
}

class InboxController extends ChangeNotifier {
  InboxController({
    required this.repository,
    required this.cache,
    required this.voice,
    this.reminders = const NoopReminderScheduler(),
    this.redactor = const LocalPayloadRedactor(),
  });
  final InboxRepository repository;
  final LocalCache cache;
  final VoiceEngine voice;
  final ReminderScheduler reminders;
  final PayloadRedactor redactor;
  final List<InboxItem> items = [];
  List<Draft> pending = [];
  CapturePhase phase = CapturePhase.idle;
  String filter = 'all', status = '', error = '';
  bool loading = false, hasMore = false;
  List<double> audioLevels = List.filled(12, 0);
  int elapsedMs = 0;
  int? countdownMs;
  Timer? _countdown, _recording;
  StreamSubscription<InboxEvent>? _stream;
  bool _ready = false, _disposed = false, _levelBusy = false, _saving = false;
  int _generation = 0;
  Draft? get current => pending.isEmpty ? null : pending.first;
  List<InboxItem> get visible =>
      items.where((i) => filter == 'all' || i.type == filter).toList();
  int count(String type) =>
      items.where((i) => type == 'all' || i.type == type).length;
  double get progress => (countdownMs ?? 0) / 3000;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void setFilter(String type) {
    filter = type;
    _emit();
  }

  Future<void> initialize() async {
    try {
      await reminders.initialize();
    } catch (_) {
      status = 'Local reminders are unavailable on this device.';
    }
    pending = cache.drafts;
    if (pending.isNotEmpty) {
      phase = CapturePhase.review;
      current!.reviewReason = 'Recovered local draft. Review before saving.';
    }
    await refresh();
  }

  Future<void> refresh({bool more = false}) async {
    if (loading) return;
    loading = true;
    error = '';
    _emit();
    final generation = _generation;
    if (!more) {
      await _stream?.cancel();
      _stream = repository.watch().listen(
        _onEvent,
        onError: (Object e) {
          status = 'Sync disconnected. Refresh to reconnect.';
          _emit();
        },
        onDone: () {
          if (!_disposed) {
            status = 'Sync disconnected. Refresh to reconnect.';
            _emit();
          }
        },
      );
    }
    // Keep events received during the snapshot so a concurrent delete/create
    // cannot be resurrected/lost when listItems resolves.
    final buffered = <InboxEvent>[];
    _snapshotEvents = buffered;
    try {
      final page = await repository.list(offset: more ? items.length : 0);
      if (_disposed || generation != _generation) return;
      if (!more) items.clear();
      for (final item in page) {
        _upsert(item);
      }
      for (final event in buffered) {
        _applyEvent(event);
      }
      for (final item in items) {
        unawaited(_reconcileReminder(item));
      }
      hasMore = page.length == 100;
      status = '';
    } catch (_) {
      error = 'Inbox unavailable. Your local drafts are safe. Try refresh.';
    } finally {
      _snapshotEvents = null;
      loading = false;
      _emit();
    }
  }

  List<InboxEvent>? _snapshotEvents;
  void _onEvent(InboxEvent event) {
    // Defense in depth; the backend already authorizes the stream.
    if (event.item != null && event.item!.userId != repository.owner) return;
    _snapshotEvents?.add(event);
    if (event.operation == 'deleted') {
      unawaited(_cancelReminder(event.itemId));
    } else if (event.item != null) {
      unawaited(_reconcileReminder(event.item!));
    }
    _applyEvent(event);
    _emit();
  }

  void _applyEvent(InboxEvent event) {
    if (event.operation == 'deleted') {
      items.removeWhere((i) => i.id == event.itemId);
    } else if (event.item != null) {
      _upsert(event.item!);
    }
  }

  Future<void> _cancelReminder(int id) async {
    try {
      await reminders.cancel(id);
    } catch (_) {
      if (!_disposed) {
        status = 'Item synced; local reminder could not be cancelled.';
        _emit();
      }
    }
  }

  Future<void> _reconcileReminder(InboxItem item) async {
    final reminder = item.reminder;
    if (item.id == null) return;
    if (reminder == null || item.isCompleted || reminder.isFired) {
      await _cancelReminder(item.id!);
      return;
    }
    try {
      await reminders.schedule(item.id!, item.title, reminder.triggerAt);
    } catch (_) {
      if (!_disposed) {
        status = 'Saved; local alert could not be scheduled on this device.';
        _emit();
      }
    }
  }

  void _upsert(InboxItem item) {
    items.removeWhere((i) => i.id == item.id);
    items.add(item);
    items.sort((a, b) {
      final d = b.createdAt.compareTo(a.createdAt);
      return d != 0 ? d : (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }

  Future<void> _prepare() async {
    if (_ready) return;
    phase = CapturePhase.preparing;
    status = 'Loading on-device models…';
    _emit();
    await voice.initialize();
    _ready = true;
  }

  Future<void> toggleRecording() async {
    if (phase == CapturePhase.recording) {
      _recording?.cancel();
      phase = CapturePhase.processing;
      status = 'Transcribing on this device…';
      _emit();
      final generation = _generation;
      final reference = DateTime.now();
      try {
        final result = await voice.stop();
        if (!_disposed && generation == _generation) {
          await acceptResult(result, reference: reference);
        }
      } catch (_) {
        if (generation == _generation) {
          phase = CapturePhase.idle;
          error =
              'Couldn’t capture that. Check microphone permission and try again.';
          _emit();
        }
      }
      return;
    }
    if (phase != CapturePhase.idle) return;
    error = '';
    final generation = _generation;
    try {
      await voice.requestPermission();
      if (_disposed || generation != _generation) return;
      await _prepare();
      if (_disposed || generation != _generation) return;
      await voice.start();
      if (_disposed || generation != _generation) {
        await voice.cancel();
        return;
      }
      phase = CapturePhase.recording;
      elapsedMs = 0;
      status = '';
      _recording = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        elapsedMs = timer.tick * 100;
        if (elapsedMs >= 30000) {
          unawaited(toggleRecording());
          return;
        }
        unawaited(_readLevels());
        _emit();
      });
      _emit();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        phase = CapturePhase.idle;
        error =
            'Microphone or models unavailable. Use typed capture, or check permissions.';
        _emit();
      }
    }
  }

  Future<void> _readLevels() async {
    if (_levelBusy) return;
    _levelBusy = true;
    try {
      final levels = await voice.levels();
      if (phase == CapturePhase.recording) audioLevels = levels;
    } catch (_) {
      audioLevels = List.filled(12, 0);
    } finally {
      _levelBusy = false;
    }
  }

  Future<void> captureText(String text) async {
    if (phase != CapturePhase.idle) return;
    final generation = _generation;
    final reference = DateTime.now();
    error = '';
    try {
      await _prepare();
      if (_disposed || generation != _generation) return;
      phase = CapturePhase.processing;
      status = 'Routing on this device…';
      _emit();
      final result = await voice.route(text);
      if (!_disposed && generation == _generation) {
        await acceptResult(result, reference: reference);
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        // Typed capture remains available on platforms without the WASM bridge.
        await acceptResult({'transcript': text}, reference: reference);
        current?.reviewReason =
            'On-device engine unavailable. Choose category and title manually.';
        _emit();
      }
    }
  }

  Future<void> acceptResult(
    Map<String, dynamic> result, {
    DateTime? reference,
  }) async {
    pending = parseVoiceResult(result, reference ?? DateTime.now());
    await _present();
  }

  Future<void> _present() async {
    _countdown?.cancel();
    countdownMs = null;
    status = '';
    if (pending.isEmpty) {
      phase = CapturePhase.idle;
      _emit();
      return;
    }
    phase = CapturePhase.processing;
    status = 'Checking privacy on this device…';
    _emit();
    try {
      for (final draft in pending) {
        if (!draft.redactionReady) await draft.redactForServer(redactor);
      }
    } catch (_) {
      phase = CapturePhase.review;
      current!.reviewReason =
          'On-device privacy check failed. Nothing was sent; retry after the model is ready.';
      error = current!.reviewReason;
      status = '';
      try {
        await cache.saveDrafts(pending);
      } catch (_) {}
      _emit();
      return;
    }
    status = '';
    phase = current!.canAutoSave
        ? CapturePhase.confirmation
        : CapturePhase.review;
    // Persist before starting a timer. Failure must never advance to a write.
    try {
      await cache.saveDrafts(pending);
    } catch (_) {
      phase = CapturePhase.review;
      error = 'Local draft could not be stored. Auto-save paused.';
      _emit();
      return;
    }
    if (_disposed) return;
    if (phase == CapturePhase.confirmation) {
      countdownMs = 3000;
      _countdown = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        countdownMs = (3000 - timer.tick * 100).clamp(0, 3000);
        _emit();
        if (countdownMs == 0) {
          timer.cancel();
          unawaited(saveCurrent());
        }
      });
    }
    _emit();
  }

  void edit() {
    _countdown?.cancel();
    countdownMs = null;
    if (current != null) {
      phase = CapturePhase.review;
      current!.reviewReason = 'Auto-save paused. Save when ready.';
    }
    _emit();
  }

  void pauseForBackground() {
    if (phase == CapturePhase.confirmation) edit();
    if (phase == CapturePhase.recording) {
      _recording?.cancel();
      unawaited(voice.cancel());
      phase = CapturePhase.idle;
      status = 'Recording stopped while app was inactive.';
      _emit();
    }
  }

  Future<void> persistEdits() async {
    for (final draft in pending) {
      draft.invalidateRedaction();
    }
    try {
      await cache.saveDrafts(pending);
    } catch (_) {
      error = 'Local draft could not be stored.';
      _emit();
    }
  }

  Future<void> cancel() async {
    if (_saving) return;
    _generation++;
    _countdown?.cancel();
    _recording?.cancel();
    countdownMs = null;
    if (phase == CapturePhase.recording) await voice.cancel();
    final previous = pending;
    pending = [];
    phase = CapturePhase.idle;
    error = '';
    status = '';
    try {
      await cache.saveDrafts(pending);
    } catch (_) {
      pending = previous;
      phase = pending.isEmpty ? CapturePhase.idle : CapturePhase.review;
      error = 'Could not remove the local draft. Try again.';
    }
    _emit();
  }

  Future<void> saveCurrent() async {
    if (_saving || current == null || _disposed) return;
    _countdown?.cancel();
    countdownMs = null;
    final draft = current!;
    final validation = draft.validationError;
    if (validation != null) {
      edit();
      error = validation;
      _emit();
      return;
    }
    _saving = true;
    phase = CapturePhase.saving;
    error = '';
    _emit();
    final generation = _generation;
    var requestSent = false;
    try {
      // Journal the raw text before any network request. Once the request has
      // been sent its outcome may be unknown: no blind automatic retry.
      await cache.saveDrafts(pending);
      if (_disposed || generation != _generation) return;
      if (!draft.redactionReady) {
        await draft.redactForServer(redactor);
        await cache.saveDrafts(pending);
      }
      if (_disposed || generation != _generation) return;
      requestSent = true;
      final saved = await repository.create(draft.toItem(repository.owner));
      if (saved.userId != repository.owner) throw StateError('Session changed');
      await cache.putOriginal(saved.id!, draft.originalTranscript);
      await _reconcileReminder(saved);
      if (_disposed) return;
      _upsert(saved);
      pending.removeAt(0);
      await cache.saveDrafts(pending);
      _saving = false;
      await _present();
      if (pending.isEmpty) {
        status = 'Saved';
        _emit();
      }
    } catch (_) {
      if (!_disposed) {
        phase = CapturePhase.review;
        draft.reviewReason = requestSent
            ? 'Save unconfirmed. Draft kept locally. Refresh before retrying to avoid duplicates.'
            : 'On-device privacy check failed. Nothing was sent; retry after the model is ready.';
        error = draft.reviewReason;
        _emit();
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> complete(InboxItem item) async {
    try {
      final saved = await repository.complete(item.id!);
      await _reconcileReminder(saved);
      if (!_disposed) {
        _upsert(saved);
        status = 'Completed';
        _emit();
      }
    } catch (_) {
      error = 'Couldn’t complete item. Nothing was changed locally.';
      _emit();
    }
  }

  Future<bool> delete(InboxItem item) async {
    try {
      final deleted = await repository.delete(item.id!);
      if (!deleted) throw StateError('Not found');
      await _cancelReminder(item.id!);
      await cache.deleteOriginal(item.id!);
      items.removeWhere((i) => i.id == item.id);
      status = 'Deleted';
      _emit();
      return true;
    } catch (_) {
      error = 'Couldn’t delete item. Refresh and try again.';
      _emit();
      return false;
    }
  }

  Future<bool> update(InboxItem item) async {
    try {
      final saved = await repository.update(item);
      await _reconcileReminder(saved);
      if (!_disposed) {
        _upsert(saved);
        status = 'Changes saved';
        _emit();
      }
      return true;
    } catch (_) {
      error = 'Couldn’t save changes. Check the date and try again.';
      _emit();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _countdown?.cancel();
    _recording?.cancel();
    unawaited(_stream?.cancel());
    unawaited(voice.cancel().catchError((Object _) {}));
    super.dispose();
  }
}
