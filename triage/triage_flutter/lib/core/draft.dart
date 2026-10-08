import 'package:triage_client/triage_client.dart';
import 'package:triage_spike/core/date_resolver.dart';
import 'redact.dart';

const categories = ['task', 'note', 'reminder', 'shopping', 'idea'];
const categoryLabels = ['Tasks', 'Notes', 'Reminders', 'Shopping', 'Ideas'];
String categoryEmoji(String type) => switch (type) {
  'note' => '📝',
  'reminder' => '⏰',
  'shopping' => '🛒',
  'idea' => '💡',
  _ => '📌',
};

/// These objects are client-local. They are never serialized to an endpoint.
class Draft {
  Draft({
    required this.title,
    required this.type,
    required this.originalTranscript,
    DateTime? referenceTime,
    String? localId,
    this.body = '',
    this.priority = '',
    this.dateText = '',
    this.tags = '',
    this.recurring = 'none',
    this.confidence,
    this.reviewReason = '',
  }) : referenceTime = referenceTime ?? DateTime.now(),
       localId = localId ?? const Uuid().v4();
  final String localId;
  final DateTime referenceTime;
  final String originalTranscript;
  final double? confidence;
  String title, type, body, priority, dateText, tags, recurring, reviewReason;
  bool redactionReady = false;
  String? redactedTranscript, redactedTitle, redactedBody;
  List<String>? redactedTags;

  ResolvedDate? get resolvedDate => dateText.trim().isEmpty
      ? null
      : DateResolver.resolve(dateText, referenceTime: referenceTime);
  String? get validationError => validate();
  String? validate({bool allowPastReminder = false, DateTime? existingDate}) {
    if (!categories.contains(type)) return 'Choose a category.';
    if (title.trim().isEmpty || title.length > 500) {
      return 'Title needs 1–500 characters.';
    }
    if (body.length > 16000) return 'Body exceeds 16000 characters.';
    if (priority.isNotEmpty && !['low', 'medium', 'high'].contains(priority)) {
      return 'Choose a valid priority.';
    }
    if (tagList.length > 32 || tagList.any((t) => t.length > 50)) {
      return 'Use up to 32 tags, each under 51 characters.';
    }
    if (dateText.trim().isNotEmpty &&
        existingDate == null &&
        resolvedDate == null) {
      return 'Date not recognized. Try “tomorrow at 3pm”.';
    }
    final actualDate = existingDate ?? resolvedDate?.dateTime;
    if (type == 'reminder' &&
        (actualDate == null ||
            (!allowPastReminder && !actualDate.isAfter(DateTime.now())))) {
      return 'Reminders need a future date and time.';
    }
    if (!['none', 'daily', 'weekly'].contains(recurring)) {
      return 'Choose a valid recurrence.';
    }
    return null;
  }

  List<String> get tagList => tags
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();
  Future<void> redactForServer(PayloadRedactor redactor) async {
    final tags = tagList;
    final values = await redactor.redact([
      originalTranscript,
      title.trim(),
      body,
      ...tags,
    ]);
    if (values.length != tags.length + 3) {
      throw StateError('On-device PII redaction returned an invalid result.');
    }
    redactedTranscript = values[0];
    redactedTitle = values[1];
    redactedBody = body.isEmpty ? null : values[2];
    redactedTags = values.skip(3).toList();
    redactionReady = true;
  }

  void invalidateRedaction() {
    redactionReady = false;
    redactedTranscript = null;
    redactedTitle = null;
    redactedBody = null;
    redactedTags = null;
  }

  bool get canAutoSave =>
      confidence != null &&
      confidence!.isFinite &&
      confidence! >= .1 &&
      confidence! <= 1 &&
      reviewReason.isEmpty &&
      validationError == null;
  Map<String, dynamic> toLocalJson() => {
    'localId': localId,
    'referenceTime': referenceTime.toIso8601String(),
    'originalTranscript': originalTranscript,
    'title': title,
    'type': type,
    'body': body,
    'priority': priority,
    'dateText': dateText,
    'tags': tags,
    'recurring': recurring,
    'confidence': confidence,
    'reviewReason': reviewReason,
    'redactionReady': redactionReady,
    'redactedTranscript': redactedTranscript,
    'redactedTitle': redactedTitle,
    'redactedBody': redactedBody,
    'redactedTags': redactedTags,
  };
  factory Draft.fromLocalJson(Map<String, dynamic> j) {
    final draft = Draft(
      localId: j['localId'] as String,
      referenceTime: DateTime.parse(j['referenceTime'] as String),
      originalTranscript: j['originalTranscript'] as String,
      title: j['title'] as String,
      type: j['type'] as String,
      body: j['body'] as String,
      priority: j['priority'] as String,
      dateText: j['dateText'] as String,
      tags: j['tags'] as String,
      recurring: j['recurring'] as String,
      confidence: (j['confidence'] as num?)?.toDouble(),
      reviewReason: j['reviewReason'] as String,
    );
    draft.redactionReady = j['redactionReady'] == true;
    draft.redactedTranscript = j['redactedTranscript'] as String?;
    draft.redactedTitle = j['redactedTitle'] as String?;
    draft.redactedBody = j['redactedBody'] as String?;
    draft.redactedTags = (j['redactedTags'] as List?)?.cast<String>();
    return draft;
  }

  /// Called after Needle extraction; only sanitized content leaves the device.
  InboxItem toItem(UuidValue owner) {
    final date = resolvedDate?.dateTime.toUtc();
    return InboxItem(
      userId: owner,
      type: type,
      title: redactedTitle ?? redactKnownPii(title.trim()),
      body: redactedBody ?? (body.isEmpty ? null : redactKnownPii(body)),
      tags: redactedTags ?? tagList.map(redactKnownPii).toList(),
      priority: priority.isEmpty ? null : priority,
      dueDate: date,
      emoji: categoryEmoji(type),
      redactedTranscript:
          redactedTranscript ?? redactKnownPii(originalTranscript),
      confidence: confidence,
      createdAt: DateTime.now().toUtc(),
      reminder: type == 'reminder' && date != null
          ? Reminder(
              inboxItemId: 0,
              triggerAt: date,
              recurring: recurring,
              createdAt: DateTime.now().toUtc(),
            )
          : null,
    );
  }
}

List<Draft> parseVoiceResult(Map<String, dynamic> result, DateTime reference) {
  final transcript = result['transcript'] is String
      ? result['transcript'] as String
      : '';
  final routing = result['routing'] is Map ? result['routing'] as Map : {};
  final parsed = routing['parsed'] is Map ? routing['parsed'] as Map : {};
  final numericScore = parsed['confidence'] is num
      ? (parsed['confidence'] as num).toDouble()
      : null;
  final score =
      numericScore != null &&
          numericScore.isFinite &&
          numericScore >= 0 &&
          numericScore <= 1
      ? numericScore
      : null;
  var calls = parsed['function_calls'] is List
      ? (parsed['function_calls'] as List)
      : [];
  var isSuppressed = false;
  if (calls.isEmpty &&
      parsed['suppressed_calls'] is List &&
      (parsed['suppressed_calls'] as List).isNotEmpty) {
    calls = parsed['suppressed_calls'] as List;
    isSuppressed = true;
  }
  var reason = '';
  if (isSuppressed) {
    reason = 'Low model confidence. Review required.';
  } else if (calls.isEmpty || transcript.trim().isEmpty) {
    reason = 'No actionable call. Review and choose what to save.';
  } else if (score == null || !score.isFinite || score < .1 || score > 1) {
    reason = 'Low or missing confidence. Review required.';
  } else if (routing['schema'] is! Map || routing['schema']['valid'] != true) {
    reason = 'Tool arguments need review.';
  }
  final validation = parsed['validation'];
  if (validation is Map &&
      (validation['negation'] == true ||
          (validation['ungrounded'] is List &&
              (validation['ungrounded'] as List).isNotEmpty))) {
    reason = 'The model flagged uncertain arguments.';
  }
  if (parsed['success'] != true && calls.isNotEmpty) {
    reason = 'The model did not report success.';
  }
  if (calls.isEmpty) {
    return _smartExtractDrafts(transcript, reference, score);
  }
  return calls.map((call) {
    final map = call is Map ? call : <String, dynamic>{};
    final a = map['arguments'] is Map
        ? map['arguments'] as Map
        : <String, dynamic>{};
    String s(String key) => a[key] is String ? a[key] as String : '';
    final type = switch (map['name']) {
      'add_task' => 'task',
      'add_note' => 'note',
      'add_reminder' => 'reminder',
      'add_shopping_item' => 'shopping',
      'log_idea' => 'idea',
      _ => 'task',
    };
    var title = type == 'shopping' ? s('item') : s('title');
    if (title.trim().isEmpty && transcript.trim().isNotEmpty) {
      title = transcript.trim();
    }
    final draft = Draft(
      type: type,
      title: title,
      originalTranscript: transcript,
      referenceTime: reference,
      confidence: score ?? (isSuppressed ? 0.05 : null),
      body: type == 'idea'
          ? s('description')
          : type == 'shopping'
          ? [s('quantity'), s('store')].where((v) => v.isNotEmpty).join(' · ')
          : s('body'),
      priority: s('priority'),
      dateText: type == 'reminder' ? s('remind_at') : s('due_date'),
      tags: type == 'note' ? s('topic') : '',
      recurring: s('recurring').isEmpty ? 'none' : s('recurring'),
      reviewReason: reason,
    );
    if ((type == 'note' || type == 'idea') && draft.body.trim().isEmpty) {
      draft.body = transcript.trim();
    }
    if (draft.resolvedDate?.usedDefaultTime == true) {
      draft.reviewReason = 'Time defaulted to 09:00. Confirm or edit it.';
    }
    return draft;
  }).toList();
}

List<Draft> _smartExtractDrafts(
  String transcript,
  DateTime reference,
  double? score,
) {
  final trimmed = transcript.trim();
  if (trimmed.isEmpty) {
    return [
      Draft(
        title: '',
        type: 'task',
        originalTranscript: transcript,
        referenceTime: reference,
        confidence: score,
        reviewReason: 'No speech detected.',
      ),
    ];
  }

  final lower = trimmed.toLowerCase();
  String type = 'task';
  if (RegExp(
    r'\b(buy|order|purchase|grocery|groceries|shopping|milk|eggs|bread|coffee|store|pick up)\b',
  ).hasMatch(lower)) {
    type = 'shopping';
  } else if (RegExp(r'\b(remind|alarm|alert|reminder)\b').hasMatch(lower) ||
      RegExp(
        r'\b(tomorrow|today|tonight|next week|at \d|at (?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve))\b',
      ).hasMatch(lower)) {
    type = 'reminder';
  } else if (RegExp(r'\b(note|meeting|minutes|summary|agreed)\b').hasMatch(lower)) {
    type = 'note';
  } else if (RegExp(r'\b(idea|what if|thought|maybe we could|pitch)\b').hasMatch(lower)) {
    type = 'idea';
  }

  var title = trimmed
      .replaceAll(
        RegExp(
          r'^(remind me to|remember to|don\x27t forget to|i need to|please|could you|can you|buy|pick up|note that|idea:?)\s+',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (title.isEmpty) title = trimmed;
  title = title[0].toUpperCase() + title.substring(1);

  String dateText = '';
  final dateMatch = RegExp(
    r'\b((?:tomorrow|today|day after tomorrow|this (?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)|next (?:monday|tuesday|wednesday|thursday|friday|saturday|sunday))(?: (?:at )?\S+(?: \S+)?)?|in \d+ (?:minute|hour|day)s?)\b',
    caseSensitive: false,
  ).firstMatch(lower);

  if (dateMatch != null) {
    dateText = dateMatch.group(0)!;
    title = title
        .replaceAll(RegExp(RegExp.escape(dateText), caseSensitive: false), '')
        .trim();
    title = title.replaceAll(RegExp(r'\s+(at|by|on)$', caseSensitive: false), '').trim();
  }

  return [
    Draft(
      type: type,
      title: title.isEmpty ? trimmed : title,
      originalTranscript: transcript,
      referenceTime: reference,
      confidence: score ?? 0.05,
      dateText: dateText,
      body: type == 'note' || type == 'idea' ? trimmed : '',
      reviewReason: 'Voice recognized. Review and confirm item.',
    ),
  ];
}
