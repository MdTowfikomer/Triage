import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:triage_flutter/voice/pcm16_buffer.dart';

void main() {
  group('Pcm16Buffer', () {
    test('preserves little-endian mono PCM chunks', () {
      final buffer = Pcm16Buffer(maxBytes: 8);
      buffer.add(Uint8List.fromList([0, 0, 255, 127]));
      buffer.add(Uint8List.fromList([0, 128, 1, 0]));

      expect(buffer.takeBytes(), [0, 0, 255, 127, 0, 128, 1, 0]);
      expect(buffer.truncated, isFalse);
    });

    test(
      'caps at the configured byte limit and preserves sample alignment',
      () {
        final buffer = Pcm16Buffer(maxBytes: 6);
        buffer.add(Uint8List.fromList([0, 0, 1, 0]));
        buffer.add(Uint8List.fromList([2, 0, 3, 0]));

        expect(buffer.length, 6);
        expect(buffer.takeBytes(), [0, 0, 1, 0, 2, 0]);
        expect(buffer.truncated, isTrue);
      },
    );

    test('drops a trailing half-sample rather than passing invalid PCM', () {
      final buffer = Pcm16Buffer(maxBytes: 16);
      buffer.add(Uint8List.fromList([0, 0, 255]));

      expect(buffer.takeBytes(), [0, 0]);
      expect(buffer.truncated, isTrue);
    });
  });
}
