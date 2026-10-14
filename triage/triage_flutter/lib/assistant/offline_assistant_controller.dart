import 'package:permission_handler/permission_handler.dart';

import '../actions/action_result.dart';
import '../actions/native_action_client.dart';
import '../voice/offline_voice_client.dart';
import '../outbox/local_outbox_repository.dart';
import '../outbox/outbox_event.dart';
import '../outbox/uuid_util.dart';
import '../parser/deterministic_action_parser.dart';
import '../contacts/favorite_contacts_repository.dart';
import '../actions/favorite_apps_repository.dart';
import '../notes/local_notes_repository.dart';

/// Structured outcome of a complete offline assistant execution cycle.
class AssistantLoopResult {
  final bool isSuccess;
  final bool isSpeechDelivered;
  final String? speechError;
  final TtsResult? ttsResult;
  final String? eventId;
  final String rawTranscript;
  final ParsedActionIntent intent;
  final ActionResult? actionResult;
  final String spokenFeedback;
  final int sttLatencyMs;
  final int parseLatencyMs;
  final int execLatencyMs;
  final int ttsLatencyMs;
  final String status;
  final String? errorMessage;

  const AssistantLoopResult({
    required this.isSuccess,
    this.isSpeechDelivered = false,
    this.speechError,
    this.ttsResult,
    this.eventId,
    required this.rawTranscript,
    required this.intent,
    this.actionResult,
    required this.spokenFeedback,
    required this.sttLatencyMs,
    required this.parseLatencyMs,
    required this.execLatencyMs,
    required this.ttsLatencyMs,
    required this.status,
    this.errorMessage,
  });

  @override
  String toString() =>
      'AssistantLoopResult(status: $status, type: ${intent.type}, ttsDelivered: $isSpeechDelivered, t_stt: ${sttLatencyMs}ms, t_parse: ${parseLatencyMs}ms, t_exec: ${execLatencyMs}ms, t_tts: ${ttsLatencyMs}ms)';
}

class _PinnedContactResolution {
  const _PinnedContactResolution({this.contact, this.failure});
  final FavoriteContact? contact;
  final ActionResult? failure;
}

/// Orchestrator for the 100% offline smart assistant loop:
/// Tap -> STT -> Deterministic Action Parse -> Pre-Execution Outbox Write -> Native Bridge -> Post-Execution Outbox Update -> Truthful TTS.
class OfflineAssistantController {
  final OfflineVoiceClient voiceClient;
  final NativeActionClient actionClient;
  final LocalOutboxRepository outboxRepository;
  final FavoriteContactsRepository? favoriteContacts;
  final FavoriteAppsRepository? favoriteApps;
  final LocalNotesRepository? notesRepository;

  OfflineAssistantController({
    required this.voiceClient,
    required this.actionClient,
    required this.outboxRepository,
    this.favoriteContacts,
    this.favoriteApps,
    this.notesRepository,
  });

  /// Executes the full assistant cycle across the expanded action matrix:
  /// Volume, Screen Brightness, Do Not Disturb, Timers, Alarms, App Launching, Media Controls.
  /// If [overrideTranscript] is passed, bypasses STT listening.
  /// If [speakTts] is false, skips local TTS speech (useful when Gemini Live handles voice follow-up).
  Future<AssistantLoopResult> executeVoiceLoop({
    String? overrideTranscript,
    bool Function()? isCancelled,
    bool speakTts = true,
  }) async {
    String transcript = '';
    int sttLatencyMs = 0;

    // Phase 1: Offline Speech Recognition
    if (overrideTranscript != null && overrideTranscript.isNotEmpty) {
      transcript = overrideTranscript;
      sttLatencyMs = 0;
    } else {
      final sttResult = await voiceClient.startListening();
      if (!sttResult.isSuccess ||
          sttResult.transcript == null ||
          sttResult.transcript!.isEmpty) {
        final err =
            sttResult.errorMessage ?? 'Speech not recognized or cancelled';
        return AssistantLoopResult(
          isSuccess: false,
          rawTranscript: '',
          intent: const ParsedActionIntent(
            type: ActionType.unknown,
            isMatched: false,
            rawTranscript: '',
            parseLatencyMs: 0,
          ),
          spokenFeedback: '',
          sttLatencyMs: sttResult.sttLatencyMs ?? 0,
          parseLatencyMs: 0,
          execLatencyMs: 0,
          ttsLatencyMs: 0,
          status: 'recognition_failed',
          errorMessage: err,
        );
      }
      transcript = sttResult.transcript!;
      sttLatencyMs = sttResult.sttLatencyMs ?? 0;
    }

    // A cancelled recognition must never become a phone action.
    if (isCancelled?.call() == true) {
      return AssistantLoopResult(
        isSuccess: false,
        rawTranscript: transcript,
        intent: const ParsedActionIntent(
          type: ActionType.unknown,
          isMatched: false,
          rawTranscript: '',
          parseLatencyMs: 0,
        ),
        spokenFeedback: '',
        sttLatencyMs: sttLatencyMs,
        parseLatencyMs: 0,
        execLatencyMs: 0,
        ttsLatencyMs: 0,
        status: 'cancelled',
      );
    }

    // Phase 2: Deterministic Slot-Filler Parsing
    var intent = DeterministicActionParser.parse(transcript);
    final parseLatencyMs = intent.parseLatencyMs;

    if (intent.isTakeNote && speakTts) {
      String? category;
      for (var attempt = 0; attempt < 2 && category == null; attempt++) {
        await voiceClient.speakOffline(
          attempt == 0
              ? 'Is this an idea, note, or reminder?'
              : 'Please say idea, note, or reminder.',
        );
        if (isCancelled?.call() == true) break;
        final answer = await voiceClient.startListening();
        if (isCancelled?.call() == true) break;
        final text = answer.transcript?.toLowerCase() ?? '';
        if (answer.isSuccess) {
          final choices = RegExp(r'\b(ideas?|notes?|reminders?)\b')
              .allMatches(text)
              .map((match) => match.group(1)!.replaceFirst(RegExp(r's$'), ''))
              .toSet();
          if (choices.length == 1) category = choices.single;
        }
      }
      if (category == null) {
        return AssistantLoopResult(
          isSuccess: false,
          rawTranscript: transcript,
          intent: intent,
          spokenFeedback:
              'Note not saved. Please choose idea, note, or reminder.',
          sttLatencyMs: sttLatencyMs,
          parseLatencyMs: parseLatencyMs,
          execLatencyMs: 0,
          ttsLatencyMs: 0,
          status: 'category_required',
        );
      }
      intent = ParsedActionIntent(
        type: intent.type,
        isMatched: true,
        rawTranscript: intent.rawTranscript,
        parseLatencyMs: intent.parseLatencyMs,
        matchedRule: intent.matchedRule,
        slots: {...intent.slots, 'noteCategory': category},
      );
    }

    if (!intent.isMatched) {
      final feedback =
          'I heard "$transcript", but could not recognize a valid assistant command.';
      int ttsLatency = 0;
      bool speechDelivered = false;
      String? speechErr;
      TtsResult? ttsRes;
      try {
        if (speakTts) {
          ttsRes = await voiceClient.speakOffline(feedback);
          ttsLatency = ttsRes.ttsLatencyMs ?? 0;
          if (ttsRes.isSuccess) {
            speechDelivered = true;
          } else {
            speechDelivered = false;
            speechErr =
                ttsRes.errorMessage ??
                ttsRes.errorCode ??
                'TTS playback failed';
          }
        }
      } catch (e) {
        speechDelivered = false;
        speechErr = e.toString();
      }

      return AssistantLoopResult(
        isSuccess: false,
        isSpeechDelivered: speechDelivered,
        speechError: speechErr,
        ttsResult: ttsRes,
        rawTranscript: transcript,
        intent: intent,
        spokenFeedback: feedback,
        sttLatencyMs: sttLatencyMs,
        parseLatencyMs: parseLatencyMs,
        execLatencyMs: 0,
        ttsLatencyMs: ttsLatency,
        status: 'intent_unmatched',
        errorMessage:
            'Utterance did not match any supported single-clause action pattern.',
      );
    }

    // Phase 3: CRITICAL PRE-EXECUTION OUTBOX WRITE
    final eventId = UuidUtil.generate();
    final now = DateTime.now();

    String intentStr;
    int? requestedValue;

    switch (intent.type) {
      case ActionType.volume:
        intentStr = 'set_volume';
        requestedValue = intent.targetPercent;
        break;
      case ActionType.brightness:
        intentStr = 'set_brightness';
        requestedValue = intent.brightnessPercent;
        break;
      case ActionType.dnd:
        intentStr = 'set_dnd';
        requestedValue = (intent.dndEnabled == true) ? 1 : 0;
        break;
      case ActionType.timer:
        intentStr = 'set_timer';
        requestedValue = intent.timerSeconds;
        break;
      case ActionType.alarm:
        intentStr = 'set_alarm';
        requestedValue =
            (intent.alarmHour ?? 0) * 100 + (intent.alarmMinute ?? 0);
        break;
      case ActionType.openApp:
        intentStr = 'open_app';
        requestedValue = null;
        break;
      case ActionType.media:
        intentStr = 'media_control';
        requestedValue = null;
        break;
      case ActionType.dialContact:
        intentStr = 'dial_contact';
        requestedValue = null;
        break;
      case ActionType.composeSms:
        intentStr = 'compose_sms';
        requestedValue = null;
        break;
      case ActionType.composeWhatsApp:
        intentStr = 'compose_whatsapp';
        requestedValue = null;
        break;
      case ActionType.navigation:
        intentStr = 'open_navigation';
        requestedValue = null;
        break;
      case ActionType.takeNote:
        intentStr = 'take_note';
        requestedValue = null;
        break;
      case ActionType.unknown:
        intentStr = 'unknown';
        requestedValue = null;
        break;
    }

    // PII Redaction for outbox event audit safety
    final safeTranscript =
        (intent.isDialContact ||
            intent.isComposeSms ||
            intent.isComposeWhatsApp)
        ? '${intent.type.name} [REDACTED_CONTACT]'
        : transcript;

    final preExecutionEvent = OutboxEvent(
      eventId: eventId,
      createdAt: now,
      intent: intentStr,
      rawTranscript: safeTranscript,
      requestedValue: requestedValue,
      status: 'attempted',
      sttLatencyMs: sttLatencyMs,
      parseLatencyMs: parseLatencyMs,
    );
    await outboxRepository.recordAttempt(preExecutionEvent);

    // Phase 4: Native Hardware / Intent Dispatch
    ActionResult actionResult;
    switch (intent.type) {
      case ActionType.volume:
        actionResult = await actionClient.setVolume(
          intent.targetPercent ?? 0,
          showUi: true,
        );
        break;
      case ActionType.brightness:
        actionResult = await actionClient.setBrightness(
          intent.brightnessPercent ?? 50,
        );
        break;
      case ActionType.dnd:
        actionResult = await actionClient.setDoNotDisturb(
          intent.dndEnabled ?? true,
        );
        break;
      case ActionType.timer:
        actionResult = await actionClient.setTimer(
          intent.timerSeconds ?? 60,
          message: intent.slots['label'] as String?,
          skipUi: true,
        );
        break;
      case ActionType.alarm:
        actionResult = await actionClient.setAlarm(
          intent.alarmHour ?? 7,
          intent.alarmMinute ?? 0,
          message: intent.slots['label'] as String?,
          skipUi: true,
        );
        break;
      case ActionType.openApp:
        final rawAppName = intent.appName ?? 'camera';
        if ((rawAppName == 'torch_on' || rawAppName == 'torch_off') &&
            !(await Permission.camera.request()).isGranted) {
          actionResult = const ActionResult(
            status: ActionStatus.permissionRequired,
            action: 'flashlight',
            executionLatencyMs: 0,
            errorCode: 'CAMERA_PERMISSION_REQUIRED',
            errorMessage: 'Allow camera access to use the flashlight.',
          );
        } else {
          // Check favorite apps for exact or alias package mapping first
          final pinned = favoriteApps?.resolve(rawAppName);
          final appToLaunch = pinned?.packageName ?? rawAppName;
          actionResult = await actionClient.openApp(appToLaunch);
        }
        break;
      case ActionType.media:
        actionResult = await actionClient.mediaControl(
          intent.mediaCommand ?? 'next',
        );
        break;
      case ActionType.dialContact:
        final contactQuery = intent.contactName ?? '';
        final resolution = await _resolvePinnedContact(
          contactQuery,
          speakTts: speakTts,
          isCancelled: isCancelled,
        );
        if (resolution.contact != null) {
          final pinnedContact = resolution.contact!;
          actionResult = await actionClient.dialContact(
            phoneNumber: pinnedContact.phoneNumber,
            name: pinnedContact.displayName,
          );
        } else {
          actionResult = resolution.failure!;
        }
        break;
      case ActionType.composeSms:
        final contactQuery = intent.contactName ?? '';
        final msg = intent.messageText ?? '';
        final resolution = await _resolvePinnedContact(
          contactQuery,
          speakTts: speakTts,
          isCancelled: isCancelled,
        );
        if (resolution.contact != null) {
          final pinnedContact = resolution.contact!;
          actionResult = await actionClient.composeSms(
            phoneNumber: pinnedContact.phoneNumber,
            message: msg,
            name: pinnedContact.displayName,
          );
        } else {
          actionResult = resolution.failure!;
        }
        break;
      case ActionType.composeWhatsApp:
        final contactQuery = intent.contactName ?? '';
        final msg = intent.messageText ?? '';
        final resolution = await _resolvePinnedContact(
          contactQuery,
          speakTts: speakTts,
          isCancelled: isCancelled,
        );
        if (resolution.contact != null) {
          final pinnedContact = resolution.contact!;
          actionResult = await actionClient.composeWhatsApp(
            phoneNumber: pinnedContact.phoneNumber,
            message: msg,
            name: pinnedContact.displayName,
          );
        } else {
          actionResult = resolution.failure!;
        }
        break;
      case ActionType.navigation:
        actionResult = await actionClient.openNavigation(
          intent.destination ?? 'home',
        );
        break;
      case ActionType.takeNote:
        final content = intent.noteContent ?? transcript;
        final category = intent.noteCategory ?? 'note';
        if (notesRepository != null) {
          await notesRepository!.createNote(
            content: content,
            category: category,
          );
          actionResult = ActionResult(
            status: ActionStatus.success,
            action: 'take_note',
            executionLatencyMs: 8,
            targetValue: content,
          );
        } else {
          actionResult = const ActionResult(
            status: ActionStatus.error,
            action: 'take_note',
            executionLatencyMs: 0,
            errorMessage: 'Notes storage not initialized.',
          );
        }
        break;
      case ActionType.unknown:
        actionResult = const ActionResult(
          status: ActionStatus.error,
          action: 'unknown',
          executionLatencyMs: 0,
          errorCode: 'UNKNOWN_INTENT',
          errorMessage: 'Intent was matched but has unknown action type',
        );
        break;
    }

    final execLatencyMs = actionResult.executionLatencyMs;
    final finalStatus = actionResult.status.toValue();
    final bool isActionSuccessful =
        actionResult.isSuccess || actionResult.status == ActionStatus.handedOff;

    // Phase 5: CRITICAL POST-EXECUTION OUTBOX UPDATE
    final prevValInt = (actionResult.previousValue is num)
        ? (actionResult.previousValue as num).toInt()
        : null;
    final actualValInt = (actionResult.targetValue is num)
        ? (actionResult.targetValue as num).toInt()
        : null;

    await outboxRepository.recordOutcome(
      eventId: eventId,
      status: finalStatus,
      previousValue: prevValInt,
      actualValue: actualValInt,
      errorCode: actionResult.errorCode,
      errorMessage: actionResult.errorMessage,
      execLatencyMs: execLatencyMs,
    );

    // Phase 6: Truthful Spoken TTS Feedback Formulation
    String feedbackText;
    if (isActionSuccessful) {
      switch (intent.type) {
        case ActionType.volume:
          final actual = actualValInt ?? intent.targetPercent ?? 0;
          feedbackText = actual == 0
              ? 'Volume muted.'
              : 'Volume set to $actual percent.';
          break;
        case ActionType.brightness:
          final actual = actualValInt ?? intent.brightnessPercent ?? 50;
          feedbackText = 'Screen brightness set to $actual percent.';
          break;
        case ActionType.dnd:
          feedbackText = intent.dndEnabled == true
              ? 'Do Not Disturb turned on.'
              : 'Do Not Disturb turned off.';
          break;
        case ActionType.timer:
          feedbackText =
              'Timer set for ${_formatTimerDuration(intent.timerSeconds ?? 60)}.';
          break;
        case ActionType.alarm:
          feedbackText =
              'Alarm set for ${_formatAlarmTime(intent.alarmHour ?? 7, intent.alarmMinute ?? 0)}.';
          break;
        case ActionType.openApp:
          switch (intent.appName) {
            case 'torch_on':
              feedbackText = 'Flashlight turned on.';
              break;
            case 'torch_off':
              feedbackText = 'Flashlight turned off.';
              break;
            case 'battery_status':
              final level = actionResult.extra['level'] ?? 'unknown';
              final charging = actionResult.extra['charging'] == true;
              feedbackText =
                  'Battery is at $level percent and currently ${charging ? "charging" : "not charging"}.';
              break;
            case 'wifi':
              feedbackText = 'Opening Wi-Fi settings.';
              break;
            case 'bluetooth':
              feedbackText = 'Opening Bluetooth settings.';
              break;
            default:
              feedbackText = 'Opening ${intent.appName ?? "app"}.';
          }
          break;
        case ActionType.media:
          switch (intent.mediaCommand) {
            case 'next':
              feedbackText = 'Skipping to next track.';
              break;
            case 'previous':
              feedbackText = 'Skipping to previous track.';
              break;
            default:
              feedbackText = 'Toggling media playback.';
              break;
          }
          break;
        case ActionType.dialContact:
          feedbackText =
              'Opening phone dialer for ${intent.contactName ?? "contact"}.';
          break;
        case ActionType.composeSms:
          feedbackText =
              'Opening SMS composer for ${intent.contactName ?? "contact"}.';
          break;
        case ActionType.composeWhatsApp:
          feedbackText =
              'Opening WhatsApp chat with draft for ${intent.contactName ?? "contact"}.';
          break;
        case ActionType.navigation:
          feedbackText =
              'Starting navigation to ${intent.destination ?? "destination"}.';
          break;
        case ActionType.takeNote:
          final cat = intent.noteCategory ?? 'note';
          feedbackText = 'Saved to ${cat}s.';
          break;
        case ActionType.unknown:
          feedbackText = 'Command executed.';
          break;
      }
    } else if (actionResult.status == ActionStatus.permissionRequired) {
      if (intent.type == ActionType.brightness) {
        feedbackText =
            'Write Settings permission is required to adjust screen brightness. Opening settings panel now.';
      } else if (intent.type == ActionType.dnd) {
        feedbackText =
            'Do Not Disturb access is required. Opening notification policy settings now.';
      } else if (intent.type == ActionType.dialContact ||
          intent.type == ActionType.composeSms ||
          intent.type == ActionType.composeWhatsApp) {
        feedbackText =
            'Contacts permission is required to find contacts on your device.';
      } else {
        feedbackText = 'Permission is required to execute this action.';
      }
    } else if (actionResult.status == ActionStatus.ambiguous) {
      feedbackText = actionResult.errorMessage ?? 'Which contact did you mean?';
    } else if (actionResult.status == ActionStatus.unsupported) {
      if (intent.type == ActionType.dialContact ||
          intent.type == ActionType.composeSms ||
          intent.type == ActionType.composeWhatsApp) {
        feedbackText =
            actionResult.errorMessage ??
            'Contact was not found in your phone book.';
      } else {
        feedbackText =
            'Cannot open ${intent.appName ?? "app"}. The app is not installed.';
      }
    } else {
      feedbackText =
          'Action failed: ${actionResult.errorMessage ?? actionResult.errorCode ?? "unknown error"}.';
    }

    // Phase 7: Spoken TTS Delivery
    int ttsLatencyMs = 0;
    bool speechDelivered = false;
    String? speechErr;
    TtsResult? ttsRes;
    if (speakTts) {
      try {
        ttsRes = await voiceClient.speakOffline(feedbackText);
        ttsLatencyMs = ttsRes.ttsLatencyMs ?? 0;
        if (ttsRes.isSuccess) {
          speechDelivered = true;
        } else {
          speechDelivered = false;
          speechErr =
              ttsRes.errorMessage ?? ttsRes.errorCode ?? 'TTS playback failed';
        }

        // Update outbox record with TTS latency metric
        await outboxRepository.recordOutcome(
          eventId: eventId,
          status: finalStatus,
          previousValue: prevValInt,
          actualValue: actualValInt,
          errorCode: actionResult.errorCode,
          errorMessage: actionResult.errorMessage,
          execLatencyMs: execLatencyMs,
          ttsLatencyMs: ttsLatencyMs,
        );
      } catch (e) {
        speechDelivered = false;
        speechErr = e.toString();
      }
    }

    return AssistantLoopResult(
      isSuccess: isActionSuccessful,
      isSpeechDelivered: speechDelivered,
      speechError: speechErr,
      ttsResult: ttsRes,
      eventId: eventId,
      rawTranscript: transcript,
      intent: intent,
      actionResult: actionResult,
      spokenFeedback: feedbackText,
      sttLatencyMs: sttLatencyMs,
      parseLatencyMs: parseLatencyMs,
      execLatencyMs: execLatencyMs,
      ttsLatencyMs: ttsLatencyMs,
      status: finalStatus,
      errorMessage: actionResult.errorMessage,
    );
  }

  Future<_PinnedContactResolution> _resolvePinnedContact(
    String query, {
    required bool speakTts,
    bool Function()? isCancelled,
  }) async {
    const action = 'pinned_contact';
    final repository = favoriteContacts;
    if (_pendingContactChoices.isNotEmpty &&
        DateTime.now().difference(_pendingContactAt).inSeconds < 90) {
      final selected = repository?.chooseFromReply(
        query,
        _pendingContactChoices,
      );
      if (selected != null) {
        _pendingContactChoices = [];
        return _PinnedContactResolution(contact: selected);
      }
    }
    final matches = repository?.findMatches(query) ?? const <FavoriteContact>[];
    if (matches.isEmpty) {
      return _PinnedContactResolution(
        failure: ActionResult(
          status: ActionStatus.unsupported,
          action: action,
          executionLatencyMs: 0,
          errorCode: 'PINNED_CONTACT_NOT_FOUND',
          errorMessage: 'I couldn’t find $query in your pinned contacts.',
        ),
      );
    }
    if (matches.length == 1) {
      _pendingContactChoices = [];
      return _PinnedContactResolution(contact: matches.single);
    }

    _pendingContactChoices = matches;
    _pendingContactAt = DateTime.now();
    final names = matches
        .asMap()
        .entries
        .map((entry) {
          final digits = entry.value.phoneNumber.replaceAll(RegExp(r'\D'), '');
          final lastDigits = digits.length > 4
              ? digits.substring(digits.length - 4)
              : digits;
          return '${entry.key + 1}: ${entry.value.displayName}, number ending $lastDigits';
        })
        .join('; ');
    final question =
        'I found ${matches.length} pinned contacts for $query: $names. Say the full name, first, second, or third.';
    if (!speakTts) {
      return _PinnedContactResolution(
        failure: ActionResult(
          status: ActionStatus.ambiguous,
          action: action,
          executionLatencyMs: 0,
          errorCode: 'PINNED_CONTACT_AMBIGUOUS',
          errorMessage: question,
          extra: {
            'candidates': matches
                .map((contact) => contact.displayName)
                .toList(),
          },
        ),
      );
    }

    await voiceClient.speakOffline(question);
    if (isCancelled?.call() == true) {
      return const _PinnedContactResolution(
        failure: ActionResult(
          status: ActionStatus.error,
          action: action,
          executionLatencyMs: 0,
          errorCode: 'CANCELLED',
          errorMessage: 'Contact selection was cancelled.',
        ),
      );
    }
    final answer = await voiceClient.startListening();
    final spokenName = answer.transcript?.trim() ?? '';
    final selected = repository?.chooseFromReply(spokenName, matches);
    if (selected != null) {
      _pendingContactChoices = [];
      return _PinnedContactResolution(contact: selected);
    }

    final retry = 'I couldn’t tell which contact you meant. Please try again.';
    await voiceClient.speakOffline(retry);
    if (isCancelled?.call() == true) {
      return const _PinnedContactResolution(
        failure: ActionResult(
          status: ActionStatus.error,
          action: action,
          executionLatencyMs: 0,
          errorCode: 'CANCELLED',
          errorMessage: 'Contact selection was cancelled.',
        ),
      );
    }
    final retryAnswer = await voiceClient.startListening();
    final retrySelection = repository?.chooseFromReply(
      retryAnswer.transcript ?? '',
      matches,
    );
    if (retrySelection != null) {
      _pendingContactChoices = [];
      return _PinnedContactResolution(contact: retrySelection);
    }
    return _PinnedContactResolution(
      failure: ActionResult(
        status: ActionStatus.ambiguous,
        action: action,
        executionLatencyMs: 0,
        errorCode: 'PINNED_CONTACT_AMBIGUOUS',
        errorMessage: question,
        extra: {
          'candidates': matches.map((contact) => contact.displayName).toList(),
        },
      ),
    );
  }

  List<FavoriteContact> _pendingContactChoices = [];
  DateTime _pendingContactAt = DateTime.fromMillisecondsSinceEpoch(0);

  static String _formatTimerDuration(int totalSeconds) {
    if (totalSeconds < 60) {
      return '$totalSeconds second${totalSeconds == 1 ? '' : 's'}';
    }
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    if (secs == 0) {
      return '$mins minute${mins == 1 ? '' : 's'}';
    }
    return '$mins minute${mins == 1 ? '' : 's'} and $secs second${secs == 1 ? '' : 's'}';
  }

  static String _formatAlarmTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }
}
