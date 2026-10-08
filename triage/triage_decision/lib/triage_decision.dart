/// Fast, deterministic decisions. Scores are rule strengths, not calibrated
/// probabilities from Laya. This package has no network or Flutter dependency.
class IntentDecision {
  const IntentDecision(
    this.type,
    this.priority,
    this.hasTemporalAnchor,
    this.confidence,
    this.reviewReason,
  );
  final String type, priority;
  final bool hasTemporalAnchor;
  final double confidence;
  final String? reviewReason;
  String get tool => switch (type) {
    'reminder' => 'add_reminder',
    'shopping' => 'add_shopping_item',
    'note' => 'add_note',
    'idea' => 'log_idea',
    _ => 'add_task',
  };
}

class ExtractedDraft {
  const ExtractedDraft({
    required this.decision,
    required this.title,
    this.body,
    this.dateText,
    this.tags,
    this.recurring = 'none',
  });
  final IntentDecision decision;
  final String title;
  final String? body, dateText;
  final List<String>? tags;
  final String recurring;
}

class FastDecisionRouter {
  static final _reminder = RegExp(
    r'\b(remind me|reminder|set (?:an? )?(?:alarm|alert)|remember to|don\x27t forget to)\b',
    caseSensitive: false,
  );
  static final _shopping = RegExp(
    r'\b(buy|purchase|groceries|shopping list|grab|pick up)\b',
    caseSensitive: false,
  );
  static final _idea = RegExp(
    r'\b(what if|idea|brainstorm|maybe we could|we could try)\b',
    caseSensitive: false,
  );
  static final _note = RegExp(
    r'\b(note that|take a note|make a note|went well|approved|agreed|meeting notes|meeting minutes|summary|we discussed|we decided)\b',
    caseSensitive: false,
  );
  static final _task = RegExp(
    r'\b(fix|email|send|call|finish|complete|prepare|submit|schedule|review|write|build|update|clean|pay|book|cancel|ship|implement)\b',
    caseSensitive: false,
  );
  static final _negated = RegExp(
    r'\b(do not|don\x27t|never|no need to|forget about)\b',
    caseSensitive: false,
  );
  static final _mixed = RegExp(
    r'\b(?:and|also|then)\s+(?:oh[, ]+)?(?:buy|grab|pick up|remind me|email|fix|send|call|note that|what if)\b|[,;]\s*(?:oh[, ]+)?(?:buy|grab|remind|email|fix|send|call)\b',
    caseSensitive: false,
  );

  static IntentDecision decide(String transcript) {
    final text = transcript.trim();
    final priority =
        RegExp(
          r'\b(low priority|not urgent|no rush)\b',
          caseSensitive: false,
        ).hasMatch(text)
        ? 'low'
        : RegExp(
            r'\b(high priority|urgent|urgently|asap)\b',
            caseSensitive: false,
          ).hasMatch(text)
        ? 'high'
        : 'medium';
    final temporal = TemporalAnchor.extract(text) != null;
    if (text.isEmpty)
      return IntentDecision(
        'note',
        priority,
        temporal,
        0,
        'No speech detected. Enter a title before saving.',
      );
    final type = _idea.hasMatch(text)
        ? 'idea'
        : _reminder.hasMatch(text)
        ? 'reminder'
        : _note.hasMatch(text)
        ? 'note'
        : _shopping.hasMatch(text)
        ? 'shopping'
        : _task.hasMatch(text)
        ? 'task'
        : 'note';
    String? reason;
    var confidence = .85;
    if (!_idea.hasMatch(text) &&
        !_reminder.hasMatch(text) &&
        !_note.hasMatch(text) &&
        !_shopping.hasMatch(text) &&
        !_task.hasMatch(text)) {
      reason = 'Category is uncertain. Review this capture.';
      confidence = .05;
    }
    if (_negated.hasMatch(text) &&
        !RegExp(r"\bdon't forget to\b", caseSensitive: false).hasMatch(text)) {
      reason = 'Negated instruction. Review before saving.';
      confidence = .05;
    }
    if (_mixed.hasMatch(text)) {
      reason =
          'Multiple requests detected. Split or edit this capture before saving.';
      confidence = .05;
    }
    if (type == 'reminder' && !temporal)
      reason ??= 'Add a reminder date and time.';
    return IntentDecision(type, priority, temporal, confidence, reason);
  }
}

class TemporalAnchor {
  static const _days =
      r'(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)';
  static const _months =
      r'(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|october|oct|november|nov|december|dec)';
  static const _time =
      r'(?:\s+(?:at\s+)?(?:\d{1,2}(?::\d{2})?\s*[ap]\.?\s*m\.?|\d{1,2}:\d{2}))?';
  static final pattern = RegExp(
    r'\b(?:in\s+\d+\s+(?:minutes?|hours?|days?)|(?:day after tomorrow|tomorrow|today|(?:this\s+|next\s+)?' +
        _days +
        r'|' +
        _months +
        r'\s+\d{1,2}(?:st|nd|rd|th)?(?:\s+\d{4})?|\d{1,2}(?:st|nd|rd|th)?\s+' +
        _months +
        r'(?:\s+\d{4})?)' +
        _time +
        r')(?=\s|[,!?;.]|$)',
    caseSensitive: false,
  );
  static String? extract(String text) =>
      pattern.firstMatch(text)?.group(0)?.trim();
}

class SlotFiller {
  static ExtractedDraft fill(String transcript, IntentDecision decision) {
    final text = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    final date = TemporalAnchor.extract(text);
    final recurring =
        RegExp(r'\b(?:daily|every day)\b', caseSensitive: false).hasMatch(text)
        ? 'daily'
        : RegExp(
            r'\b(?:weekly|every week)\b',
            caseSensitive: false,
          ).hasMatch(text)
        ? 'weekly'
        : 'none';
    var title = text;
    String? body;
    List<String>? tags;
    if (decision.reviewReason?.startsWith('Multiple requests') == true) {
      body = text;
    } else {
      title = title.replaceFirst(
        RegExp(
          r'^(?:um[, ]+)?(?:so[, ]+)?(?:please\s+)?',
          caseSensitive: false,
        ),
        '',
      );
      title = title.replaceFirst(
        RegExp(
          r"^(?:remind me to|remember to|don't forget to|i need to|buy|purchase|grab|pick up|note that|take a note[: ,]*|make a note[: ,]*|idea[: ,]*)\s*",
          caseSensitive: false,
        ),
        '',
      );
      if (date != null &&
          (decision.type == 'task' ||
              decision.type == 'reminder' ||
              decision.type == 'shopping')) {
        title = title.replaceFirst(
          RegExp(
            r'(?:\b(?:by|on|at)\s+)?' + RegExp.escape(date),
            caseSensitive: false,
          ),
          '',
        );
      }
      title = title
          .replaceAll(
            RegExp(
              r'[, ]*\b(?:high|medium|low) priority\b|[, ]*\b(?:daily|weekly|every day|every week)\b',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (decision.type == 'shopping') {
        final store = RegExp(
          r'\s+(?:from|at)\s+(.+?)[.!?]*$',
          caseSensitive: false,
        ).firstMatch(title);
        final quantity = RegExp(
          r'^\d+(?:\.\d+)?\s+(?:packs? of |bottles? of |cartons? of )?',
          caseSensitive: false,
        ).firstMatch(title);
        if (store != null) {
          title = title.substring(0, store.start).trim();
          body = 'Store: ${store.group(1)}';
        }
        if (quantity != null) {
          body = [
            'Quantity: ${quantity.group(0)!.trim()}',
            if (body != null) body,
          ].join(' · ');
          title = title.substring(quantity.end).trim();
        }
      }
      if (decision.type == 'note' || decision.type == 'idea') {
        body = text;
        if (decision.type == 'note' &&
            RegExp(r'\bmeeting\b', caseSensitive: false).hasMatch(text))
          tags = ['meeting'];
      }
    }
    title = title.replaceAll(RegExp(r'^[,\s]+|[,\s.!?]+$'), '').trim();
    if (title.isEmpty) title = text.isEmpty ? 'New capture' : text;
    if (title.length > 500) title = title.substring(0, 500);
    if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);
    return ExtractedDraft(
      decision: decision,
      title: title,
      body: body,
      dateText: date,
      tags: tags,
      recurring: recurring,
    );
  }
}
