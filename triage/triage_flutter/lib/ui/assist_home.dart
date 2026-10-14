import 'package:flutter/material.dart';
import '../actions/action_result.dart';
import '../assistant/offline_assistant_controller.dart';
import 'components/command_guide_modal.dart';
import 'components/illustrated_cat.dart';

class AssistHome extends StatelessWidget {
  const AssistHome({
    super.key,
    required this.catState,
    required this.status,
    required this.pendingSync,
    required this.onSpeak,
    required this.onShortcut,
    required this.favorites,
    this.onEditContacts,
    this.lastResult,
  });
  final CatState catState;
  final String status;
  final int pendingSync;
  final VoidCallback onSpeak;
  final void Function(String) onShortcut;
  final List<String> favorites;
  final VoidCallback? onEditContacts;
  final AssistantLoopResult? lastResult;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF242521);
    const muted = Color(0xFF777971);
    const paper = Color(0xFFF8F7F2);
    final result = lastResult;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Triage',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: ink,
                        ),
                      ),
                      if (pendingSync > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          '$pendingSync actions waiting to sync',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Offline Commands Guide',
                  onPressed: () => CommandGuideModal.show(context),
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE78A4E).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE78A4E).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      size: 19,
                      color: Color(0xFFC05621),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Center(child: IllustratedCat(state: catState, size: 238)),
            const SizedBox(height: 20),
            Text(
              result == null
                  ? 'How can I help?'
                  : result.actionResult?.status == ActionStatus.handedOff
                  ? 'Sent to your phone.'
                  : result.isSuccess
                  ? 'All done.'
                  : 'Let’s try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result == null
                  ? 'Ask naturally. Triage handles the rest.'
                  : status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 62,
              child: FilledButton.icon(
                onPressed: onSpeak,
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.mic_rounded),
                label: const Text(
                  'Speak to Triage',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Works offline for phone commands',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted),
            ),
            if (result != null) ...[
              const SizedBox(height: 34),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Latest action',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.rawTranscript.isEmpty
                          ? 'Voice command'
                          : result.rawTranscript,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.errorMessage ?? result.spokenFeedback,
                      style: TextStyle(
                        color:
                            result.actionResult?.status ==
                                ActionStatus.permissionRequired
                            ? const Color(0xFFAD681F)
                            : muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 38),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '// FAVORITES',
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onEditContacts,
                  child: const Text('+ EDIT'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final phrase in favorites.take(3))
              InkWell(
                onTap: () => onShortcut(phrase),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          phrase,
                          style: const TextStyle(color: ink, fontSize: 15),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_upward_rounded,
                        size: 17,
                        color: muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
