# Future feature: contact actions and favorite apps

**Status:** Proposed; not implemented in the new offline assistant.  
**Reviewed:** 2026-10-13  
**Related work:** [Ticket 08 native action matrix](../.scratch/triage-offline-assistant/issues/08-native-action-matrix-expansion.md), [Ticket 06 BYOK routing firewall](../.scratch/triage-offline-assistant/issues/06-single-provider-byok-gateway-and-routing-firewall.md)

## Goal

Let a user choose the apps they use most in Triage, launch them by voice, and perform a small set of explicitly supported tasks. Add local contact resolution for commands such as “Call Ayesha” and “WhatsApp Ayesha: I'm on the way.” Preserve the assistant's offline-first behavior and truthful typed results.

The user chooses favorites. Triage should not infer “most used” apps from usage history or request Usage Access merely to populate this list.

## User experience and offline boundary

| Request | Local work | Handoff and truthful result |
| --- | --- | --- |
| “Open WhatsApp” | Parse the app name and resolve an enabled favorite to an installed package. | Launch the app; `success` means Android opened it, not that anything inside it happened. |
| “Call Ayesha” | Resolve a locally stored contact and phone number; ask which one if ambiguous. | Open the phone dialer with the number using `ACTION_DIAL`; report `handed_off`. The user starts the call. Cellular service is needed to complete it. |
| “WhatsApp Ayesha: I'm on the way” | Resolve the contact and compose the exact dictated message locally. | Open Ayesha's WhatsApp chat with text prefilled, show the recipient and text, and let the user tap Send. Report `handed_off`, never `sent`. WhatsApp delivery needs connectivity. Test whether the installed WhatsApp app opens the composer while offline; do not claim this as guaranteed. |
| “Text Ayesha: I'm on the way” | Resolve the contact and compose an SMS draft locally. | Open the SMS composer with `ACTION_SENDTO`; report `handed_off`. Sending needs cellular service. |
| “Start navigation to home” | Parse a supported navigation action and locally resolve an approved destination. | Hand off to a maps app; route calculation and guidance may require network or downloaded offline maps. |

The first version should use a **user-visible handoff** for calling and messaging. Do not attempt to silently send a WhatsApp message through UI automation or claim delivery without a verified acknowledgement from the target app.

## Favorite-app settings

1. Show launchable, visible installed apps with icon and label. The user pins and unpins favorites, chooses optional spoken aliases, and can disable voice launch per app.
2. Save the selected package ID and aliases locally. Resolve an alias to one package deterministically; if two apps or aliases match, ask the user to choose.
3. Expose **Open app** for any selected launchable app. Expose **Tasks** only for apps with a documented, implemented action adapter. A favorite app does not imply permission to automate all its screens.
4. Reflect app uninstall, disabled app state, or package change as `unsupported` or `ambiguous`, without launching a similarly named app silently.

Android 11+ filters package queries. The current project uses scoped `<queries>`; expand and test visibility only as needed for the supported discovery and task flows. Avoid blanket package inventory access unless there is a justified, policy-compatible need. See [Android package visibility](https://developer.android.com/training/package-visibility) and [declaring queries](https://developer.android.com/training/package-visibility/declaring).

## Action architecture

Use a small capability registry, with entries such as `open_app`, `dial_contact`, `compose_sms`, `compose_whatsapp`, and `open_navigation`. Each entry declares required slots, local permissions, whether it needs a target app, whether it can work without data service, and the possible typed results. The deterministic parser handles clear single-intent commands first. The BYOK model may propose an action, but cannot invoke a native bridge method directly; proposed recipients, message text, and destinations require explicit user confirmation.

Implement each task through an Android public intent, documented deep link, or supported app integration. Opening arbitrary activities or simulating taps across other apps should not be part of the first release. Android documents [common dial and messaging intents](https://developer.android.com/guide/components/intents-common). WhatsApp documents a [prefilled click-to-chat link](https://faq.whatsapp.com/5913398998672934); verify its behavior with the installed Android app and offline state on the physical test device.

## Contacts, privacy, and safety

- Prefer Android's contact picker for a one-off handoff where it provides enough information. For voice lookup by name across the address book, request `READ_CONTACTS` with a clear explanation and keep lookup on-device. See [Android contact selection](https://developer.android.com/guide/components/intents-common) and [contact lookup permission](https://developer.android.com/identity/providers/contacts-provider/retrieve-names).
- Confirm the exact contact and number when names are similar, a contact has multiple numbers, or recognition confidence is low. Do not guess a recipient.
- Keep contact names, phone numbers, and message bodies out of Serverpod audit sync by default. Store only a redacted action type and result where an audit event is needed; any local draft should be clearly identified as local.
- Recheck the app and contact state immediately before handoff. Cancel safely on interruption or if the user declines confirmation.
- Use the existing result vocabulary: `success` for a verified local launch, `handed_off` for a dialer or composer, `permission_required`, `ambiguous`, `unsupported`, and `error` as appropriate.

## Suggested implementation slices

1. **Favorite launchers:** user-pinned apps, aliases, deterministic “open app” routing, installed-package checks, and physical-device verification.
2. **Contact calling:** local name/number resolution, ambiguity UI, `ACTION_DIAL`, and Airplane Mode handoff testing.
3. **Message composers:** SMS and WhatsApp prefilled handoffs with an explicit recipient-and-text preview; verify app behavior with and without connectivity.
4. **App task adapters:** add one documented task at a time, each with its own parameters, result contract, and physical-device acceptance test.
5. **Optional BYOK planning:** allow the LLM to suggest supported tasks, then show a structured confirmation card before any native action.

Success is measured by correct target selection, no wrong-recipient side effects, accurate `handed_off` versus `success` feedback, and continued local operation for parsing, contacts, and app launching in Airplane Mode.
