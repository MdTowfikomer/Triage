import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/draft.dart';
import '../state/inbox_controller.dart';
import 'draft_form.dart';
import 'theme.dart';

class VoiceDock extends StatelessWidget {
  const VoiceDock({super.key, required this.controller});
  final InboxController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final confirming = c.current != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: UiTokens.motion(context, UiTokens.entry),
            reverseDuration: UiTokens.motion(context, UiTokens.normal),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: MediaQuery.disableAnimationsOf(context)
                          ? Offset.zero
                          : const Offset(0, .06),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: animation, curve: UiTokens.ease),
                    ),
                child: child,
              ),
            ),
            child: confirming
                ? _Confirmation(
                    controller: c,
                    draft: c.current!,
                    key: ValueKey(c.current!.localId),
                  )
                : const SizedBox.shrink(),
          ),
          if (confirming) const SizedBox(height: 12),
          AnimatedContainer(
            duration: UiTokens.motion(context, UiTokens.entry),
            curve: UiTokens.ease,
            width: c.phase == CapturePhase.recording ? 310 : 220,
            height: 58,
            decoration: BoxDecoration(
              color: TriageColors.surface,
              borderRadius: BorderRadius.circular(UiTokens.pillRadius),
              border: Border.all(color: TriageColors.border),
              boxShadow: UiTokens.floatingShadow,
            ),
            child: TextButton(
              key: const Key('voice-toggle'),
              onPressed:
                  c.phase == CapturePhase.idle ||
                      c.phase == CapturePhase.recording
                  ? () => unawaited(c.toggleRecording())
                  : null,
              style: TextButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: c.phase == CapturePhase.recording
                  ? _Recording(c)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          c.phase == CapturePhase.idle
                              ? Icons.mic_none
                              : Icons.graphic_eq,
                          size: 20,
                          color: TriageColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            switch (c.phase) {
                              CapturePhase.idle => 'Tap to speak',
                              CapturePhase.preparing => 'Preparing models…',
                              CapturePhase.processing => 'Processing locally…',
                              CapturePhase.saving => 'Saving…',
                              _ => 'Review your capture',
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: TriageColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({
    super.key,
    required this.controller,
    required this.draft,
  });
  final InboxController controller;
  final Draft draft;
  @override
  Widget build(BuildContext context) {
    final c = controller, d = draft;
    final review = c.phase == CapturePhase.review;
    final saving = c.phase == CapturePhase.saving;
    final date = d.resolvedDate;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.max(
          140,
          MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom -
              MediaQuery.paddingOf(context).vertical -
              110,
        ),
      ),
      child: Container(
        key: const Key('confirmation-card'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TriageColors.surface,
          borderRadius: BorderRadius.circular(UiTokens.modalRadius),
          border: Border.all(color: TriageColors.border),
          boxShadow: UiTokens.floatingShadow,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    review ? Icons.edit_outlined : Icons.check_circle_outline,
                    size: 16,
                    color: review ? TriageColors.amber : TriageColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      review
                          ? 'Review / Edit required'
                          : saving
                          ? 'Saving your capture…'
                          : 'Ready for your inbox',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (c.pending.length > 1)
                    Text(
                      '${c.pending.length} items',
                      style: const TextStyle(
                        fontSize: 11,
                        color: TriageColors.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (review) ...[
                Text(
                  d.reviewReason.isEmpty
                      ? 'Check the fields, then save.'
                      : d.reviewReason,
                  style: const TextStyle(
                    color: TriageColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      100,
                      math.min(300, MediaQuery.sizeOf(context).height * .38),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (d.originalTranscript.isNotEmpty) ...[
                          const Text(
                            'Heard on this device',
                            style: TextStyle(
                              fontSize: 11,
                              color: TriageColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            d.originalTranscript,
                            style: const TextStyle(
                              fontSize: 12,
                              color: TriageColors.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        DraftForm(
                          draft: d,
                          onChanged: () => unawaited(c.persistEdits()),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                CategoryPill(d.type),
                const SizedBox(height: 10),
                Text(
                  d.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.4,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: TriageColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat(
                            'EEE, MMM d · h:mm a',
                          ).format(date.dateTime.toLocal()),
                          style: const TextStyle(
                            fontSize: 12,
                            color: TriageColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (d.tagList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    d.tagList.map((t) => '#$t').join('  '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: TriageColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
              if (c.error.isNotEmpty) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    c.error,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TriageColors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!review && !saving) ...[
                Semantics(
                  label: 'Auto-save countdown',
                  value:
                      '${((c.countdownMs ?? 0) / 1000).ceil()} seconds remaining',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: c.progress),
                      duration: UiTokens.motion(context, UiTokens.fast),
                      builder: (context, value, child) =>
                          LinearProgressIndicator(
                            key: const Key('autosave-progress'),
                            value: value,
                            minHeight: 2,
                            color: TriageColors.muted,
                            backgroundColor: TriageColors.border,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saving in ${((c.countdownMs ?? 0) / 1000).ceil()}s · tap Edit to pause',
                  style: const TextStyle(
                    fontSize: 11,
                    color: TriageColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionButton(
                    'Save Now',
                    key: const Key('save-now'),
                    primary: true,
                    busy: saving,
                    onPressed: () => unawaited(c.saveCurrent()),
                  ),
                  if (!review)
                    ActionButton(
                      'Edit',
                      key: const Key('edit-capture'),
                      onPressed: saving ? null : c.edit,
                      icon: Icons.edit_outlined,
                    ),
                  ActionButton(
                    'Cancel',
                    key: const Key('cancel-capture'),
                    onPressed: saving ? null : () => unawaited(c.cancel()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Recording extends StatefulWidget {
  const _Recording(this.controller);
  final InboxController controller;
  @override
  State<_Recording> createState() => _RecordingState();
}

class _RecordingState extends State<_Recording>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = 1;
    } else {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, seconds = c.elapsedMs ~/ 1000;
    return Semantics(
      label: 'Finish recording',
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) =>
                Opacity(opacity: .45 + .55 * pulse.value, child: child),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: TriageColors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: TriageColors.white,
              fontSize: 13,
              fontFeatures: UiTokens.numbers,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: c.audioLevels
                      .map(
                        (level) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: SizedBox(
                            width: 3,
                            height: 24,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: .15 + .85 * level.clamp(0, 1)),
                              duration: UiTokens.motion(context, UiTokens.fast),
                              builder: (context, value, child) =>
                                  Transform.scale(scaleY: value, child: child),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: TriageColors.muted,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.stop_rounded, size: 18, color: TriageColors.white),
        ],
      ),
    );
  }
}
