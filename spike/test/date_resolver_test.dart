import 'package:flutter_test/flutter_test.dart';
import 'package:triage_spike/core/date_resolver.dart';

void main() {
  final reference = DateTime.utc(2026, 10, 7, 12, 34, 56, 789, 123);
  ResolvedDate? resolve(String input) =>
      DateResolver.resolve(input, referenceTime: reference);

  group('requested relative days and time normalization', () {
    final cases = <String, DateTime>{
      'today at 5pm': DateTime.utc(2026, 10, 7, 17),
      'today 17:00': DateTime.utc(2026, 10, 7, 17),
      'tomorrow at 3pm': DateTime.utc(2026, 10, 8, 15),
      'tomorrow 3 p.m.': DateTime.utc(2026, 10, 8, 15),
      'tomorrow 9am': DateTime.utc(2026, 10, 8, 9),
      'day after tomorrow at 10am': DateTime.utc(2026, 10, 9, 10),
      'tomorrow 3:00 PM': DateTime.utc(2026, 10, 8, 15),
      'tomorrow 15:00': DateTime.utc(2026, 10, 8, 15),
      'tomorrow at 3p.m.': DateTime.utc(2026, 10, 8, 15),
      'tomorrow at 3 P. M.': DateTime.utc(2026, 10, 8, 15),
      'tomorrow at 03:07 p.m.': DateTime.utc(2026, 10, 8, 15, 7),
      'tomorrow 3:00': DateTime.utc(2026, 10, 8, 3),
      'tomorrow 12am': DateTime.utc(2026, 10, 8),
      'tomorrow 12pm': DateTime.utc(2026, 10, 8, 12),
      'tomorrow 00:00': DateTime.utc(2026, 10, 8),
      'tomorrow 23:59': DateTime.utc(2026, 10, 8, 23, 59),
      '  TOMORROW\tAT\n3PM!  ': DateTime.utc(2026, 10, 8, 15),
      'tomorrow\u00a03\u202fp.m.': DateTime.utc(2026, 10, 8, 15),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final result = resolve(entry.key)!;
        expect(result.dateTime, entry.value);
        expect(result.hasExplicitTime, isTrue);
        expect(result.usedDefaultTime, isFalse);
        expect(result.matchedText, entry.key.trim());
        expect(result.dateTime.second, 0);
        expect(result.dateTime.microsecond, 0);
      });
    }
  });

  group('default time and past scheduling metadata', () {
    for (final entry in <String, DateTime>{
      'today': DateTime.utc(2026, 10, 7, 9),
      'tomorrow': DateTime.utc(2026, 10, 8, 9),
      'day after tomorrow': DateTime.utc(2026, 10, 9, 9),
      'Friday': DateTime.utc(2026, 10, 9, 9),
      'October 14': DateTime.utc(2026, 10, 14, 9),
    }.entries) {
      test(entry.key, () {
        final result = resolve(entry.key)!;
        expect(result.dateTime, entry.value);
        expect(result.hasExplicitTime, isFalse);
        expect(result.usedDefaultTime, isTrue);
        expect(result.isPast, entry.key == 'today');
      });
    }
    test('product default can be configured to 18:30', () {
      final result = DateResolver.resolve(
        'tomorrow',
        referenceTime: reference,
        defaultHour: 18,
        defaultMinute: 30,
      )!;
      expect(result.dateTime, DateTime.utc(2026, 10, 8, 18, 30));
      expect(result.usedDefaultTime, isTrue);
    });
    test('an explicitly past today stays today', () {
      final result = resolve('today at 9am')!;
      expect(result.dateTime, DateTime.utc(2026, 10, 7, 9));
      expect(result.isPast, isTrue);
      expect(result.hasExplicitTime, isTrue);
    });
    test('no injected clock uses device-local mode', () {
      expect(DateResolver.resolve('tomorrow')!.dateTime.isUtc, isFalse);
    });
    test('UTC conversion preserves the instant', () {
      final result = DateResolver.resolve(
        'tomorrow 3pm',
        referenceTime: DateTime(2026, 10, 7, 12),
      )!;
      expect(result.dateTime.isUtc, isFalse);
      expect(result.utcDateTime.isUtc, isTrue);
      expect(result.utcDateTime.isAtSameMomentAs(result.dateTime), isTrue);
    });
  });

  group('weekdays and next-calendar-week semantics', () {
    final cases = <String, DateTime>{
      'Friday': DateTime.utc(2026, 10, 9, 9),
      'this Friday at 4pm': DateTime.utc(2026, 10, 9, 16),
      'next Monday at 9am': DateTime.utc(2026, 10, 12, 9),
      'next Friday at 4pm': DateTime.utc(2026, 10, 16, 16),
      'Monday 10am': DateTime.utc(2026, 10, 12, 10),
      'Tuesday 10am': DateTime.utc(2026, 10, 13, 10),
      'Wednesday 1pm': DateTime.utc(2026, 10, 7, 13),
      'Wednesday 12pm': DateTime.utc(2026, 10, 14, 12),
      'Thursday 10am': DateTime.utc(2026, 10, 8, 10),
      'Saturday 10am': DateTime.utc(2026, 10, 10, 10),
      'Sunday 10am': DateTime.utc(2026, 10, 11, 10),
    };
    for (final entry in cases.entries) {
      test(entry.key, () => expect(resolve(entry.key)!.dateTime, entry.value));
    }
    for (final prefix in ['', 'this ']) {
      test('${prefix}Friday before scheduled time stays today', () {
        expect(
          DateResolver.resolve(
            '${prefix}Friday 4pm',
            referenceTime: DateTime.utc(2026, 10, 9, 15),
          )!.dateTime,
          DateTime.utc(2026, 10, 9, 16),
        );
      });
      test('${prefix}Friday after scheduled time rolls to next week', () {
        expect(
          DateResolver.resolve(
            '${prefix}Friday 4pm',
            referenceTime: DateTime.utc(2026, 10, 9, 17),
          )!.dateTime,
          DateTime.utc(2026, 10, 16, 16),
        );
      });
    }
    test('past weekday default rolls to next week', () {
      expect(
        DateResolver.resolve(
          'Friday',
          referenceTime: DateTime.utc(2026, 10, 9, 10),
        )!.dateTime,
        DateTime.utc(2026, 10, 16, 9),
      );
    });
    test('weekday time exactly equal to reference is not past', () {
      expect(
        DateResolver.resolve(
          'Friday 9am',
          referenceTime: DateTime.utc(2026, 10, 9, 9),
        )!.dateTime,
        DateTime.utc(2026, 10, 9, 9),
      );
    });
    test('seconds after the weekday time roll to next week', () {
      expect(
        DateResolver.resolve(
          'Friday 9am',
          referenceTime: DateTime.utc(2026, 10, 9, 9, 0, 1),
        )!.dateTime,
        DateTime.utc(2026, 10, 16, 9),
      );
    });
    test('next Monday on Monday is seven days later', () {
      expect(
        DateResolver.resolve(
          'next Monday 9am',
          referenceTime: DateTime.utc(2026, 10, 12, 8),
        )!.dateTime,
        DateTime.utc(2026, 10, 19, 9),
      );
    });
    test('next Monday on Sunday is tomorrow', () {
      expect(
        DateResolver.resolve(
          'next Monday 9am',
          referenceTime: DateTime.utc(2026, 10, 11, 8),
        )!.dateTime,
        DateTime.utc(2026, 10, 12, 9),
      );
    });
    test('weekday rolls across the year boundary', () {
      expect(
        DateResolver.resolve(
          'Friday',
          referenceTime: DateTime.utc(2026, 12, 31, 12),
        )!.dateTime,
        DateTime.utc(2027, 1, 1, 9),
      );
    });
  });

  group('elapsed durations', () {
    for (final entry in <String, Duration>{
      'in 2 hours': const Duration(hours: 2),
      'in 30 minutes': const Duration(minutes: 30),
      'in 1 day': const Duration(days: 1),
      'in 1 hour': const Duration(hours: 1),
      'in 1 minute': const Duration(minutes: 1),
      'in 2 days': const Duration(days: 2),
    }.entries) {
      test(entry.key, () {
        final result = resolve(entry.key)!;
        expect(result.dateTime, reference.add(entry.value));
        expect(result.hasExplicitTime, isTrue);
        expect(result.usedDefaultTime, isFalse);
        expect(result.isPast, isFalse);
      });
    }
    test('duration crosses midnight and year without truncating precision', () {
      final result = DateResolver.resolve(
        'in 30 minutes',
        referenceTime: DateTime.utc(2026, 12, 31, 23, 50, 5, 4, 3),
      )!;
      expect(result.dateTime, DateTime.utc(2027, 1, 1, 0, 20, 5, 4, 3));
    });
  });

  group('specific month-name dates', () {
    for (final entry in <String, DateTime>{
      'October 14 at 10am': DateTime.utc(2026, 10, 14, 10),
      '14th Oct 3pm': DateTime.utc(2026, 10, 14, 15),
      'Oct. 14 15:00': DateTime.utc(2026, 10, 14, 15),
      '14 October 2026 at 3 p.m.': DateTime.utc(2026, 10, 14, 15),
      'October 14, 2027 at 10am': DateTime.utc(2027, 10, 14, 10),
      '1st Jan 2027': DateTime.utc(2027, 1, 1, 9),
      '2nd Nov': DateTime.utc(2026, 11, 2, 9),
      '3rd Nov': DateTime.utc(2026, 11, 3, 9),
      '11th Nov': DateTime.utc(2026, 11, 11, 9),
      '12th Nov': DateTime.utc(2026, 11, 12, 9),
      '13th Nov': DateTime.utc(2026, 11, 13, 9),
      '21st Nov': DateTime.utc(2026, 11, 21, 9),
      '22nd Nov': DateTime.utc(2026, 11, 22, 9),
      '23rd Nov': DateTime.utc(2026, 11, 23, 9),
      '31st Dec': DateTime.utc(2026, 12, 31, 9),
      'Sept 14': DateTime.utc(2027, 9, 14, 9),
      'October 7 1pm': DateTime.utc(2026, 10, 7, 13),
      'October 7 10am': DateTime.utc(2027, 10, 7, 10),
      'October 7 2025 at 10am': DateTime.utc(2025, 10, 7, 10),
      'February 29': DateTime.utc(2028, 2, 29, 9),
    }.entries) {
      test(entry.key, () => expect(resolve(entry.key)!.dateTime, entry.value));
    }
    test('explicit past year is flagged without rewriting it', () {
      expect(resolve('October 7 2025 at 10am')!.isPast, isTrue);
    });
    for (var month = 1; month <= 12; month++) {
      final names = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      test('${names[month - 1]} full name', () {
        expect(
          resolve('${names[month - 1]} 14 2027')!.dateTime,
          DateTime.utc(2027, month, 14, 9),
        );
      });
    }
  });

  group('calendar boundaries and Gregorian leap years', () {
    for (final entry in <DateTime, DateTime>{
      DateTime.utc(2026, 1, 31, 23): DateTime.utc(2026, 2, 1, 15),
      DateTime.utc(2026, 2, 28, 23): DateTime.utc(2026, 3, 1, 15),
      DateTime.utc(2024, 2, 28, 23): DateTime.utc(2024, 2, 29, 15),
      DateTime.utc(2024, 2, 29, 23): DateTime.utc(2024, 3, 1, 15),
      DateTime.utc(2026, 4, 30, 23): DateTime.utc(2026, 5, 1, 15),
      DateTime.utc(2026, 12, 31, 23): DateTime.utc(2027, 1, 1, 15),
    }.entries) {
      test('tomorrow from ${entry.key}', () {
        expect(
          DateResolver.resolve(
            'tomorrow 3pm',
            referenceTime: entry.key,
          )!.dateTime,
          entry.value,
        );
      });
    }
    test('day after tomorrow crosses month', () {
      expect(
        DateResolver.resolve(
          'day after tomorrow 10am',
          referenceTime: DateTime.utc(2026, 1, 30),
        )!.dateTime,
        DateTime.utc(2026, 2, 1, 10),
      );
    });
    test('yearless date rolls over December to January', () {
      expect(
        DateResolver.resolve(
          'January 1',
          referenceTime: DateTime.utc(2026, 12, 31),
        )!.dateTime,
        DateTime.utc(2027, 1, 1, 9),
      );
    });
    test('yearless leap day skips non-leap century', () {
      expect(
        DateResolver.resolve(
          'February 29',
          referenceTime: DateTime.utc(2096, 3, 1),
        )!.dateTime,
        DateTime.utc(2104, 2, 29, 9),
      );
    });
    test('year divisible by 400 is a leap year', () {
      expect(
        resolve('February 29 2000')!.dateTime,
        DateTime.utc(2000, 2, 29, 9),
      );
    });
  });

  group('timezone contract', () {
    for (final zone in ['UTC', 'utc', ' Etc/UTC ', 'GMT', 'Z']) {
      test(zone, () {
        final result = DateResolver.resolve(
          'tomorrow 3pm',
          referenceTime: DateTime(2026, 10, 7, 12),
          timeZoneName: zone,
        )!;
        final utcReference = DateTime(2026, 10, 7, 12).toUtc();
        expect(
          result.dateTime,
          DateTime.utc(
            utcReference.year,
            utcReference.month,
            utcReference.day + 1,
            15,
          ),
        );
        expect(result.dateTime.isUtc, isTrue);
      });
    }
    test(
      'local mode converts the instant before choosing the calendar day',
      () {
        final instant = DateTime.utc(2026, 10, 7, 23);
        final local = instant.toLocal();
        final result = DateResolver.resolve(
          'tomorrow 3pm',
          referenceTime: instant,
          timeZoneName: 'local',
        )!;
        expect(
          result.dateTime,
          DateTime(local.year, local.month, local.day + 1, 15),
        );
        expect(result.dateTime.isUtc, isFalse);
      },
    );
    test('the exact device-local timezone label is accepted', () {
      final local = DateTime(2026, 10, 7, 12);
      expect(
        DateResolver.resolve(
          'tomorrow',
          referenceTime: local,
          timeZoneName: local.timeZoneName,
        ),
        isNotNull,
      );
    });
    for (final zone in [
      'America/New_York',
      'Asia/Kolkata',
      'UTC+05:30',
      'IST',
      '',
      'Mars/Olympus',
    ]) {
      test('unsupported explicit zone $zone fails safely', () {
        expect(
          DateResolver.resolve(
            'tomorrow',
            referenceTime: reference,
            timeZoneName: zone,
          ),
          isNull,
        );
      });
    }
  });

  group('invalid or ambiguous fields return null without exceptions', () {
    for (final input in [
      '',
      '   ',
      'buy milk',
      'client meeting went well',
      'not a date',
      'yesterday',
      'next month',
      '2026-10-14',
      '14/10/2026',
      'tomorrow at 3',
      'tomorrow 15',
      'tomorrow at',
      'tomorrow 3p',
      'tomorrow 24:00',
      'tomorrow 25:00',
      'tomorrow 3:60pm',
      'tomorrow 0pm',
      'tomorrow 13pm',
      'tomorrow 15:00 PM',
      'tomorrow -1:00',
      'tomorrow 3:0pm',
      'tomorrow 3:00:00pm',
      'tomorrow 3pm garbage',
      'Friday or Monday',
      'tomorrow and Friday',
      'Remind me to call the dentist tomorrow at 3pm',
      'Fix the login bug by Friday, high priority',
      'in 0 hours',
      'in -2 hours',
      'in 1.5 hours',
      'in two hours',
      'in 2 hours tomorrow',
      'in 1 day at 3pm',
      'in 999999999999999999999999 hours',
      'in 36526 days',
      'April 31',
      'February 30',
      'October 0',
      'October 32',
      'February 29 2026',
      'February 29 1900',
      'October 14 0000',
      '14st Oct',
      '11st Nov',
      '23th Nov',
      'Foo 14 3pm',
      'October 14 at 99am',
    ]) {
      test(input.isEmpty ? 'empty input' : input, () {
        expect(() => resolve(input), returnsNormally);
        expect(resolve(input), isNull);
      });
    }
    test(
      'unbounded input rejected',
      () => expect(resolve('tomorrow ${'x' * 300}'), isNull),
    );
    for (final hour in [-1, 24]) {
      test(
        'invalid default hour $hour',
        () => expect(
          DateResolver.resolve(
            'tomorrow',
            referenceTime: reference,
            defaultHour: hour,
          ),
          isNull,
        ),
      );
    }
    for (final minute in [-1, 60]) {
      test(
        'invalid default minute $minute',
        () => expect(
          DateResolver.resolve(
            'tomorrow',
            referenceTime: reference,
            defaultMinute: minute,
          ),
          isNull,
        ),
      );
    }
    test('DateTime maximum overflow rejected', () {
      expect(
        DateResolver.resolve(
          'in 1 day',
          referenceTime: DateTime.utc(275760, 9, 13),
        ),
        isNull,
      );
    });
  });
}
