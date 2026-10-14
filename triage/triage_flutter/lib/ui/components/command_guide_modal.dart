import 'package:flutter/material.dart';

class CommandGuideModal extends StatelessWidget {
  const CommandGuideModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CommandGuideModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFF7F6F0);
    const cardBg = Color(0xFFFFFFFF);
    const border = Color(0xFFE9E8E2);
    const ink = Color(0xFF242521);
    const muted = Color(0xFF777971);
    const accent = Color(0xFFE78A4E);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.offline_bolt_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Commands Guide',
                        style: TextStyle(
                          color: ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Zero-latency, on-device actions without internet',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: muted),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: border),

          // Scrollable command categories
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _buildCategory(
                  icon: Icons.phone_in_talk_rounded,
                  title: 'Calling & Contacts',
                  description: 'Call your pinned contacts directly with fuzzy name match.',
                  examples: [
                    'Call Mom',
                    'Dial John',
                    'Make a phone call to Sarah',
                  ],
                  note: 'Tip: Add aliases like "Mom" in Settings > Pinned Contacts.',
                  cardBg: cardBg,
                  border: border,
                  ink: ink,
                  muted: muted,
                ),
                const SizedBox(height: 14),
                _buildCategory(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'WhatsApp & SMS Messages',
                  description: 'Compose or directly send text to friends.',
                  examples: [
                    'WhatsApp Dad I am on my way',
                    'Send WhatsApp message to Alex',
                    'Text Sarah running 5 minutes late',
                  ],
                  note: 'If contact name is ambiguous, Triage asks to clarify before sending.',
                  cardBg: cardBg,
                  border: border,
                  ink: ink,
                  muted: muted,
                ),
                const SizedBox(height: 14),
                _buildCategory(
                  icon: Icons.volume_up_rounded,
                  title: 'Volume & Hardware Controls',
                  description: 'Set device sound level or jump to presets instantly.',
                  examples: [
                    'Set volume to 50%',
                    'Mute the phone',
                    'Turn up volume',
                    'Set volume to maximum',
                  ],
                  cardBg: cardBg,
                  border: border,
                  ink: ink,
                  muted: muted,
                ),
                const SizedBox(height: 14),
                _buildCategory(
                  icon: Icons.brightness_6_rounded,
                  title: 'Screen & Do Not Disturb',
                  description: 'Adjust display brightness and silence interruptions.',
                  examples: [
                    'Set brightness to 80%',
                    'Turn on Do Not Disturb',
                    'Disable DND',
                  ],
                  cardBg: cardBg,
                  border: border,
                  ink: ink,
                  muted: muted,
                ),
                const SizedBox(height: 14),
                _buildCategory(
                  icon: Icons.alarm_rounded,
                  title: 'Timers & Alarms',
                  description: 'Zero-touch alarms and cooking or workout countdowns.',
                  examples: [
                    'Set timer for 10 minutes',
                    'Set an alarm for 7:30 AM',
                    'Cancel the timer',
                  ],
                  cardBg: cardBg,
                  border: border,
                  ink: ink,
                  muted: muted,
                ),
                const SizedBox(height: 14),
                _buildCategory(
                  icon: Icons.explore_outlined,
                  title: 'Navigation & Travel',
                  description: 'Launch Google Maps navigation directly.',
                  examples: [
                    'Navigate to Central Park',
                    'Take me to Heathrow Airport',
                    'Directions to Coffee Shop',
                  ],
                  cardBg: cardBg,
                  border: border,
                  ink: ink,
                  muted: muted,
                ),
                const SizedBox(height: 14),
                _buildCategory(
                  icon: Icons.apps_rounded,
                  title: 'Open Installed Apps',
                  description: 'Launch any installed app hands-free.',
                  examples: [
                    'Open Spotify',
                    'Launch YouTube',
                    'Open Camera',
                  ],
                  cardBg: cardBg,
                  border: border,
                  ink: ink,
                  muted: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCategory({
    required IconData icon,
    required String title,
    required String description,
    required List<String> examples,
    String? note,
    required Color cardBg,
    required Color border,
    required Color ink,
    required Color muted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: ink),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: examples.map((ex) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F2EB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '“$ex”',
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }).toList(),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(
                color: Color(0xFF94623C),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
