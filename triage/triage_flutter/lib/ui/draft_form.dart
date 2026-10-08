import 'package:flutter/material.dart';
import '../core/draft.dart';
import 'theme.dart';

class DraftForm extends StatefulWidget {
  const DraftForm({
    super.key,
    required this.draft,
    required this.onChanged,
    this.showCategory = true,
    this.showRecurrence = true,
  });
  final Draft draft;
  final VoidCallback onChanged;
  final bool showCategory, showRecurrence;
  @override
  State<DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<DraftForm> {
  late final title = TextEditingController(text: widget.draft.title),
      body = TextEditingController(text: widget.draft.body),
      date = TextEditingController(text: widget.draft.dateText),
      tags = TextEditingController(text: widget.draft.tags);
  void _change() {
    final d = widget.draft;
    d.title = title.text;
    d.body = body.text;
    d.dateText = date.text;
    d.tags = tags.text;
    widget.onChanged();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    date.dispose();
    tags.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller,
    Key key, {
    int lines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: TriageColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          key: key,
          controller: controller,
          maxLines: lines,
          style: const TextStyle(fontSize: 16),
          onChanged: (_) => _change(),
          decoration: InputDecoration(hintText: hint),
          textInputAction: lines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.showCategory) ...[
        const Text(
          'Category',
          style: TextStyle(fontSize: 12, color: TriageColors.muted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: categories
              .map(
                (type) => TextButton(
                  onPressed: () {
                    setState(() => widget.draft.type = type);
                    widget.onChanged();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: widget.draft.type == type
                        ? TriageColors.tint(type)
                        : Colors.transparent,
                    side: BorderSide(
                      color: widget.draft.type == type
                          ? TriageColors.category(type)
                          : TriageColors.border,
                    ),
                  ),
                  child: Text(
                    type[0].toUpperCase() + type.substring(1),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
      _field('Title', title, const Key('draft-title')),
      _field('Body (optional)', body, const Key('draft-body'), lines: 3),
      const Text(
        'Priority (optional)',
        style: TextStyle(fontSize: 12, color: TriageColors.muted),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        children: ['', 'low', 'medium', 'high']
            .map(
              (p) => TextButton(
                onPressed: () {
                  setState(() => widget.draft.priority = p);
                  widget.onChanged();
                },
                style: TextButton.styleFrom(
                  backgroundColor: widget.draft.priority == p
                      ? TriageColors.border
                      : Colors.transparent,
                  side: const BorderSide(color: TriageColors.border),
                ),
                child: Text(
                  p.isEmpty ? 'None' : p[0].toUpperCase() + p.substring(1),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      _field(
        widget.draft.type == 'reminder'
            ? 'Reminder date and time'
            : 'Due date (optional)',
        date,
        const Key('draft-date'),
        hint: 'Tomorrow at 3pm, Friday, October 14 2026 15:00',
      ),
      _field(
        'Tags (comma separated, optional)',
        tags,
        const Key('draft-tags'),
        hint: 'work, personal',
      ),
      if (widget.draft.type == 'reminder' && widget.showRecurrence) ...[
        const Text(
          'Repeat',
          style: TextStyle(fontSize: 12, color: TriageColors.muted),
        ),
        Wrap(
          spacing: 4,
          children: ['none', 'daily', 'weekly']
              .map(
                (r) => TextButton(
                  onPressed: () {
                    setState(() => widget.draft.recurring = r);
                    widget.onChanged();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: widget.draft.recurring == r
                        ? TriageColors.border
                        : Colors.transparent,
                  ),
                  child: Text(r),
                ),
              )
              .toList(),
        ),
      ],
    ],
  );
}
