import 'dart:core';
import 'deterministic_volume_parser.dart';

enum ActionType {
  volume,
  brightness,
  dnd,
  timer,
  alarm,
  openApp,
  media,
  dialContact,
  composeSms,
  composeWhatsApp,
  navigation,
  takeNote,
  unknown,
}

/// Structured parsed intent containing action type, slots, and parsing metrics.
class ParsedActionIntent {
  final ActionType type;
  final bool isMatched;
  final String rawTranscript;
  final int parseLatencyMs;
  final String? matchedRule;
  final Map<String, dynamic> slots;

  const ParsedActionIntent({
    required this.type,
    required this.isMatched,
    required this.rawTranscript,
    required this.parseLatencyMs,
    this.matchedRule,
    this.slots = const {},
  });

  bool get isVolume => type == ActionType.volume && isMatched;
  bool get isBrightness => type == ActionType.brightness && isMatched;
  bool get isDnd => type == ActionType.dnd && isMatched;
  bool get isTimer => type == ActionType.timer && isMatched;
  bool get isAlarm => type == ActionType.alarm && isMatched;
  bool get isOpenApp => type == ActionType.openApp && isMatched;
  bool get isMedia => type == ActionType.media && isMatched;
  bool get isDialContact => type == ActionType.dialContact && isMatched;
  bool get isComposeSms => type == ActionType.composeSms && isMatched;
  bool get isComposeWhatsApp => type == ActionType.composeWhatsApp && isMatched;
  bool get isNavigation => type == ActionType.navigation && isMatched;
  bool get isTakeNote => type == ActionType.takeNote && isMatched;

  int? get targetPercent =>
      (slots['targetPercent'] ?? slots['percent']) as int?;
  int? get brightnessPercent =>
      (slots['percent'] ?? slots['targetPercent']) as int?;
  bool? get dndEnabled => slots['enabled'] as bool?;
  int? get timerSeconds => slots['seconds'] as int?;
  int? get alarmHour => slots['hour'] as int?;
  int? get alarmMinute => (slots['minute'] ?? slots['minutes']) as int?;
  String? get appName => (slots['app'] ?? slots['appName']) as String?;
  String? get mediaCommand => slots['command'] as String?;
  String? get contactName => (slots['contact'] ?? slots['name']) as String?;
  String? get messageText => (slots['message'] ?? slots['text']) as String?;
  String? get destination => slots['destination'] as String?;
  String? get noteContent => slots['noteContent'] as String?;
  String? get noteCategory => slots['noteCategory'] as String?;

  @override
  String toString() =>
      'ParsedActionIntent(type: $type, isMatched: $isMatched, slots: $slots, latency: ${parseLatencyMs}ms, rule: $matchedRule)';
}

/// Zero-network, strictly deterministic regex slot-filler for the expanded native action matrix.
class DeterministicActionParser {
  static const Map<String, int> _numberWords = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'hundred': 100,
  };

  /// Parses an utterance transcript into a typed [ParsedActionIntent].
  static ParsedActionIntent parse(String rawTranscript) {
    final stopwatch = Stopwatch()..start();
    final normalized = _normalizeText(rawTranscript);

    // Rule 0a: Strictly reject negated commands
    if (_hasNegation(normalized)) {
      stopwatch.stop();
      return ParsedActionIntent(
        type: ActionType.unknown,
        isMatched: false,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'rejected_negation',
      );
    }

    final cleaned = _stripPoliteAffixes(normalized);

    final volumeCue = RegExp(r'\b(volume|louder|quieter|mute|unmute|crank)\b').hasMatch(cleaned);
    final brightnessCue = RegExp(r'\b(brightness|screen|display|dim|darken)\b').hasMatch(cleaned);
    if (volumeCue && brightnessCue) {
      stopwatch.stop();
      return ParsedActionIntent(
        type: ActionType.unknown,
        isMatched: false,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'ambiguous_intent',
        slots: const {'candidates': ['volume', 'brightness']},
      );
    }

    // Messaging & Communication Intents (Allow natural phrasing in message body)
    final whatsappIntent = _parseWhatsApp(cleaned, rawTranscript, stopwatch);
    if (whatsappIntent != null) return whatsappIntent;

    final smsIntent = _parseSms(cleaned, rawTranscript, stopwatch);
    if (smsIntent != null) return smsIntent;

    final dialIntent = _parseDial(cleaned, rawTranscript, stopwatch);
    if (dialIntent != null) return dialIntent;

    final navIntent = _parseNavigation(cleaned, rawTranscript, stopwatch);
    if (navIntent != null) return navIntent;

    final reminderTimer = _parseReminderTimer(cleaned, rawTranscript, stopwatch);
    if (reminderTimer != null) return reminderTimer;

    final noteIntent = _parseNote(cleaned, rawTranscript, stopwatch);
    if (noteIntent != null) return noteIntent;

    // Rule 0b: Strictly reject compound or multi-intent commands for device control
    if (_hasCompoundClause(cleaned)) {
      stopwatch.stop();
      return ParsedActionIntent(
        type: ActionType.unknown,
        isMatched: false,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'rejected_compound',
      );
    }

    // 1. DND Intent
    final dndIntent = _parseDnd(cleaned, rawTranscript, stopwatch);
    if (dndIntent != null) return dndIntent;

    // 2. Brightness Intent
    final brightnessIntent = _parseBrightness(
      cleaned,
      rawTranscript,
      stopwatch,
    );
    if (brightnessIntent != null) return brightnessIntent;

    // 3. Media Controls Intent
    final mediaIntent = _parseMedia(cleaned, rawTranscript, stopwatch);
    if (mediaIntent != null) return mediaIntent;

    // 4. Timer Intent
    final timerIntent = _parseTimer(cleaned, rawTranscript, stopwatch);
    if (timerIntent != null) return timerIntent;

    // 5. Alarm Intent
    final alarmIntent = _parseAlarm(cleaned, rawTranscript, stopwatch);
    if (alarmIntent != null) return alarmIntent;

    // 6. Open App Intent
    final openAppIntent = _parseOpenApp(cleaned, rawTranscript, stopwatch);
    if (openAppIntent != null) return openAppIntent;

    // 7. Volume Intent (Fallback to existing volume parser)
    final vol = DeterministicVolumeParser.parse(rawTranscript);
    if (vol.isMatched) {
      stopwatch.stop();
      return ParsedActionIntent(
        type: ActionType.volume,
        isMatched: true,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: vol.matchedRule,
        slots: {
          'targetPercent': vol.targetPercent,
          'percent': vol.targetPercent,
        },
      );
    }

    stopwatch.stop();
    return ParsedActionIntent(
      type: ActionType.unknown,
      isMatched: false,
      rawTranscript: rawTranscript,
      parseLatencyMs: stopwatch.elapsedMilliseconds,
      matchedRule: null,
    );
  }

  // --- Sub-parsers ---

  static ParsedActionIntent? _parseDnd(String text, String raw, Stopwatch sw) {
    // "turn on do not disturb", "enable dnd", "dnd on", "turn on dnd"
    final enablePatterns = RegExp(
      r'^(?:turn\s+on|enable|activate|start|switch\s+on)?\s*(?:do\s+not\s+disturb|dnd)(?:\s+(?:mode|on))?$',
    );
    // "turn off do not disturb", "disable dnd", "dnd off", "turn off dnd"
    final disablePatterns = RegExp(
      r'^(?:turn\s+off|disable|deactivate|stop|switch\s+off)\s+(?:do\s+not\s+disturb|dnd)(?:\s+mode)?$|^(?:do\s+not\s+disturb|dnd)\s+off$',
    );

    if (disablePatterns.hasMatch(text)) {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.dnd,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'dnd_disable',
        slots: {'enabled': false},
      );
    }

    if (enablePatterns.hasMatch(text)) {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.dnd,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'dnd_enable',
        slots: {'enabled': true},
      );
    }

    return null;
  }

  static ParsedActionIntent? _parseBrightness(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    final dimPattern = RegExp(
      r'^(?:dim|darken)(?:\s+the)?(?:\s+screen|\s+display)?(?:\s+down)?(?:\s+to)?\s+([a-z0-9]+(?:\s+[a-z0-9]+)?)(?:\s*(?:%|percent))?$',
    );
    final dimMatch = dimPattern.firstMatch(text);
    if (dimMatch != null) {
      final value = _extractNumber(dimMatch.group(1) ?? '');
      if (value != null && value <= 100) {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.brightness,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'brightness_dim_numeric',
          slots: {'targetPercent': value},
        );
      }
    }
    if (text == 'half brightness' || text == 'brightness halfway') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.brightness,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'brightness_half',
        slots: {'targetPercent': 50},
      );
    }
    // Keywords for max / min
    if (text == 'max brightness' ||
        text == 'maximum brightness' ||
        text == 'full brightness' ||
        text == 'brightness to max' ||
        text == 'set brightness to max' ||
        text == 'turn brightness up to max') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.brightness,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'brightness_max',
        slots: {'targetPercent': 100},
      );
    }

    if (text == 'min brightness' ||
        text == 'minimum brightness' ||
        text == 'dim screen' ||
        text == 'dim the screen' ||
        text == 'brightness to min' ||
        text == 'lowest brightness') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.brightness,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'brightness_min',
        slots: {'targetPercent': 10},
      );
    }

    final brightnessPrefixPattern = RegExp(
      r'^(?:(?:set|change|adjust|turn(?:\s+it)?(?:\s+(?:up|down))?|put)\s+)?(?:the\s+)?(?:screen\s+|display\s+)?brightness\s*(?:level\s*)?(?:to|at|up to|down to)?\s*([a-z0-9\s\-%]+)$',
    );

    final match = brightnessPrefixPattern.firstMatch(text);
    if (match != null) {
      final valuePart = match.group(1)?.trim() ?? '';
      final parsedNumber = _extractNumber(valuePart);
      if (parsedNumber != null && parsedNumber >= 0 && parsedNumber <= 100) {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.brightness,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'brightness_numeric',
          slots: {'targetPercent': parsedNumber},
        );
      }
    }

    return null;
  }

  static ParsedActionIntent? _parseMedia(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    if (text == 'next track' ||
        text == 'next song' ||
        text == 'skip track' ||
        text == 'skip song' ||
        text == 'skip to next' ||
        text == 'next') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.media,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'media_next',
        slots: {'command': 'next'},
      );
    }

    if (text == 'previous track' ||
        text == 'previous song' ||
        text == 'prev track' ||
        text == 'prev song' ||
        text == 'play previous') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.media,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'media_previous',
        slots: {'command': 'previous'},
      );
    }

    if (text == 'pause music' ||
        text == 'pause song' ||
        text == 'pause playback' ||
        text == 'pause track' ||
        text == 'pause') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.media,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'media_pause',
        slots: {'command': 'pause'},
      );
    }

    if (text == 'play music' ||
        text == 'resume music' ||
        text == 'resume playback' ||
        text == 'play song') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.media,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'media_play',
        slots: {'command': 'play'},
      );
    }

    return null;
  }

  static ParsedActionIntent? _parseTimer(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    // "set a timer for 5 minutes", "timer 30 seconds", "set 1 minute timer"
    final timerPattern = RegExp(
      r'^(?:set\s+(?:a\s+)?)?timer(?:\s+for)?\s+(\d+|[a-z]+)\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?)$|^(?:set\s+(?:a\s+)?)?(\d+|[a-z]+)\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?)\s+timer$',
    );

    final match = timerPattern.firstMatch(text);
    if (match != null) {
      final rawNum = match.group(1) ?? match.group(3) ?? '1';
      final unit = (match.group(2) ?? match.group(4) ?? 'minutes')
          .toLowerCase();

      final count = _extractNumber(rawNum) ?? 1;
      int totalSeconds;
      if (unit.startsWith('sec')) {
        totalSeconds = count;
      } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
        totalSeconds = count * 3600;
      } else {
        totalSeconds = count * 60;
      }

      sw.stop();
      return ParsedActionIntent(
        type: ActionType.timer,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'timer_countdown',
        slots: {'seconds': totalSeconds, 'message': '$count $unit timer'},
      );
    }

    return null;
  }

  static ParsedActionIntent? _parseReminderTimer(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    final pattern = RegExp(
      r'^remind\s+me\s+to\s+(.+?)\s+in\s+(\d+|[a-z]+)\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?)$',
    );
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    final message = match.group(1)?.trim() ?? '';
    final count = _extractNumber(match.group(2) ?? '') ?? 0;
    final unit = (match.group(3) ?? '').toLowerCase();
    if (message.isEmpty || count <= 0) return null;
    final seconds = unit.startsWith('sec')
        ? count
        : unit.startsWith('hour') || unit.startsWith('hr')
        ? count * 3600
        : count * 60;
    sw.stop();
    return ParsedActionIntent(
      type: ActionType.timer,
      isMatched: true,
      rawTranscript: raw,
      parseLatencyMs: sw.elapsedMilliseconds,
      matchedRule: 'reminder_countdown',
      slots: {'seconds': seconds, 'label': message, 'message': message},
    );
  }

  static ParsedActionIntent? _parseAlarm(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    // "set an alarm for 7:30 am", "set alarm for 8 am", "alarm for 6 pm", "wake me up at 7:00 am"
    final alarmPattern = RegExp(
      r'^(?:(?:set\s+(?:an?\s+)?)?alarm(?:\s+(?:for|at))?|wake\s+me\s+up\s+at)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$',
    );

    final match = alarmPattern.firstMatch(text);
    if (match != null) {
      var hour = int.tryParse(match.group(1) ?? '') ?? 8;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final meridian = match.group(3)?.toLowerCase();

      if (meridian == 'pm' && hour < 12) hour += 12;
      if (meridian == 'am' && hour == 12) hour = 0;

      sw.stop();
      return ParsedActionIntent(
        type: ActionType.alarm,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'alarm_time',
        slots: {
          'hour': hour,
          'minute': minutes,
          'minutes': minutes,
          'message': 'Morning Alarm',
        },
      );
    }

    return null;
  }

  static ParsedActionIntent? _parseWhatsApp(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    // WhatsApp Call pattern:
    // "call ayesha on whatsapp" / "call ayesha via whatsapp" / "whatsapp call ayesha"
    final waCallPattern = RegExp(
      r'^(?:(?:make\s+a\s+)?whatsapp\s+call\s+to|call\s+([a-z0-9\s._]+?)\s+(?:on|via)\s+whatsapp|whatsapp\s+call\s+([a-z0-9\s._]+))$',
      caseSensitive: false,
    );
    final waCallMatch = waCallPattern.firstMatch(text);
    if (waCallMatch != null) {
      final contact = waCallMatch.group(1) ?? waCallMatch.group(2) ?? '';
      if (contact.trim().isNotEmpty) {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.composeWhatsApp,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'whatsapp_call',
          slots: {
            'contact': contact.trim(),
            'name': contact.trim(),
            'message': '',
            'text': '',
          },
        );
      }
    }

    // WhatsApp Message pattern:
    // Examples:
    // "whatsapp ayesha: i am on the way"
    // "whatsapp ayesha that i am on the way"
    // "whatsapp ayesha saying i am on the way"
    // "whatsapp ayesha i am on the way"
    // "send a whatsapp to ayesha saying i am on the way"
    // "send a message to ayesha on whatsapp saying ..."
    // "message ayesha on whatsapp that ..."
    // "whatsapp ayesha" (opens chat)
    final waExplicitPattern = RegExp(
      r'^(?:send\s+(?:a\s+)?whatsapp(?:\s+message)?\s+to|whatsapp|message\s+([a-z0-9\s._]+?)\s+(?:on|via)\s+whatsapp|text\s+([a-z0-9\s._]+?)\s+(?:on|via)\s+whatsapp)\s*([a-z0-9\s._]*?)(?:\s*[:]\s*|\s+(?:that|saying|and\s+say)\s+)(.+)$',
      caseSensitive: false,
    );

    final explicitMatch = waExplicitPattern.firstMatch(text);
    if (explicitMatch != null) {
      final contact = (explicitMatch.group(1) ?? explicitMatch.group(2) ?? explicitMatch.group(3))?.trim() ?? '';
      final msg = explicitMatch.group(4)?.trim() ?? '';
      if (contact.isNotEmpty && contact != 'message' && contact != 'text') {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.composeWhatsApp,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'compose_whatsapp',
          slots: {
            'contact': contact,
            'name': contact,
            'message': msg,
            'text': msg,
          },
        );
      }
    }

    // Direct pattern: "whatsapp <contact> <message>" or "whatsapp <contact>"
    final waDirectPattern = RegExp(
      r'^(?:send\s+(?:a\s+)?whatsapp(?:\s+message)?\s+to\s+|whatsapp\s+)([a-z0-9._]+)(?:\s+(.+))?$',
      caseSensitive: false,
    );

    final directMatch = waDirectPattern.firstMatch(text);
    if (directMatch != null) {
      final contact = directMatch.group(1)?.trim() ?? '';
      final msg = directMatch.group(2)?.trim() ?? '';
      if (contact.isNotEmpty && contact != 'message' && contact != 'text') {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.composeWhatsApp,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'compose_whatsapp_direct',
          slots: {
            'contact': contact,
            'name': contact,
            'message': msg,
            'text': msg,
          },
        );
      }
    }

    return null;
  }

  static ParsedActionIntent? _parseSms(String text, String raw, Stopwatch sw) {
    // Examples:
    // "text ayesha: i am on the way"
    // "message ayesha saying i am on the way"
    // "send an sms to ayesha: i am on the way"
    // "send a text to ayesha saying i am on the way"
    final smsPattern = RegExp(
      r'^(?:send\s+(?:a\s+)?(?:text|sms|message)(?:\s+to)?|text|message|sms)\s+([a-z0-9\s._]+?)(?:\s*[:]\s*|\s+(?:that|saying|and\s+say)\s+)(.+)$',
      caseSensitive: false,
    );

    final match = smsPattern.firstMatch(text);
    if (match != null) {
      final contact = match.group(1)?.trim() ?? '';
      final msg = match.group(2)?.trim() ?? '';
      if (contact.isNotEmpty && msg.isNotEmpty) {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.composeSms,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'compose_sms',
          slots: {
            'contact': contact,
            'name': contact,
            'message': msg,
            'text': msg,
          },
        );
      }
    }

    return null;
  }

  static ParsedActionIntent? _parseDial(String text, String raw, Stopwatch sw) {
    // Examples:
    // "call ayesha"
    // "dial ayesha"
    // "phone ayesha"
    // "make a call to ayesha"
    final dialPattern = RegExp(
      r'^(?:call|dial|phone|make\s+a\s+call\s+to)\s+([a-z0-9\s._]+)$',
      caseSensitive: false,
    );

    final match = dialPattern.firstMatch(text);
    if (match != null) {
      final contact = match.group(1)?.trim() ?? '';
      // Exclude "call me", "call back"
      if (contact.isNotEmpty && contact != 'back' && contact != 'emergency') {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.dialContact,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'dial_contact',
          slots: {'contact': contact, 'name': contact},
        );
      }
    }

    return null;
  }

  static ParsedActionIntent? _parseNavigation(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    // Examples:
    // "start navigation to home"
    // "navigate to home"
    // "directions to central park"
    // "drive to airport"
    final navPattern = RegExp(
      r'^(?:(?:start\s+)?navigation\s+to|navigate\s+to|directions\s+to|take\s+me\s+to|drive\s+to)\s+(.+)$',
      caseSensitive: false,
    );

    final match = navPattern.firstMatch(text);
    if (match != null) {
      final dest = match.group(1)?.trim() ?? '';
      if (dest.isNotEmpty) {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.navigation,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'open_navigation',
          slots: {'destination': dest},
        );
      }
    }

    return null;
  }

  static ParsedActionIntent? _parseOpenApp(
    String text,
    String raw,
    Stopwatch sw,
  ) {
    final hardwareShortcut = switch (text) {
      'turn on flashlight' || 'flashlight on' || 'torch on' => 'torch_on',
      'turn off flashlight' || 'flashlight off' || 'torch off' => 'torch_off',
      'battery level' ||
      'battery percentage' ||
      'how much battery' => 'battery_status',
      _ => null,
    };
    if (hardwareShortcut != null) {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.openApp,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'device_quick_action',
        slots: {'appName': hardwareShortcut},
      );
    }
    // "open camera", "launch whatsapp", "open maps", "start youtube"
    final openPattern = RegExp(
      r'^(?:open|launch|start)\s+(the\s+)?([a-z0-9\s._]+)$',
    );

    final match = openPattern.firstMatch(text);
    if (match != null) {
      final appName = match.group(2)?.trim() ?? '';
      // Don't mistake "open volume" or "open brightness"
      if (appName != 'volume' &&
          appName != 'brightness' &&
          appName.isNotEmpty) {
        sw.stop();
        return ParsedActionIntent(
          type: ActionType.openApp,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'open_application',
          slots: {'app': appName, 'appName': appName},
        );
      }
    }

    // Direct camera shortcuts
    if (text == 'take a photo' ||
        text == 'take a picture' ||
        text == 'camera') {
      sw.stop();
      return ParsedActionIntent(
        type: ActionType.openApp,
        isMatched: true,
        rawTranscript: raw,
        parseLatencyMs: sw.elapsedMilliseconds,
        matchedRule: 'camera_shortcut',
        slots: {'appName': 'camera'},
      );
    }

    return null;
  }

  // --- Helpers ---

  static bool _hasNegation(String text) {
    // Mask "do not disturb" phrase so it does not trigger a false positive on itself
    final masked = text.replaceAll(
      RegExp(r'\bdo\s+not\s+disturb\b', caseSensitive: false),
      'dnd_placeholder',
    );
    final negationPattern = RegExp(
      r"\b(don't|dont|do not|never|not|cancel|avoid|disallow|prevent|no)\b",
      caseSensitive: false,
    );
    return negationPattern.hasMatch(masked);
  }

  static bool _hasCompoundClause(String text) {
    final compoundPattern = RegExp(
      r"\b(and|then|also|after|before|while|but|if|when|plus|or)\b",
      caseSensitive: false,
    );
    return compoundPattern.hasMatch(text);
  }

  static String _stripPoliteAffixes(String text) {
    var cleaned = text;
    final leadingPattern = RegExp(
      r'^(?:please|can you please|could you please|would you please|can you|could you|would you|kindly|hey triage|hey|hi|triage)\s+',
      caseSensitive: false,
    );
    while (leadingPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(leadingPattern, '').trim();
    }
    final trailingPattern = RegExp(r'\s+please$', caseSensitive: false);
    if (trailingPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(trailingPattern, '').trim();
    }
    return cleaned;
  }

  static String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(r'’', "'")
        .replaceAll(RegExp(r'[,!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int? _extractNumber(String tokenString) {
    var cleaned = tokenString.replaceAll('%', '').trim();
    if (cleaned.endsWith('percent')) {
      cleaned = cleaned.substring(0, cleaned.length - 7).trim();
    }

    final directInt = int.tryParse(cleaned);
    if (directInt != null) return directInt;

    if (_numberWords.containsKey(cleaned)) {
      return _numberWords[cleaned];
    }

    final words = cleaned.split(RegExp(r'[\s\-]+'));
    if (words.length == 2) {
      final tens = _numberWords[words[0]];
      final units = _numberWords[words[1]];
      if (tens != null &&
          units != null &&
          tens >= 20 &&
          tens <= 90 &&
          units < 10) {
        return tens + units;
      }
    }

    return null;
  }

  static ParsedActionIntent? _parseNote(String text, String raw, Stopwatch sw) {
    // Patterns:
    // "note down: buy milk" / "note down buy milk" / "take a note: buy milk" / "take note buy milk" / "new note: ..."
    // "remember to: ..." / "remember: ..." / "save idea: ..." / "add to shopping: ..."
    final noteRegex = RegExp(
      r'^(?:take\s+(?:a\s+)?note(?:\s+that|\s+to)?|note\s+down|note|new\s+note|remember(?:\s+to)?|save\s+(?:a\s+)?(?:note|idea|reminder)|add\s+(?:a\s+)?(?:note|reminder|item))(?:\s*[:,\-]\s*|\s+)(.+)$',
      caseSensitive: false,
    );

    final match = noteRegex.firstMatch(text);
    if (match != null) {
      final content = match.group(1)?.trim();
      if (content != null && content.isNotEmpty) {
        sw.stop();
        // Optional pre-tagging hint if explicitly uttered (e.g. "save idea: ...")
        String initialCategory = 'note';
        if (text.startsWith('save idea') || text.contains('idea:')) {
          initialCategory = 'idea';
        } else if (text.startsWith('remember') || text.contains('reminder')) {
          initialCategory = 'reminder';
        } else if (text.contains('shopping') || text.contains('grocery') || text.contains('buy')) {
          initialCategory = 'shopping';
        }

        return ParsedActionIntent(
          type: ActionType.takeNote,
          isMatched: true,
          rawTranscript: raw,
          parseLatencyMs: sw.elapsedMilliseconds,
          matchedRule: 'take_note',
          slots: {
            'noteContent': content,
            'noteCategory': initialCategory,
          },
        );
      }
    }
    return null;
  }
}
