import 'package:flutter_test/flutter_test.dart';
import 'package:triage_flutter/parser/deterministic_action_parser.dart';

void main() {
  group('DeterministicActionParser Tests', () {
    test('parses brightness commands with numbers and keywords', () {
      final p1 = DeterministicActionParser.parse('set brightness to 50%');
      expect(p1.isBrightness, isTrue);
      expect(p1.slots['targetPercent'], equals(50));

      final p2 = DeterministicActionParser.parse('turn brightness up to 80');
      expect(p2.isBrightness, isTrue);
      expect(p2.slots['targetPercent'], equals(80));

      final p3 = DeterministicActionParser.parse('max brightness');
      expect(p3.isBrightness, isTrue);
      expect(p3.slots['targetPercent'], equals(100));

      final p4 = DeterministicActionParser.parse('dim screen');
      expect(p4.isBrightness, isTrue);
      expect(p4.slots['targetPercent'], equals(10));
    });

    test('parses Do Not Disturb commands', () {
      final p1 = DeterministicActionParser.parse('turn on do not disturb');
      expect(p1.isDnd, isTrue);
      expect(p1.slots['enabled'], isTrue);

      final p2 = DeterministicActionParser.parse('enable dnd');
      expect(p2.isDnd, isTrue);
      expect(p2.slots['enabled'], isTrue);

      final p3 = DeterministicActionParser.parse('turn off do not disturb');
      expect(p3.isDnd, isTrue);
      expect(p3.slots['enabled'], isFalse);

      final p4 = DeterministicActionParser.parse('disable dnd');
      expect(p4.isDnd, isTrue);
      expect(p4.slots['enabled'], isFalse);
    });

    test('parses timer commands in seconds, minutes, and hours', () {
      final p1 = DeterministicActionParser.parse('set a timer for 5 minutes');
      expect(p1.isTimer, isTrue);
      expect(p1.slots['seconds'], equals(300));

      final p2 = DeterministicActionParser.parse('timer 30 seconds');
      expect(p2.isTimer, isTrue);
      expect(p2.slots['seconds'], equals(30));

      final p3 = DeterministicActionParser.parse('set 1 minute timer');
      expect(p3.isTimer, isTrue);
      expect(p3.slots['seconds'], equals(60));
    });

    test('parses alarm commands with AM/PM and minutes', () {
      final p1 = DeterministicActionParser.parse('set an alarm for 7:30 am');
      expect(p1.isAlarm, isTrue);
      expect(p1.slots['hour'], equals(7));
      expect(p1.slots['minutes'], equals(30));

      final p2 = DeterministicActionParser.parse('alarm for 8 pm');
      expect(p2.isAlarm, isTrue);
      expect(p2.slots['hour'], equals(20));
      expect(p2.slots['minutes'], equals(0));

      final p3 = DeterministicActionParser.parse('wake me up at 6 am');
      expect(p3.isAlarm, isTrue);
      expect(p3.slots['hour'], equals(6));
    });

    test('parses app opening commands', () {
      final p1 = DeterministicActionParser.parse('open camera');
      expect(p1.isOpenApp, isTrue);
      expect(p1.slots['appName'], equals('camera'));

      final p2 = DeterministicActionParser.parse('launch whatsapp');
      expect(p2.isOpenApp, isTrue);
      expect(p2.slots['appName'], equals('whatsapp'));

      final p3 = DeterministicActionParser.parse('open maps');
      expect(p3.isOpenApp, isTrue);
      expect(p3.slots['appName'], equals('maps'));

      final p4 = DeterministicActionParser.parse('take a picture');
      expect(p4.isOpenApp, isTrue);
      expect(p4.slots['appName'], equals('camera'));
    });

    test('parses media playback and track skipping commands', () {
      final p1 = DeterministicActionParser.parse('next track');
      expect(p1.isMedia, isTrue);
      expect(p1.slots['command'], equals('next'));

      final p2 = DeterministicActionParser.parse('skip song');
      expect(p2.isMedia, isTrue);
      expect(p2.slots['command'], equals('next'));

      final p3 = DeterministicActionParser.parse('previous track');
      expect(p3.isMedia, isTrue);
      expect(p3.slots['command'], equals('previous'));

      final p4 = DeterministicActionParser.parse('pause music');
      expect(p4.isMedia, isTrue);
      expect(p4.slots['command'], equals('pause'));

      final p5 = DeterministicActionParser.parse('play music');
      expect(p5.isMedia, isTrue);
      expect(p5.slots['command'], equals('play'));
    });

    test('delegates volume commands accurately', () {
      final p1 = DeterministicActionParser.parse('set volume to 40 percent');
      expect(p1.isVolume, isTrue);
      expect(p1.slots['targetPercent'], equals(40));

      final p2 = DeterministicActionParser.parse('mute');
      expect(p2.isVolume, isTrue);
      expect(p2.slots['targetPercent'], equals(0));
    });

    test('strictly rejects negated commands across all action types', () {
      final n1 = DeterministicActionParser.parse("don't set brightness to 50");
      expect(n1.isMatched, isFalse);
      expect(n1.matchedRule, equals('rejected_negation'));

      final n2 = DeterministicActionParser.parse(
        'do not turn on do not disturb',
      );
      expect(n2.isMatched, isFalse);
      expect(n2.matchedRule, equals('rejected_negation'));

      final n3 = DeterministicActionParser.parse('never open camera');
      expect(n3.isMatched, isFalse);
      expect(n3.matchedRule, equals('rejected_negation'));
    });

    test('parses call and dial commands', () {
      final p1 = DeterministicActionParser.parse('call Ayesha');
      expect(p1.isDialContact, isTrue);
      expect(p1.contactName, equals('ayesha'));

      final p2 = DeterministicActionParser.parse('dial John Doe');
      expect(p2.isDialContact, isTrue);
      expect(p2.contactName, equals('john doe'));
    });

    test(
      'parses WhatsApp message commands with recipient and message body',
      () {
        final p1 = DeterministicActionParser.parse(
          "whatsapp Ayesha: I am on the way",
        );
        expect(p1.isComposeWhatsApp, isTrue);
        expect(p1.contactName, equals('ayesha'));
        expect(p1.messageText, equals('i am on the way'));

        final p2 = DeterministicActionParser.parse(
          "send a whatsapp to Mom saying please buy milk",
        );
        expect(p2.isComposeWhatsApp, isTrue);
        expect(p2.contactName, equals('mom'));
        expect(p2.messageText, equals('please buy milk'));

        final p3 = DeterministicActionParser.parse(
          "WhatsApp Dad I am on my way",
        );
        expect(p3.isComposeWhatsApp, isTrue);
        expect(p3.contactName, equals('dad'));
        expect(p3.messageText, equals('i am on my way'));
      },
    );

    test('parses SMS and text message commands', () {
      final p1 = DeterministicActionParser.parse(
        "text Bob: running 5 minutes late",
      );
      expect(p1.isComposeSms, isTrue);
      expect(p1.contactName, equals('bob'));
      expect(p1.messageText, equals('running 5 minutes late'));

      final p2 = DeterministicActionParser.parse(
        "message Alice saying hello there",
      );
      expect(p2.isComposeSms, isTrue);
      expect(p2.contactName, equals('alice'));
      expect(p2.messageText, equals('hello there'));
    });

    test('parses navigation commands', () {
      final p1 = DeterministicActionParser.parse("start navigation to home");
      expect(p1.isNavigation, isTrue);
      expect(p1.destination, equals('home'));

      final p2 = DeterministicActionParser.parse("navigate to central park");
      expect(p2.isNavigation, isTrue);
      expect(p2.destination, equals('central park'));
    });

    test('strictly rejects compound clauses across all action types', () {
      final c1 = DeterministicActionParser.parse(
        'open camera and set volume to 50',
      );
      expect(c1.isMatched, isFalse);
      expect(c1.matchedRule, equals('rejected_compound'));

      final c2 = DeterministicActionParser.parse(
        'set brightness to 50 then next track',
      );
      expect(c2.isMatched, isFalse);
      expect(c2.matchedRule, equals('rejected_compound'));
    });

    test('parses offline device shortcuts and volume presets', () {
      for (final phrase in ['turn on flashlight', 'torch on']) {
        final parsed = DeterministicActionParser.parse(phrase);
        expect(parsed.isOpenApp, isTrue);
        expect(parsed.appName, 'torch_on');
      }
      expect(
        DeterministicActionParser.parse('battery percentage').appName,
        'battery_status',
      );
      expect(
        DeterministicActionParser.parse('open whatsapp business').appName,
        'whatsapp business',
      );
      expect(DeterministicActionParser.parse('max volume').targetPercent, 100);
      expect(DeterministicActionParser.parse('silent mode').targetPercent, 0);
      expect(
        DeterministicActionParser.parse('half brightness').brightnessPercent,
        50,
      );
    });
  });
}
