import 'dart:math';

/// Fast, dependency-free RFC-4122 v4 UUID generator.
class UuidUtil {
  static final Random _random = Random.secure();

  static String generate() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));
    // Set version to 4
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to IETF (RFC 4122)
    values[8] = (values[8] & 0x3f) | 0x80;

    return [
      values.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(10, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    ].join('-');
  }
}
