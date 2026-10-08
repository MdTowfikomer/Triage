import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:triage_client/triage_client.dart';
import '../core/draft.dart';
import '../core/redact.dart';
import '../state/inbox_controller.dart';
import 'draft_form.dart';
import 'theme.dart';

Future<void> showItemDetail(
  BuildContext context,
  InboxController controller,
  InboxItem item,
) {
  if (controller.current != null) controller.edit();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ItemDetail(controller: controller, item: item),
  );
}

class _ItemDetail extends StatefulWidget {
  const _ItemDetail({required this.controller, required this.item});
  final InboxController controller;
  final InboxItem item;
  @override
  State<_ItemDetail> createState() => _ItemDetailState();
}

class _ItemDetailState extends State<_ItemDetail> {
  late final initialDateText = widget.item.dueDate == null
      ? ''
      : DateFormat('MMMM d yyyy HH:mm').format(widget.item.dueDate!.toLocal());
  late final Draft draft = Draft(
    title: widget.item.title,
    type: widget.item.type,
    originalTranscript: widget.controller.cache.original(widget.item.id!) ?? '',
    body: widget.item.body ?? '',
    priority: widget.item.priority ?? '',
    tags: (widget.item.tags ?? []).join(', '),
    dateText: initialDateText,
    recurring: widget.item.reminder?.recurring ?? 'none',
  );
  String _error = '';
  bool _busy = false, _dirty = false;
  Future<void> _close() async {
    if (_busy) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?', style: TextStyle(fontSize: 18)),
          content: const Text('Your saved item will stay unchanged.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final unchangedDate = draft.dateText == initialDateText;
    final validation = draft.validate(
      allowPastReminder: unchangedDate,
      existingDate: unchangedDate ? widget.item.dueDate : null,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() => _busy = true);
    final edited = widget.item.copyWith(
      title: redactKnownPii(draft.title.trim()),
      body: draft.body.isEmpty ? null : redactKnownPii(draft.body),
      priority: draft.priority.isEmpty ? null : draft.priority,
      dueDate: unchangedDate
          ? widget.item.dueDate
          : draft.resolvedDate?.dateTime.toUtc(),
      tags: draft.tagList.map(redactKnownPii).toList(),
    );
    final saved = await widget.controller.update(edited);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_close());
    },
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryPill(widget.item.type),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close item',
                    onPressed: () => unawaited(_close()),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Item details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 24),
              DraftForm(
                draft: draft,
                showCategory: false,
                showRecurrence: false,
                onChanged: () {
                  if (mounted) setState(() => _dirty = true);
                },
              ),
              const Divider(height: 32),
              const Text(
                'Original transcript · this device only',
                style: TextStyle(color: TriageColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SelectableText(
                draft.originalTranscript.isEmpty
                    ? 'Not available on this device. Raw transcripts are never synced.'
                    : draft.originalTranscript,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sanitized server text',
                style: TextStyle(color: TriageColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.item.redactedTranscript,
                style: const TextStyle(fontSize: 13, color: TriageColors.muted),
              ),
              const SizedBox(height: 24),
              if (_error.isNotEmpty) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error,
                    style: const TextStyle(color: TriageColors.red),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionButton(
                    'Save changes',
                    primary: true,
                    busy: _busy,
                    onPressed: () => unawaited(_save()),
                  ),
                  ActionButton(
                    'Cancel',
                    onPressed: _busy ? null : () => unawaited(_close()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
