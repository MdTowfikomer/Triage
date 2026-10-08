# Token spine

Primitives: obsidian #0B0F17, slate #121824, border #1E2638, white #F1F5F9, muted #94A3B8, dim #64748B. User-specified five category foreground/tint pairs remain unchanged.

Semantics: canvas=obsidian; raised/modal=slate; text=white; secondary=muted; tertiary=dim. Functional recording/error red #EF4444. Inter is bundled, not downloaded at runtime.

Components: inputs radius 6, cards 10, dialogs 14, capsule/filter pills 999. Spacing 4/8/12/16/24/32/48. Body 14, input 16, title 28. Counts and timer use tabular numerals. Borders are 1 logical px. Capsule has ambient/direct shadows plus border.

Tween motion only: 120ms feedback, 200ms filter, 280ms capsule/card entry, 200ms exit; easeOutCubic. Reduced motion removes spatial/pulse animation, not countdown/state information. Stack: canvas < feed < floating capsule < modal. No light theme requested.
