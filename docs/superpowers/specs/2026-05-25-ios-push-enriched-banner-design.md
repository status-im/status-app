# iOS Push: Enriched Banner via `local-notifications` Replacement

- **Date:** 2026-05-25
- **Status:** Draft (design approved, pre-implementation)
- **Target:** Status Mobile — iOS
- **Author:** Alex Jbanca
- **Builds on:** Layer 1b (background-receive → sync) — `docs/superpowers/plans/2026-05-25-ios-push-layer1b-background-sync.md`
- **Reference implementation:** Android `StatusNotificationManager` (ADR-0002) — `mobile/android/qt6/src/app/status/mobile/ipc/notifications/StatusNotificationManager.java`

## Problem

iOS shows a **contentless anonymous** push ("You have a new message"). After Layer 1b wakes the app and syncs, status-go decrypts the message and (on Android) emits a privacy-filtered `local-notifications` signal. On iOS that signal is **not consumed**, so the banner stays anonymous even though the real, privacy-correct content is now available on-device.

## Goal

When the background sync (Layer 1b) produces a `local-notifications` event, **replace the anonymous banner in place** with the privacy-filtered content (sender + message, per the user's `notificationsMessagePreview` setting) — with **no second alert/buzz** — achieving Layer 2's enriched banner **without an NSE** (the decrypt happens in the in-process status-go that owns the DB, sidestepping the NSE memory budget and the ratchet-corruption hazard).

## Non-Goals

- The NSE (`UNNotificationServiceExtension`) path — explicitly avoided; this supersedes it for the enriched-banner goal.
- Precise tap → specific-chat routing (deferred Layer 1a; needs the hashed-chatId resolver). Tap continues to open the app.
- A MessagingStyle-equivalent "N messages" thread on iOS — coalesce to the latest message per conversation (iOS has no MessagingStyle).
- Changing what content the push carries — the push stays **contentless** (only the addition of an `apns-collapse-id`, which is the already-present hash; see Privacy).
- Desktop/Android notification behavior — unchanged.

## Constraints / Current State (confirmed in source)

- **Show primitive:** MobileUI exposes `PushNotifications.showNotification(title, message, identifier)` (QML singleton). The existing `NotificationsManager` uses a **desktop-only** `StatusOSNotification`; iOS must route to MobileUI.
- **`local-notifications` signal is NOT consumed on iOS.** The Nim `SignalType` enum (`src/app/core/signals/remote_signals/signal_type.nim`) has `Message = "messages.new"` but **no** `local-notifications` entry. status-go only emits it when `LocalNotificationsConfig.Enabled = true` (`src/app_service/service/node_configuration/dto/node_config.nim:144`); enablement on iOS is **unverified** and must be ensured.
- **Signal payload** (status-go `services/local-notifications/core.go`): `DisplayTitle`, `DisplayMessage`, `Title`, `Message`, `ConversationID`, `id`, `Category`, `notificationAuthor` (name/icon), `communityIcon`, `chatIcon`, `isGroupConversation`, `timestamp`, `deepLink`, `isFromMe`, `deleted`. `DisplayTitle`/`DisplayMessage` are already privacy-filtered (`applyMessagePreview`/`applyAuthorPrivacy`).
- **Push payload:** anonymous; `data.chatId = hex(Shake256(chatID))` already present (`pushnotificationserver/gorush.go`). No `apns-collapse-id` is set today.
- **Layer 1b** delivers the background wake + sync; this design consumes the resulting signal.

## Design

### Data flow
1. Anonymous push (alert + `content-available` + **new** `apns-collapse-id = hex(messageID)`) → Layer 1b wakes the app.
2. App syncs; status-go processes messages and emits the `local-notifications` signal with privacy-filtered `DisplayTitle`/`DisplayMessage`, `ConversationID`, and the message `id` (== the push's messageID).
3. **New iOS consumer:** the Nim signal handler receives the event, applies the suppression rules (below), and calls `PushNotifications.showNotification(displayTitle, displayMessage, identifier = id)` with `threadIdentifier = conversationId`.
4. iOS coalesces by `request.identifier` (== the push's `apns-collapse-id` == `hex(messageID)`) → **replaces that message's anonymous banner in place**. Banners group per conversation via the device-side `threadIdentifier`.

### Identifier scheme (the correlation key) — per-message, privacy-preserving
The anonymous push's `apns-collapse-id` and the replacement local notification's `identifier` **must be the same string**. The chosen key is the **message ID** — a per-message value already shared by both sides, requiring **no new signal field and no app-side hashing**:
- The push is sent for a specific message: gorush sets `apns-collapse-id = hex(messageID)` (plumbed from `PushNotificationRequest.MessageId`).
- The `local-notifications` signal already carries that same message ID as its `id` field (`local_notifications.go:311` `ID: HexToHash(id)`; Android reads it as `optString("id")`). The Nim consumer uses `id` verbatim as the notification `identifier`.

**Why per-message, not per-conversation:** a stable `Shake256(chatID)` collapse-id would give Apple a persistent pseudonymous per-conversation key (social-graph leak). A per-message id is nonce-like — each push looks independent to Apple, so no stable conversation key is exposed (≈ what message timing already implies today). This is the privacy-preserving rule.

**Grouping vs. coalescing:** the local notification sets `threadIdentifier = conversationId` (device-side only, never sent to Apple) so banners group per conversation in the shade. Replacement is therefore **per message** (each message: anonymous → enriched in place, grouped by conversation), not a single coalesced "N messages" banner. This is the privacy cost-of-business and is native iOS grouping behavior.

**Group-message note (future hardening):** multiple recipients of a group message share the same `messageID`, so a per-message collapse-id still lets Apple observe per-message co-occurrence across devices (no worse than today's timing correlation, and 1-1 — the primary case — is unaffected since there is a single recipient). Salting the collapse-id with the recipient's identity (`hex(hash(messageID‖recipientPubKey))`, computed identically by sender and recipient, supplied via the signal) would remove even that; deferred.

### Components

**status-go (small, 2 changes):**
1. `pushnotificationserver/gorush.go` — add `CollapseID` to `GoRushRequestNotification`, set it to `hex(messageID)` for APN tokens → APNS `apns-collapse-id`. The messageID is `PushNotificationRequest.MessageId`; plumb it from `sendPushNotification`/`buildPushNotificationRequestResponse` into `PushNotificationRegistrationToGoRushRequest`. (Extend `gorush_test.go`.)
2. Ensure `LocalNotificationsConfig.Enabled = true` for the iOS node config so the signal is emitted (verify; enable if absent).

*(No new local-notification field is needed — the signal already carries the message ID as `id`.)*

**status-desktop (Nim):**
4. Add a `local-notifications` `SignalType` (`= "local-notifications"`) + a signal struct (`signal_type.nim`, a new `*_signal.nim`, dispatch in `signals_manager.nim`) parsing the fields above.
5. A handler (extend `NotificationsManager` or a small iOS-gated handler) that, on iOS, applies the suppression rules and calls `PushNotifications.showNotification(displayTitle, displayMessage, identifier = id)` (the signal's `id` == the push messageID), with `threadIdentifier = conversationId`. Reuse the foreground-visible state the app already tracks.
6. Keep desktop on its existing `messages.new → showMessageNotification → StatusOSNotification` path; this new consumer is **iOS-gated** so the two don't double-fire.

**MobileUI:**
7. Verify `PushNotificationIOS::showNotification` posts a `UNNotificationRequest` with `request.identifier = identifier` (required for coalescing with the remote push's collapse-id == `hex(messageID)`). Extend the signature to accept a `threadIdentifier` (set to `conversationId`) for device-side per-conversation grouping; the current `showNotification(title, message, identifier)` has no thread param.

### Suppression rules (mirror Android `StatusNotificationManager`)
- `deleted == true` → skip.
- `isFromMe == true` → skip (the user's own message, e.g. sent from a paired desktop), unless a notification for that conversation is already active (refresh case).
- app foreground / active → skip (Android's `uiVisible`); reuse the app's foreground signal.
- `category` other than message types (e.g. `contactRequest`) → out of scope for v1; only `newMessage`-category events enrich. Non-message categories leave the anonymous banner.

### Privacy
- Content is the already-privacy-filtered `DisplayTitle`/`DisplayMessage`; users who reduced `notificationsMessagePreview` get less, automatically. Anonymous-level users get no enrichment by construction. Decryption is on-device; nothing readable transits the PNS/APNS.
- The push stays contentless. The only new exposure is the `apns-collapse-id`, set to **`hex(messageID)` — a per-message, nonce-like value**. Apple sees a fresh, unlinkable id per push, so **no stable per-conversation key is created** and no persistent social graph is exposed — preserving the current privacy posture (a unique-per-message id is ≈ what message timing already implies). The `threadIdentifier` used for per-conversation grouping is set **only on the local notification (device-side)** and is never transmitted to Apple.
- **Residual (group only, deferred):** recipients of the same group message share a `messageID`, so Apple could observe per-message co-occurrence across device tokens — no worse than today's timing correlation. 1-1 (the primary case) has a single recipient and is unaffected. Salting the collapse-id with the recipient identity removes even this; deferred.

## The make-or-break unknown (must device-verify early)
Does posting a **local** `UNNotificationRequest` whose `identifier` equals a **delivered remote** notification's `apns-collapse-id` **replace it in place without re-alerting**? This is the crux of "seamless." Verify on a physical device first. Fallbacks if it re-alerts or double-shows: (a) accept the re-alert; (b) investigate suppressing the replacement's alert (interruption level / sound = none on the update); (c) remove-then-repost (flash). This verification gates the rest of the implementation.

## Edge cases
- App not woken (Layer 1b best-effort) → anonymous banner stays (graceful, today's behavior).
- Sync fails / message not retrieved → anonymous stays.
- Multiple messages, same conversation → one banner **per message**, each replaced anonymous→enriched in place, grouped in the shade by `threadIdentifier = conversationId` (iOS-native grouping; not a single coalesced "N messages" banner — that would require the rejected per-conversation collapse-id).
- Multiple conversations → grouped into distinct conversation threads via `threadIdentifier`.
- Late-arriving push for an already-enriched message (retry) → same `apns-collapse-id` (`hex(messageID)`) → harmlessly re-shows that one message's banner (anonymous, then re-enriched on the next signal).
- Group/community: matching is automatic because both the push collapse-id and the signal `id` are the same messageID; whether a push fires for group/community at all is existing push behavior, not this design.
- `DisplayTitle`/`DisplayMessage` empty (older status-go path) → fall back to `Title`/`Message`, mirroring Android.

## Testing
- **status-go unit test:** extend `gorush_test.go` to assert `CollapseID == hex(messageID)` for APN tokens and absent/empty for Firebase tokens.
- **Nim:** test the signal handler dispatches `showNotification` with `identifier == ` the signal's `id` (the messageID) and `threadIdentifier == conversationId`, and honors the `deleted`/`isFromMe`/foreground suppression rules (mock the MobileUI show).
- **On-device smoke test (device-bound):** 1-1 message, app backgrounded → anonymous banner appears → after sync, replaced **in place** with sender + message, **no second buzz**. Verify `isFromMe` (send from paired desktop → no notification), `deleted`, and foreground suppression.

## References (code)
- Android reference: `mobile/android/qt6/src/app/status/mobile/ipc/notifications/StatusNotificationManager.java` (signal parsing ~`:92-167`, `conversationId` keying ~`:204`, `isFromMe`/`uiVisible` suppression ~`:95`,`:221`), `NotificationBuilder.java`; ADR-0002.
- Signal payload: `vendor/status-go/services/local-notifications/core.go` (`Notification` struct), `protocol/local_notifications.go` (`applyMessagePreview`/`applyAuthorPrivacy`).
- Push payload / collapse-id: `vendor/status-go/protocol/pushnotificationserver/gorush.go` (`GoRushRequestNotification`, `data.chatId`).
- iOS show primitive: `vendor/MobileUI/pushnotification_ios.{h,mm}` (`showNotification`), `vendor/MobileUI/pushnotifications.{h,cpp}` (QML singleton).
- Nim signal plumbing: `src/app/core/signals/remote_signals/signal_type.nim`, `src/app/core/signals/signals_manager.nim`; notification show path `src/app/core/notifications/notifications_manager.nim`.
- node config: `src/app_service/service/node_configuration/dto/node_config.nim:144` (`LocalNotificationsConfig`).
