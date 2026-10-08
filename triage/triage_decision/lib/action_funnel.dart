import 'triage_decision.dart';

const supportedApps = [
  'whatsapp',
  'calendar',
  'maps',
  'mail',
  'clock',
  'notes',
  'browser',
];
const inboxTools = {
  'add_task': 'task',
  'add_reminder': 'reminder',
  'add_shopping_item': 'shopping',
  'add_note': 'note',
  'log_idea': 'idea',
};

/// Whole-command matching prevents a quoted, negated or compound request from
/// accidentally launching an app. Native execution uses the same allowlist.
String? requestedApp(String transcript) {
  final match = RegExp(
    r'^(?:please\s+)?(?:open|launch|start|show)\s+(?:my\s+|the\s+)?(whats\s*app|calendar|maps|google maps|mail|email|gmail|clock|alarms?|notes|browser|chrome)(?:\s+app)?[.!?]*$',
    caseSensitive: false,
  ).firstMatch(transcript.trim());
  return switch (match?.group(1)?.toLowerCase().replaceAll(' ', '')) {
    'whatsapp' => 'whatsapp',
    'calendar' => 'calendar',
    'maps' || 'googlemaps' => 'maps',
    'mail' || 'email' || 'gmail' => 'mail',
    'clock' || 'alarm' || 'alarms' => 'clock',
    'notes' => 'notes',
    'browser' || 'chrome' => 'browser',
    _ => null,
  };
}

class FunnelAction {
  const FunnelAction({
    required this.actionType,
    required this.tool,
    required this.title,
    required this.category,
    required this.priority,
    required this.confidence,
    this.appName,
    this.body,
    this.dateText,
    this.reviewReason,
    this.tags,
    this.recurring = 'none',
  });
  final String actionType, tool, title, category, priority, recurring;
  final String? appName, body, dateText, reviewReason;
  final double confidence;
  final List<String>? tags;

  static FunnelAction local(String transcript) {
    final app = requestedApp(transcript);
    if (app != null) {
      return FunnelAction(
        actionType: 'device_action',
        tool: 'open_app',
        appName: app,
        title: 'Open $app',
        category: 'task',
        priority: 'medium',
        confidence: .95,
      );
    }
    final decision = FastDecisionRouter.decide(transcript);
    final draft = SlotFiller.fill(transcript, decision);
    return FunnelAction(
      actionType: 'inbox_item',
      tool: decision.tool,
      title: draft.title,
      category: decision.type,
      priority: decision.priority,
      confidence: decision.confidence,
      body: draft.body,
      dateText: draft.dateText,
      reviewReason: decision.reviewReason,
      tags: draft.tags,
      recurring: draft.recurring,
    );
  }
}
