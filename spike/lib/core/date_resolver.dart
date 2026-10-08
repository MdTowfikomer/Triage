/// A resolved instant plus the information needed to review a schedule.
class ResolvedDate {
  const ResolvedDate({
    required this.dateTime,
    required this.hasExplicitTime,
    required this.matchedText,
    required this.isPast,
  });

  final DateTime dateTime;

  /// False only when a calendar expression used the configured default time.
  /// An explicit duration also determines an exact time, so this is true for it.
  final bool hasExplicitTime;

  /// The original expression, trimmed but otherwise preserved.
  final String matchedText;

  /// Compared with the captured reference clock, not a later DateTime.now().
  final bool isPast;

  bool get usedDefaultTime => !hasExplicitTime;
  DateTime get utcDateTime => dateTime.toUtc();
}

/// Deterministic English temporal-field parser using only dart:core.
///
/// Parses the entire field, not arbitrary transcript fragments. Unknown or
/// ambiguous syntax, invalid dates/times, unsupported zones, and DST gaps or
/// overlaps return null. No model, network, platform imports or timezone tables.
///
/// Without [timeZoneName], the reference's UTC/local mode is preserved; an
/// omitted reference uses the device's local clock. Zone names may be `local`,
/// `UTC`, `Etc/UTC`, `GMT`, `Z`, or the reference's exact local zone label.
/// Arbitrary IANA names cannot be resolved by dart:core and are rejected.
class DateResolver {
  DateResolver._();

  static final _relativeDay = RegExp(
    r'^(day after tomorrow|tomorrow|today)(?:\s+(?:at\s+)?(.+))?$',
  );
  static final _weekday = RegExp(
    r'^(?:(this|next)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(?:at\s+)?(.+))?$',
  );
  static final _duration = RegExp(r'^in\s+(\d+)\s+(minute|hour|day)s?$');
  static final _clock = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$');
  static final _meridiem = RegExp(r'([ap])\s*\.?\s*m\.?');
  static const _weekdays = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };
  static const _hourWords = {
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'eleven': '11',
    'twelve': '12',
  };
  static const _months = {
    'january': 1,
    'jan': 1,
    'february': 2,
    'feb': 2,
    'march': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'june': 6,
    'jun': 6,
    'july': 7,
    'jul': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sep': 9,
    'sept': 9,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
  };
  static final _monthNames = _months.keys.join('|');
  static final _monthFirst = RegExp(
    '^($_monthNames)\\.?\\s+(\\d{1,2})(st|nd|rd|th)?(?:\\s*,?\\s+(\\d{4}))?(?:\\s+(?:at\\s+)?(.+))?\$',
  );
  static final _dayFirst = RegExp(
    '^(\\d{1,2})(st|nd|rd|th)?\\s+($_monthNames)\\.?(?:\\s*,?\\s+(\\d{4}))?(?:\\s+(?:at\\s+)?(.+))?\$',
  );

  /// Date-only defaults are 09:00. Customize with [defaultHour]/[defaultMinute].
  /// Bare/`this` weekdays mean the upcoming occurrence, including today; if its
  /// chosen time has passed, advance seven calendar days. `next` means the
  /// named day of the next Monday–Sunday calendar week.
  /// Yearless specific dates choose the next occurrence, including today;
  /// Feb 29 searches forward to the next leap year. Explicit years and `today`
  /// retain their stated dates even in the past (see [ResolvedDate.isPast]).
  /// Durations are positive whole elapsed units (`in 1 day` = 24 hours).
  static ResolvedDate? resolve(
    String input, {
    DateTime? referenceTime,
    String? timeZoneName,
    int defaultHour = 9,
    int defaultMinute = 0,
  }) {
    if (defaultHour < 0 ||
        defaultHour > 23 ||
        defaultMinute < 0 ||
        defaultMinute > 59) {
      return null;
    }
    final original = input.trim();
    if (original.isEmpty || original.length > 256) return null;
    var reference = referenceTime ?? DateTime.now();
    if (timeZoneName != null) {
      final zone = timeZoneName.trim().toLowerCase();
      if (const {'utc', 'etc/utc', 'gmt', 'z'}.contains(zone)) {
        reference = reference.toUtc();
      } else if (zone == 'local') {
        reference = reference.toLocal();
      } else if (reference.isUtc ||
          zone != reference.timeZoneName.toLowerCase()) {
        return null;
      }
    }
    // Permit punctuation from STT without changing matchedText's provenance.
    var text = original.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceFirst(RegExp(r'[.!?]+$'), '').trim();
    text = text.replaceAllMapped(_meridiem, (match) => '${match[1]}m');

    // Normalize spoken clock words before time evaluation
    for (final entry in _hourWords.entries) {
      text = text.replaceAll(
        RegExp(r'\b' + entry.key + r'(?=\s*(?:am|pm|o[\x27\s]?clock|:\d{2}))\b'),
        entry.value,
      );
    }

    try {
      final duration = _duration.firstMatch(text);
      if (duration != null) {
        final count = int.tryParse(duration[1]!);
        // Bound multiplication below JS's exact-integer limit and DateTime's
        // supported range. A human scheduling interval over 100 years is invalid.
        if (count == null || count <= 0) return null;
        final secondsPerUnit = switch (duration[2]) {
          'minute' => 60,
          'hour' => 3600,
          _ => 86400,
        };
        if (count > 36525 * 86400 ~/ secondsPerUnit) return null;
        return _result(
          reference.add(Duration(seconds: count * secondsPerUnit)),
          reference,
          original,
          true,
        );
      }

      final day = _relativeDay.firstMatch(text);
      if (day != null) {
        final time = _time(day[2], defaultHour, defaultMinute);
        if (time == null) return null;
        final offset = switch (day[1]) {
          'today' => 0,
          'tomorrow' => 1,
          _ => 2,
        };
        final date = _calendarOffset(reference, offset, time);
        return date == null
            ? null
            : _result(date, reference, original, day[2] != null);
      }

      final weekday = _weekday.firstMatch(text);
      if (weekday != null) {
        final time = _time(weekday[3], defaultHour, defaultMinute);
        if (time == null) return null;
        final target = _weekdays[weekday[2]]!;
        var offset = weekday[1] == 'next'
            ? 7 + target - reference.weekday
            : (target - reference.weekday + 7) % 7;
        if (offset == 0 &&
            DateTime.utc(2000, 1, 1, time.$1, time.$2).isBefore(
              DateTime.utc(
                2000,
                1,
                1,
                reference.hour,
                reference.minute,
                reference.second,
                reference.millisecond,
                reference.microsecond,
              ),
            )) {
          offset = 7;
        }
        var date = _calendarOffset(reference, offset, time);
        if (date == null) return null;
        if (date.isBefore(reference)) {
          offset += 7;
          date = _calendarOffset(reference, offset, time);
        }
        return date == null
            ? null
            : _result(date, reference, original, weekday[3] != null);
      }

      final monthFirst = _monthFirst.firstMatch(text);
      final dayFirst = _dayFirst.firstMatch(text);
      final match = monthFirst ?? dayFirst;
      if (match == null) return null;
      final month = _months[monthFirst != null ? match[1] : match[3]]!;
      final dayOfMonth = int.parse((monthFirst != null ? match[2] : match[1])!);
      final suffix = monthFirst != null ? match[3] : match[2];
      if (suffix != null && suffix != _ordinal(dayOfMonth)) return null;
      if (dayOfMonth < 1 || dayOfMonth > _daysInMonth(2000, month)) return null;
      final time = _time(match[5], defaultHour, defaultMinute);
      if (time == null) return null;
      final statedYear = match[4] == null ? null : int.parse(match[4]!);
      if (statedYear != null) {
        if (statedYear < 1) return null;
        final date = _at(statedYear, month, dayOfMonth, time, reference.isUtc);
        return date == null
            ? null
            : _result(date, reference, original, match[5] != null);
      }
      // Eight years spans a skipped leap year at a non-400-divisible century.
      for (var year = reference.year; year <= reference.year + 8; year++) {
        if (dayOfMonth > _daysInMonth(year, month)) continue;
        final wall = DateTime.utc(year, month, dayOfMonth, time.$1, time.$2);
        final referenceWall = DateTime.utc(
          reference.year,
          reference.month,
          reference.day,
          reference.hour,
          reference.minute,
          reference.second,
          reference.millisecond,
          reference.microsecond,
        );
        if (wall.isBefore(referenceWall)) continue;
        // Do not silently jump to another year to escape an invalid DST time.
        final date = _at(year, month, dayOfMonth, time, reference.isUtc);
        return date == null
            ? null
            : _result(date, reference, original, match[5] != null);
      }
      return null;
    } on ArgumentError {
      // DateTime overflow or invalid runtime construction is a parse failure.
      return null;
    }
  }

  static (int, int)? _time(String? value, int hour, int minute) {
    if (value == null) return (hour, minute);
    final match = _clock.firstMatch(value);
    if (match == null || (match[2] == null && match[3] == null)) return null;
    hour = int.parse(match[1]!);
    minute = match[2] == null ? 0 : int.parse(match[2]!);
    if (minute > 59) return null;
    final meridiem = match[3];
    if (meridiem == null) return hour <= 23 ? (hour, minute) : null;
    if (hour < 1 || hour > 12) return null;
    return (hour % 12 + (meridiem == 'pm' ? 12 : 0), minute);
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return 'th';
    return switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }

  static int _daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  static DateTime? _calendarOffset(
    DateTime reference,
    int days,
    (int, int) time,
  ) {
    // Calendar arithmetic, rather than elapsed Duration(days: ...), preserves
    // the intended local wall clock across DST and month/year boundaries.
    final calendar = DateTime.utc(
      reference.year,
      reference.month,
      reference.day + days,
    );
    return _at(
      calendar.year,
      calendar.month,
      calendar.day,
      time,
      reference.isUtc,
    );
  }

  static DateTime? _at(
    int year,
    int month,
    int day,
    (int, int) time,
    bool utc,
  ) {
    if (day > _daysInMonth(year, month)) return null;
    final date = utc
        ? DateTime.utc(year, month, day, time.$1, time.$2)
        : DateTime(year, month, day, time.$1, time.$2);
    bool matches(DateTime candidate) =>
        candidate.year == year &&
        candidate.month == month &&
        candidate.day == day &&
        candidate.hour == time.$1 &&
        candidate.minute == time.$2;
    // DateTime normalizes nonexistent spring-forward times; reject that shift.
    if (!matches(date)) return null;
    if (!utc) {
      // Check adjacent offsets for another instant with the same wall time.
      // This also handles non-hour DST changes without hardcoding 60 minutes.
      for (final delta in [-2, 2]) {
        final otherOffset = date.add(Duration(days: delta)).timeZoneOffset;
        final difference = date.timeZoneOffset - otherOffset;
        if (difference != Duration.zero && matches(date.add(difference))) {
          return null;
        }
      }
    }
    return date;
  }

  static ResolvedDate _result(
    DateTime date,
    DateTime reference,
    String original,
    bool explicit,
  ) => ResolvedDate(
    dateTime: date,
    hasExplicitTime: explicit,
    matchedText: original,
    isPast: date.isBefore(reference),
  );
}
