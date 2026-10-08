import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:triage_client/triage_client.dart';
import '../core/draft.dart';
import '../state/inbox_controller.dart';
import 'item_detail.dart';
import 'theme.dart';
import 'voice_dock.dart';

class InboxView extends StatefulWidget {
  const InboxView({
    super.key,
    required this.controller,
    this.demo = false,
    this.onSignOut,
  });
  final InboxController controller;
  final bool demo;
  final Future<void> Function()? onSignOut;
  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.controller.pauseForBackground();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.controller.pauseForBackground();
    } else {
      widget.controller.resumeFromBackground();
    }
  }

  Future<void> _type() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _TypedCapture(),
    );
    if (text != null && text.isNotEmpty) {
      await widget.controller.captureText(text);
    }
  }

  Future<void> _signOut() async {
    if (widget.controller.phase == CapturePhase.recording ||
        widget.controller.pending.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out?', style: TextStyle(fontSize: 20)),
          content: const Text(
            'Recording will stop. Unsaved drafts stay on this device for this account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep working'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final c = widget.controller;
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              return Row(
                children: [
                  if (wide)
                    _Rail(
                      demo: widget.demo,
                      onSignOut: widget.onSignOut == null
                          ? null
                          : () => unawaited(_signOut()),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth < 600
                                    ? 16
                                    : 40,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: wide ? 40 : 24),
                                  if (!wide) ...[
                                    Row(
                                      children: [
                                        const Brand(),
                                        const Spacer(),
                                        if (widget.demo)
                                          const Text(
                                            'Local demo',
                                            style: TextStyle(
                                              color: TriageColors.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        if (widget.onSignOut != null)
                                          IconButton(
                                            tooltip: 'Sign out',
                                            onPressed: () =>
                                                unawaited(_signOut()),
                                            icon: const Icon(
                                              Icons.logout,
                                              size: 18,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Inbox',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -.8,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: const Key('refresh-inbox'),
                                        tooltip: 'Refresh inbox',
                                        onPressed: c.loading
                                            ? null
                                            : () => unawaited(c.refresh()),
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 18,
                                          color: TriageColors.muted,
                                        ),
                                      ),
                                      ActionButton(
                                        'Type a thought',
                                        key: const Key('type-thought'),
                                        icon: Icons.edit_note,
                                        onPressed: c.phase == CapturePhase.idle
                                            ? () => unawaited(_type())
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Everything on your mind. One place to put it.',
                                    style: TextStyle(
                                      color: TriageColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final type in [
                                          'all',
                                          ...categories,
                                        ])
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            child: _FilterChip(
                                              type: type,
                                              active: c.filter == type,
                                              count: c.count(type),
                                              onTap: () => c.setFilter(type),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (c.error.isNotEmpty &&
                                      c.current == null) ...[
                                    Semantics(
                                      liveRegion: true,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            size: 16,
                                            color: TriageColors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c.error,
                                              style: const TextStyle(
                                                color: TriageColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (c.status.isNotEmpty &&
                                      c.phase == CapturePhase.idle) ...[
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        c.status,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: TriageColors.muted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Expanded(
                                    child: c.loading && c.items.isEmpty
                                        ? const _FeedSkeleton()
                                        : c.visible.isEmpty
                                        ? _EmptyFeed(
                                            type: c.filter,
                                            onCapture:
                                                c.phase == CapturePhase.idle
                                                ? () => unawaited(
                                                    c.toggleRecording(),
                                                  )
                                                : null,
                                          )
                                        : ListView.separated(
                                            key: const Key('inbox-feed'),
                                            padding: const EdgeInsets.only(
                                              bottom: 140,
                                            ),
                                            itemCount:
                                                c.visible.length +
                                                (c.hasMore ? 1 : 0),
                                            separatorBuilder:
                                                (context, index) =>
                                                    const SizedBox(height: 8),
                                            itemBuilder: (context, index) {
                                              if (index == c.visible.length) {
                                                return ActionButton(
                                                  'Load more',
                                                  onPressed: c.loading
                                                      ? null
                                                      : () => unawaited(
                                                          c.refresh(more: true),
                                                        ),
                                                );
                                              }
                                              return _InboxCard(
                                                item: c.visible[index],
                                                controller: c,
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 20,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: VoiceDock(controller: c),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _TypedCapture extends StatefulWidget {
  const _TypedCapture();
  @override
  State<_TypedCapture> createState() => _TypedCaptureState();
}

class _TypedCaptureState extends State<_TypedCapture> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type a thought',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The same on-device routing, without a microphone.',
              style: TextStyle(fontSize: 12, color: TriageColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('typed-thought'),
              controller: input,
              autofocus: true,
              maxLines: 3,
              maxLength: 4000,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Remind me to call the dentist tomorrow at 3pm',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ActionButton(
                  'Capture',
                  primary: true,
                  onPressed: () => Navigator.pop(context, input.text.trim()),
                ),
                ActionButton('Cancel', onPressed: () => Navigator.pop(context)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Rail extends StatelessWidget {
  const _Rail({required this.demo, this.onSignOut});
  final bool demo;
  final VoidCallback? onSignOut;
  @override
  Widget build(BuildContext context) => Container(
    width: 224,
    decoration: const BoxDecoration(
      color: TriageColors.surface,
      border: Border(right: BorderSide(color: TriageColors.border)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: TriageColors.border,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Icon(Icons.inbox_outlined, size: 18),
              SizedBox(width: 10),
              Text(
                'Inbox',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Divider(),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: TriageColors.muted),
            SizedBox(width: 8),
            Text(
              'On-device capture',
              style: TextStyle(fontSize: 11, color: TriageColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          demo ? 'Local demo · no cloud writes' : 'Your private workspace',
          style: const TextStyle(fontSize: 11, color: TriageColors.muted),
        ),
        if (onSignOut != null) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: onSignOut,
            child: const Row(
              children: [
                Icon(Icons.logout, size: 14, color: TriageColors.muted),
                SizedBox(width: 8),
                Text(
                  'Sign out',
                  style: TextStyle(color: TriageColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.type,
    required this.active,
    required this.count,
    required this.onTap,
  });
  final String type;
  final bool active;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    child: AnimatedContainer(
      duration: UiTokens.motion(context, UiTokens.normal),
      curve: UiTokens.ease,
      decoration: BoxDecoration(
        color: active ? TriageColors.border : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TextButton(
        key: Key('filter-$type'),
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type == 'all' ? 'All' : categoryLabels[categories.indexOf(type)],
              style: TextStyle(
                fontSize: 12,
                color: active ? TriageColors.white : TriageColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                color: active ? TriageColors.white : TriageColors.dim,
                fontFeatures: UiTokens.numbers,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item, required this.controller});
  final InboxItem item;
  final InboxController controller;
  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('item-${item.id}'),
    direction: item.isCompleted
        ? DismissDirection.endToStart
        : DismissDirection.horizontal,
    background: _swipe(
      'Complete',
      Icons.check,
      TriageColors.green,
      Alignment.centerLeft,
    ),
    secondaryBackground: _swipe(
      'Delete',
      Icons.delete_outline,
      TriageColors.red,
      Alignment.centerRight,
    ),
    confirmDismiss: (direction) async {
      if (direction == DismissDirection.startToEnd) {
        await controller.complete(item);
      } else {
        await controller.delete(item);
      }
      return false;
    },
    child: Material(
      color: TriageColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: TriageColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(showItemDetail(context, controller, item)),
        hoverColor: TriageColors.border.withValues(alpha: .3),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: item.isCompleted
                    ? 'Completed'
                    : 'Complete ${item.title}',
                child: Checkbox(
                  value: item.isCompleted,
                  onChanged: item.isCompleted
                      ? null
                      : (_) => unawaited(controller.complete(item)),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryPill(item.type),
                        if (item.priority == 'high') ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.signal_cellular_alt,
                            size: 12,
                            color: TriageColors.muted,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'High priority',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: TriageColors.muted,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (item.emoji != null)
                          Text(
                            item.emoji!,
                            style: const TextStyle(fontSize: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: item.isCompleted
                            ? TriageColors.muted
                            : TriageColors.white,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (item.body != null && item.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: TriageColors.muted,
                        ),
                      ),
                    ],
                    if ((item.tags ?? []).isNotEmpty ||
                        item.dueDate != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final tag in item.tags ?? <String>[])
                            Text(
                              '#$tag',
                              style: const TextStyle(
                                color: TriageColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          if (item.dueDate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: TriageColors.dim,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'MMM d · h:mm a',
                                  ).format(item.dueDate!.toLocal()),
                                  style: const TextStyle(
                                    color: TriageColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Item actions',
                color: TriageColors.surface,
                icon: const Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: TriageColors.dim,
                ),
                onSelected: (action) {
                  if (action == 'complete') {
                    unawaited(controller.complete(item));
                  } else if (action == 'delete') {
                    unawaited(controller.delete(item));
                  } else {
                    unawaited(showItemDetail(context, controller, item));
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit item')),
                  if (!item.isCompleted)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Complete'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _swipe(
    String label,
    IconData icon,
    Color color,
    Alignment alignment,
  ) => Container(
    alignment: alignment,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: TriageColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: TriageColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.type, this.onCapture});
  final String type;
  final VoidCallback? onCapture;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (type) {
                'task' => Icons.check_box_outlined,
                'note' => Icons.notes,
                'reminder' => Icons.notifications_none,
                'shopping' => Icons.shopping_bag_outlined,
                'idea' => Icons.lightbulb_outline,
                _ => Icons.inbox_outlined,
              },
              size: 32,
              color: TriageColors.dim,
            ),
            const SizedBox(height: 20),
            Text(
              type == 'all'
                  ? 'A clear inbox. A clearer mind.'
                  : 'No ${categoryLabels[categories.indexOf(type)].toLowerCase()} yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Speak a thought. We’ll help you put it in place.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TriageColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onCapture,
              child: const Text(
                'Capture your first thought',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading inbox',
    child: ListView.separated(
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: 4,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (context, i) => Container(
        height: 124,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TriageColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TriageColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 52, height: 16, color: TriageColors.border),
            const SizedBox(height: 16),
            Container(width: 180, height: 12, color: TriageColors.border),
            const SizedBox(height: 16),
            Container(width: 100, height: 8, color: TriageColors.border),
          ],
        ),
      ),
    ),
  );
}
