import 'desert_ant_redact_stub.dart'
    if (dart.library.js_interop) 'desert_ant_redact_web.dart'
    as bridge;

/// Deterministic defense-in-depth PII masking applied after intent extraction.
///
/// This deterministic fallback complements Desert Ant for formatted
/// identifiers. It does not detect every address or contextual PII by itself.
class PiiRedactor {
  const PiiRedactor();

  String redact(String input) {
    var text = input;
    text = text.replaceAll(
      RegExp(r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}', caseSensitive: false),
      '[EMAIL]',
    );
    text = text.replaceAll(RegExp(r'\b\d{3}[- ]\d{2}[- ]\d{4}\b'), '[SSN]');
    text = text.replaceAllMapped(_cardPattern, (match) {
      final digits = match[0]!.replaceAll(RegExp(r'\D'), '');
      return _passesLuhn(digits) ? '[CARD]' : match[0]!;
    });
    text = text.replaceAll(_addressPattern, '[ADDRESS]');
    text = text.replaceAllMapped(_phonePattern, (match) {
      final digits = match[0]!.replaceAll(RegExp(r'\D'), '');
      return digits.length >= 7 && digits.length <= 15 ? '[PHONE]' : match[0]!;
    });
    return text;
  }

  static final _cardPattern = RegExp(r'(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)');
  static final _addressPattern = RegExp(
    r"\b\d{1,6}\s+(?:[A-Z0-9.'-]+\s+){0,5}(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Way|Terrace|Ter|Place|Pl)\b(?:\s+(?:Apt|Apartment|Unit|Suite|Ste|#)\s*[A-Z0-9-]+)?",
    caseSensitive: false,
  );
  static final _phonePattern = RegExp(r'(?<![\w])\+?\d[\d(). -]{5,}\d(?![\w])');

  static bool _passesLuhn(String digits) {
    if (digits.length < 13 || digits.length > 19) return false;
    var sum = 0;
    var doubleDigit = false;
    for (final code in digits.codeUnits.reversed) {
      var digit = code - 48;
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }
}

String redactKnownPii(String input) => const PiiRedactor().redact(input);

abstract interface class PayloadRedactor {
  Future<List<String>> redact(List<String> inputs);
}

class LocalPayloadRedactor implements PayloadRedactor {
  const LocalPayloadRedactor();
  @override
  Future<List<String>> redact(List<String> inputs) async =>
      inputs.map(redactKnownPii).toList();
}

/// Calls the official Desert Ant model on-device. Errors propagate so the
/// caller can keep the draft local instead of sending unchecked text.
class DesertAntPayloadRedactor implements PayloadRedactor {
  const DesertAntPayloadRedactor();
  @override
  Future<List<String>> redact(List<String> inputs) async =>
      (await bridge.redactAll(inputs)).map(redactKnownPii).toList();
}
