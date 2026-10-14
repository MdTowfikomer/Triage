import 'dart:core';

/// Typed intent result for volume extraction.
class VolumeIntent {
  final bool isMatched;
  final int? targetPercent; // 0 to 100
  final String rawTranscript;
  final int parseLatencyMs;
  final String? matchedRule;

  const VolumeIntent({
    required this.isMatched,
    this.targetPercent,
    required this.rawTranscript,
    required this.parseLatencyMs,
    this.matchedRule,
  });

  @override
  String toString() =>
      'VolumeIntent(isMatched: $isMatched, targetPercent: $targetPercent, parseLatency: ${parseLatencyMs}ms, rule: $matchedRule)';
}

/// Zero-network, strictly deterministic slot-filler regex parser for volume control.
class DeterministicVolumeParser {
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
    'one hundred': 100,
  };

  /// Parses an utterance transcript into a structured [VolumeIntent].
  /// Operates entirely in-memory with typical latency < 2 ms.
  static VolumeIntent parse(String rawTranscript) {
    final stopwatch = Stopwatch()..start();
    final normalized = _normalizeText(rawTranscript);

    // Rule 0a: Strictly reject negated commands ("don't set volume to 50", "do not mute", "never", "stop")
    if (_hasNegation(normalized)) {
      stopwatch.stop();
      return VolumeIntent(
        isMatched: false,
        targetPercent: null,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'rejected_negation',
      );
    }

    // Rule 0b: Strictly reject compound or multi-intent commands ("set volume to 50 and open camera", "open camera then set volume")
    if (_hasCompoundClause(normalized)) {
      stopwatch.stop();
      return VolumeIntent(
        isMatched: false,
        targetPercent: null,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'rejected_compound',
      );
    }

    // Strip polite preamble ("please", "could you", "hey triage") and trailing polite affixes ("please")
    final cleaned = _stripPoliteAffixes(normalized);

    final colloquial = RegExp(
      r'^(?:crank|raise|increase|lower|reduce)\s+(?:the\s+)?volume(?:\s+(?:up|down))?(?:\s+to)?\s+(\d+|[a-z]+(?:\s+[a-z]+)?)(?:\s*(?:%|percent))?$',
    ).firstMatch(cleaned);
    if (colloquial != null) {
      final value = _extractNumber(colloquial.group(1) ?? '');
      if (value != null && value <= 100) {
        stopwatch.stop();
        return VolumeIntent(
          isMatched: true,
          targetPercent: value,
          rawTranscript: rawTranscript,
          parseLatencyMs: stopwatch.elapsedMilliseconds,
          matchedRule: 'volume_colloquial_numeric',
        );
      }
    }

    if (cleaned == 'max volume' ||
        cleaned == 'full volume' ||
        cleaned == 'maximum volume') {
      stopwatch.stop();
      return VolumeIntent(
        isMatched: true,
        targetPercent: 100,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'volume_max',
      );
    }
    if (cleaned == 'silent mode' ||
        cleaned == 'silence' ||
        cleaned == 'unmute' ||
        cleaned == 'unsilence') {
      stopwatch.stop();
      return VolumeIntent(
        isMatched: true,
        targetPercent: cleaned == 'silent mode' || cleaned == 'silence'
            ? 0
            : 50,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'volume_silent_preset',
      );
    }

    // Rule 1: Direct Mute / Silence keywords
    if (_isMuteCommand(cleaned)) {
      stopwatch.stop();
      return VolumeIntent(
        isMatched: true,
        targetPercent: 0,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'mute_keyword',
      );
    }

    // Rule 2: Direct Maximum keywords
    if (_isMaxCommand(cleaned)) {
      stopwatch.stop();
      return VolumeIntent(
        isMatched: true,
        targetPercent: 100,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'max_keyword',
      );
    }

    // Rule 3: Fraction keywords ("half volume", "volume half", "half", "set volume to half")
    if (_isHalfCommand(cleaned)) {
      stopwatch.stop();
      return VolumeIntent(
        isMatched: true,
        targetPercent: 50,
        rawTranscript: rawTranscript,
        parseLatencyMs: stopwatch.elapsedMilliseconds,
        matchedRule: 'half_volume',
      );
    }

    // Rule 4: Anchored volume command with numeric percentage or number token
    // Matches patterns like:
    // "set volume to 50%", "volume to 70 percent", "turn volume up to 80",
    // "turn it up to 25%", "volume 30 percent", "set media volume to 40", "volume 50"
    final volumePrefixPattern = RegExp(
      r'^(?:(?:set|change|adjust|turn(?:\s+it)?(?:\s+(?:up|down))?|put)\s+)?(?:the\s+)?(?:media\s+|device\s+)?(?:volume|it)?\s*(?:level\s*)?(?:to|at|up to|down to)?\s*([a-z0-9\s\-%]+)$',
    );

    final match = volumePrefixPattern.firstMatch(cleaned);
    if (match != null) {
      final valuePart = match.group(1)?.trim() ?? '';
      final parsedNumber = _extractNumber(valuePart);
      if (parsedNumber != null && parsedNumber >= 0 && parsedNumber <= 100) {
        stopwatch.stop();
        return VolumeIntent(
          isMatched: true,
          targetPercent: parsedNumber,
          rawTranscript: rawTranscript,
          parseLatencyMs: stopwatch.elapsedMilliseconds,
          matchedRule: 'volume_prefix_numeric',
        );
      }
    }

    // Rule 5: Fallback standalone percentage expression like "50%", "50 percent"
    final standalonePercent = RegExp(
      r'^(\d+)\s*(?:%|percent)$',
    ).firstMatch(cleaned);
    if (standalonePercent != null) {
      final numVal = int.tryParse(standalonePercent.group(1) ?? '');
      if (numVal != null && numVal >= 0 && numVal <= 100) {
        stopwatch.stop();
        return VolumeIntent(
          isMatched: true,
          targetPercent: numVal,
          rawTranscript: rawTranscript,
          parseLatencyMs: stopwatch.elapsedMilliseconds,
          matchedRule: 'standalone_percent',
        );
      }
    }

    stopwatch.stop();
    return VolumeIntent(
      isMatched: false,
      targetPercent: null,
      rawTranscript: rawTranscript,
      parseLatencyMs: stopwatch.elapsedMilliseconds,
      matchedRule: null,
    );
  }

  static bool _hasNegation(String text) {
    final negationPattern = RegExp(
      r"\b(don't|dont|do not|never|not|stop|cancel|avoid|disallow|prevent|no)\b",
      caseSensitive: false,
    );
    return negationPattern.hasMatch(text);
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
        .replaceAll(RegExp(r'[,.!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isMuteCommand(String text) {
    return text == 'mute' ||
        text == 'mute volume' ||
        text == 'mute the volume' ||
        text == 'silence' ||
        text == 'silence volume' ||
        text == 'turn off volume' ||
        text == 'volume zero' ||
        text == 'volume to zero';
  }

  static bool _isMaxCommand(String text) {
    return text == 'max volume' ||
        text == 'maximum volume' ||
        text == 'full volume' ||
        text == 'set volume to max' ||
        text == 'set volume to maximum' ||
        text == 'volume max' ||
        text == 'volume to max' ||
        text == 'turn volume to max';
  }

  static bool _isHalfCommand(String text) {
    return text == 'half volume' ||
        text == 'volume half' ||
        text == 'half' ||
        text == 'set volume to half';
  }

  static int? _extractNumber(String tokenString) {
    // Clean trailing units like "percent", "%"
    var cleaned = tokenString.replaceAll('%', '').trim();
    if (cleaned.endsWith('percent')) {
      cleaned = cleaned.substring(0, cleaned.length - 7).trim();
    }

    // Check if directly an integer
    final directInt = int.tryParse(cleaned);
    if (directInt != null && directInt >= 0 && directInt <= 100)
      return directInt;

    // Check if directly a known number word
    if (_numberWords.containsKey(cleaned)) {
      return _numberWords[cleaned];
    }

    // Check compound words like "twenty five", "eighty five"
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
}
