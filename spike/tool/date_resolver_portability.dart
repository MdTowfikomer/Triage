import 'dart:convert';
import 'dart:js_interop';

// Deliberately compile the standalone file without Flutter package resolution.
// ignore: avoid_relative_lib_imports
import '../lib/core/date_resolver.dart';

@JS('resolverTestZone')
external JSString get _zone;
@JS('resolverTestResults')
external set _results(JSString value);

void main() {
  final zone = _zone.toDart;
  final passed = <String>[];
  void check(String name, Object? actual, Object? expected) {
    if (actual != expected) {
      throw StateError('$zone: $name: $actual != $expected');
    }
    passed.add(name);
  }

  DateTime? resolve(String text, DateTime reference, {String? timeZoneName}) =>
      DateResolver.resolve(
        text,
        referenceTime: reference,
        timeZoneName: timeZoneName,
      )?.dateTime;
  final local = DateTime(2026, 10, 7, 12);
  check(
    'local mode',
    resolve('tomorrow 3pm', local),
    DateTime(2026, 10, 8, 15),
  );
  check(
    'UTC mode',
    resolve('tomorrow 3pm', DateTime.utc(2026, 10, 7, 12)),
    DateTime.utc(2026, 10, 8, 15),
  );
  check(
    'date-only default',
    resolve('tomorrow', local),
    DateTime(2026, 10, 8, 9),
  );
  check(
    'STT punctuation',
    resolve('tomorrow 3p.m.', local),
    DateTime(2026, 10, 8, 15),
  );
  check(
    'elapsed duration',
    resolve('in 30 minutes', local),
    local.add(const Duration(minutes: 30)),
  );
  final instant = DateTime.utc(2026, 10, 7, 23);
  final converted = instant.toLocal();
  check(
    'UTC instant localized before date arithmetic',
    resolve('tomorrow 3pm', instant, timeZoneName: 'local'),
    DateTime(converted.year, converted.month, converted.day + 1, 15),
  );
  check(
    'UTC override',
    resolve('today 3pm', instant, timeZoneName: 'UTC'),
    DateTime.utc(2026, 10, 7, 15),
  );
  check(
    'leap-day century rollover',
    resolve('February 29', DateTime.utc(2096, 3, 1)),
    DateTime.utc(2104, 2, 29, 9),
  );
  check(
    'unknown zone rejected',
    resolve('tomorrow', local, timeZoneName: 'Mars/Olympus'),
    null,
  );

  if (zone == 'Asia/Kolkata') {
    check(
      'India UTC offset',
      local.timeZoneOffset,
      const Duration(hours: 5, minutes: 30),
    );
    check(
      'India UTC conversion',
      resolve('tomorrow 3pm', local)!.toUtc(),
      DateTime.utc(2026, 10, 8, 9, 30),
    );
  } else if (zone == 'America/New_York') {
    final spring = DateTime(2026, 3, 7, 9);
    final fall = DateTime(2026, 10, 31, 9);
    check(
      'spring calendar day is 23 elapsed hours',
      resolve('tomorrow 9am', spring)!.difference(spring),
      const Duration(hours: 23),
    );
    check(
      'fall calendar day is 25 elapsed hours',
      resolve('tomorrow 9am', fall)!.difference(fall),
      const Duration(hours: 25),
    );
    check(
      'spring elapsed day preserves 24 hours',
      resolve('in 1 day', spring),
      DateTime(2026, 3, 8, 10),
    );
    check(
      'fall elapsed day preserves 24 hours',
      resolve('in 1 day', fall),
      DateTime(2026, 11, 1, 8),
    );
    check('spring gap rejected', resolve('tomorrow 2:30am', spring), null);
    check('fall overlap rejected', resolve('tomorrow 1:30am', fall), null);
    check(
      'specific-date gap rejected',
      resolve('March 8 2:30am', spring),
      null,
    );
    check(
      'specific-date overlap rejected',
      resolve('November 1 1:30am', fall),
      null,
    );
    check('weekday overlap rejected', resolve('Sunday 1:30am', fall), null);
    check(
      'past weekday gap rolls to valid next week',
      resolve('Sunday 2:30am', DateTime(2026, 3, 8, 12)),
      DateTime(2026, 3, 15, 2, 30),
    );
    check(
      'fall duration reaches precise second occurrence',
      resolve('in 2 hours', DateTime(2026, 11, 1, 0, 30))!.toUtc(),
      DateTime.utc(2026, 11, 1, 6, 30),
    );
  } else if (zone == 'Australia/Lord_Howe') {
    final spring = DateTime(2026, 10, 3, 9);
    final fall = DateTime(2026, 4, 4, 9);
    check(
      'half-hour spring calendar change',
      resolve('tomorrow 9am', spring)!.difference(spring),
      const Duration(hours: 23, minutes: 30),
    );
    check(
      'half-hour fall calendar change',
      resolve('tomorrow 9am', fall)!.difference(fall),
      const Duration(hours: 24, minutes: 30),
    );
    check('half-hour gap rejected', resolve('tomorrow 2:15am', spring), null);
    check('half-hour overlap rejected', resolve('tomorrow 1:45am', fall), null);
  } else if (zone == 'Pacific/Apia') {
    final beforeSkip = DateTime(2011, 12, 29, 9);
    check('skipped civil day rejected', resolve('tomorrow', beforeSkip), null);
    check(
      'explicit skipped civil date rejected',
      resolve('December 30 2011', beforeSkip),
      null,
    );
    check(
      'elapsed duration across skipped civil day',
      resolve('in 1 day', beforeSkip),
      DateTime(2011, 12, 31, 9),
    );
  }
  _results = jsonEncode({
    'zone': zone,
    'passed': passed.length,
    'checks': passed,
  }).toJS;
}
