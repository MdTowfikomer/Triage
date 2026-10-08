# Task 2 — Deterministic date resolver

Implementation: [date_resolver.dart](../spike/lib/core/date_resolver.dart). Unit suite: [date_resolver_test.dart](../spike/test/date_resolver_test.dart). The implementation uses only `dart:core`; copy this single file into another Dart/Flutter project without adding runtime dependencies. It does not call Needle, a backend, or a network service.

```dart
final resolved = DateResolver.resolve(
  'tomorrow at 3pm',
  referenceTime: DateTime(2026, 10, 7, 12),
);
// Local October 8, 2026, 15:00. Omit referenceTime to use the device clock.
if (resolved != null) {
  final utcForPersistence = resolved.utcDateTime;
  final needsDefaultTimeReview = resolved.usedDefaultTime;
  final needsPastTimeReview = resolved.isPast;
}
```

## Supported fields and rules

| Pattern | Rule |
| --- | --- |
| `today`, `tomorrow`, `day after tomorrow` | Calendar days in the selected reference timezone. Past `today` times are preserved and flagged. |
| `Friday`, `this Friday at 4pm` | Upcoming named weekday, including today. If its selected/default time is past, advance seven calendar days. An exact match to the reference instant is not past. |
| `next Monday at 9am` | Named day of the next Monday–Sunday calendar week. Thus `next Friday` on Wednesday is nine days ahead; bare `Friday` is two. |
| `in 2 hours`, `in 30 minutes`, `in 1 day` | Positive whole elapsed units. A day means 24 hours, preserving reference seconds/milliseconds/microseconds; it can change the wall-clock hour across DST. |
| `October 14 at 10am`, `14th Oct 3pm` | Full/abbreviated English month names; optional valid ordinal, year, `at`, or abbreviation period. |
| Yearless specific dates | Next occurrence, including today if its time has not passed. Feb 29 searches to the next leap year, including century rules. |
| Explicit years | Retain that year even when past and flag `isPast`; invalid calendar dates return `null`. |
| No clock time | Default **09:00**, with `hasExplicitTime=false` / `usedDefaultTime=true`. Override using `defaultHour` and `defaultMinute`. |
| Clock variants | `3pm`, `3 p.m.`, `3p.m.`, `3:00 PM`, `15:00`; 12am is midnight and 12pm is noon. Case, whitespace and trailing STT punctuation normalize. |

`matchedText` preserves the trimmed original field, including case and punctuation. Calendar results have zero seconds/fractions. Durations set `hasExplicitTime=true`: the interval determines an exact time rather than applying a date-only default.

The parser is intentionally anchored to **one complete temporal field**. Pass `remind_at`/`due_date`, not a complete transcript or multiple alternative dates. Ambiguous bare hours (`tomorrow at 3`), fractional/spelled-out durations, ISO/slash dates, unknown syntax, invalid hours/minutes/ordinals, impossible dates and unsupported timezone names return `null` without throwing. Duration inputs are bounded to 100 Julian years, and fields to 256 characters, to avoid overflow and unbounded parsing. No fuzzy guessing or partial-match recovery is applied.

## Timezone and DST contract

With no timezone argument, the supplied reference's UTC/local mode is preserved. With no reference, one `DateTime.now()` sample supplies the device-local calendar and clock. `timeZoneName: 'local'` converts the reference instant to device-local time **before** resolving its date; `UTC`, `Etc/UTC`, `GMT`, and `Z` convert it to UTC. An exact non-reserved device-local timezone label is also accepted. Reserved UTC aliases take precedence over device labels.

Arbitrary IANA timezone selection (e.g. `timeZoneName: 'America/New_York'`) is **not implemented**: Dart's native `DateTime` represents local time or UTC, not selectable named zones. Such requests return `null` instead of silently using another zone. The browser tests below change the isolated browser's local timezone; they do not add IANA resolution to the API or alter the host OS timezone. Supporting arbitrary named zones later requires a timezone database/adapter. [Dart DateTime reference](https://api.dart.dev/dart-core/DateTime-class.html).

Calendar arithmetic constructs the target civil date rather than adding `Duration(days: 1)`, which could move the requested hour across DST. Nonexistent local times are rejected when Dart normalizes them to a different wall time. Ambiguous times are rejected by checking adjacent timezone offsets for a second instant with the same wall time; this covers one-hour and half-hour DST transitions. Elapsed durations may land in a repeated hour because their exact instant is already determined. [Dart duration caveat](https://api.dart.dev/dart-core/DateTime/add.html).

Persist `utcDateTime` as an absolute instant. Review `null`, `isPast`, and `usedDefaultTime` before scheduling. Notification integrations should adapt that instant to the notification API's required type; this module does not schedule notifications or apply auto-save policy.

## Verification

- **164/164 resolver unit tests passed** on the Windows Dart VM: all briefing examples, normalization variants, midnight/noon, default flags, weekday rollover, month/year boundaries, leap years including 1900/2000/2100, timezone conversion, invalid inputs and maximum-date overflow.
- **65/65 compiled-Dart browser checks passed** in Chrome 131.0.6778.204: UTC (9), Asia/Kolkata (11), America/New_York (20), Australia/Lord_Howe (13), Pacific/Apia (12). Tests cover 23/25-hour civil days, 30-minute DST changes, gaps/overlaps, elapsed durations, and Samoa's historically skipped civil day. [Recorded results](spike/date_resolver_timezones.json).
- JavaScript compilation succeeds without Flutter package resolution. **Static analysis: no issues. Full Flutter suite: 166/166 passed** (164 resolver tests plus the two existing capture-control tests).

From `spike/`, run `flutter --no-version-check test test/date_resolver_test.dart` (or `flutter test` for the full suite), followed by `flutter analyze`. In this checkout the workspace-local Flutter executable is `../.spike-cache/flutter/bin/flutter.bat`.

To reproduce the browser checks from the repository root using the test driver already installed for Task 1:

```powershell
New-Item -ItemType Directory -Force .spike-cache/date-resolver | Out-Null
./.spike-cache/flutter/bin/cache/dart-sdk/bin/dart.exe compile js -O1 -o .spike-cache/date-resolver/portability.js spike/tool/date_resolver_portability.dart
# Set SPIKE_CHROME to an installed test Chrome executable if needed.
node spike/scripts/date_resolver_browser_check.cjs
```

The pure implementation has no Web, desktop, mobile, or Flutter imports. Windows execution and Web compilation/runtime are verified; no physical Android/iOS run was needed or performed for this module.
