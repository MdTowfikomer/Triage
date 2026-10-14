import 'package:flutter_test/flutter_test.dart';
import 'package:triage_flutter/parser/deterministic_volume_parser.dart';

void main() {
  group('DeterministicVolumeParser Tests', () {
    test('parses numeric percentages correctly', () {
      final res1 = DeterministicVolumeParser.parse('set volume to 50%');
      expect(res1.isMatched, isTrue);
      expect(res1.targetPercent, equals(50));

      final res2 = DeterministicVolumeParser.parse('volume to 70 percent');
      expect(res2.isMatched, isTrue);
      expect(res2.targetPercent, equals(70));

      final res3 = DeterministicVolumeParser.parse('turn volume up to 80');
      expect(res3.isMatched, isTrue);
      expect(res3.targetPercent, equals(80));

      final res4 = DeterministicVolumeParser.parse('volume 30');
      expect(res4.isMatched, isTrue);
      expect(res4.targetPercent, equals(30));
    });

    test('parses number words correctly', () {
      final res1 = DeterministicVolumeParser.parse('set volume to fifty percent');
      expect(res1.isMatched, isTrue);
      expect(res1.targetPercent, equals(50));

      final res2 = DeterministicVolumeParser.parse('volume thirty percent');
      expect(res2.isMatched, isTrue);
      expect(res2.targetPercent, equals(30));

      final res3 = DeterministicVolumeParser.parse('set volume to twenty five');
      expect(res3.isMatched, isTrue);
      expect(res3.targetPercent, equals(25));

      final res4 = DeterministicVolumeParser.parse('volume seventy five percent');
      expect(res4.isMatched, isTrue);
      expect(res4.targetPercent, equals(75));
    });

    test('parses special volume keywords (mute, max, half)', () {
      final resMute1 = DeterministicVolumeParser.parse('mute');
      expect(resMute1.isMatched, isTrue);
      expect(resMute1.targetPercent, equals(0));

      final resMute2 = DeterministicVolumeParser.parse('mute the volume');
      expect(resMute2.isMatched, isTrue);
      expect(resMute2.targetPercent, equals(0));

      final resMax = DeterministicVolumeParser.parse('set volume to max');
      expect(resMax.isMatched, isTrue);
      expect(resMax.targetPercent, equals(100));

      final resHalf = DeterministicVolumeParser.parse('half volume');
      expect(resHalf.isMatched, isTrue);
      expect(resHalf.targetPercent, equals(50));
    });

    test('rejects unrecognized intents deterministically', () {
      final res1 = DeterministicVolumeParser.parse('what is the weather today');
      expect(res1.isMatched, isFalse);
      expect(res1.targetPercent, isNull);

      final res2 = DeterministicVolumeParser.parse('open camera');
      expect(res2.isMatched, isFalse);
      expect(res2.targetPercent, isNull);

      final res3 = DeterministicVolumeParser.parse('');
      expect(res3.isMatched, isFalse);
      expect(res3.targetPercent, isNull);
    });

    test('strictly rejects negated commands', () {
      final negatedSamples = [
        "Don't set volume to 50",
        "dont set volume to 50",
        "do not set volume to 50",
        "never set volume to 50",
        "stop setting volume to 50",
        "don't mute the volume",
        "do not mute",
        "cancel volume setting",
      ];

      for (final sample in negatedSamples) {
        final res = DeterministicVolumeParser.parse(sample);
        expect(res.isMatched, isFalse, reason: 'Should reject: $sample');
        expect(res.targetPercent, isNull, reason: 'Target percent should be null for: $sample');
        expect(res.matchedRule, equals('rejected_negation'), reason: 'Should record rejected_negation rule for: $sample');
      }
    });

    test('strictly rejects compound or chained commands', () {
      final compoundSamples = [
        'set volume to 50 and turn on the lights',
        'set volume to 50 and mute',
        'set volume to 50 then open camera',
        'open camera then set volume to 50',
        "set volume to 50 but don't play music",
        'if it is loud set volume to 50',
        'set volume to 50 or 60',
      ];

      for (final sample in compoundSamples) {
        final res = DeterministicVolumeParser.parse(sample);
        expect(res.isMatched, isFalse, reason: 'Should reject compound: $sample');
        expect(res.targetPercent, isNull);
      }
    });

    test('strictly rejects unanchored sentences containing volume phrases', () {
      final unanchoredSamples = [
        'yesterday I set volume to 50 when training',
        'set volume to 50 for the party tonight',
      ];

      for (final sample in unanchoredSamples) {
        final res = DeterministicVolumeParser.parse(sample);
        expect(res.isMatched, isFalse, reason: 'Should reject unanchored sentence: $sample');
        expect(res.targetPercent, isNull);
      }
    });

    test('parses commands with politeness affixes and relative keywords', () {
      final res1 = DeterministicVolumeParser.parse('please set volume to 50%');
      expect(res1.isMatched, isTrue);
      expect(res1.targetPercent, equals(50));

      final res2 = DeterministicVolumeParser.parse('could you please mute the volume');
      expect(res2.isMatched, isTrue);
      expect(res2.targetPercent, equals(0));

      final res3 = DeterministicVolumeParser.parse('set volume to eighty percent please');
      expect(res3.isMatched, isTrue);
      expect(res3.targetPercent, equals(80));

      final res4 = DeterministicVolumeParser.parse('turn it up to 25%');
      expect(res4.isMatched, isTrue);
      expect(res4.targetPercent, equals(25));
    });

    test('operates with parsing latency < 5 ms', () {
      final res = DeterministicVolumeParser.parse('set volume to eighty percent');
      expect(res.parseLatencyMs, lessThanOrEqualTo(5));
    });
  });
}
