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
1. Anonymous push (alert + `content-available` + **new** `apns-collapse-id = hex(Shake256(chatID))`) → Layer 1b wakes the app.
2. App syncs; status-go processes messages and emits the `local-notifications` signal with privacy-filtered `DisplayTitle`/`DisplayMessage`, `ConversationID`, and **the same collapse-id value**.
3. **New iOS consumer:** the Nim signal handler receives the event, applies the suppression rules (below), and calls `PushNotifications.showNotification(displayTitle, displayMessage, identifier = collapseId)`.
4. iOS coalesces by `request.identifier` (== the push's `apns-collapse-id`) → **replaces the anonymous banner in place**. Multiple messages in one conversation collapse into a single updating notification (latest message shown).

### Identifier scheme (the correlation key)
The anonymous push's `apns-collapse-id` and the replacement local notification's `identifier` **must be the same string**, and that string must be derivable on the device without hashing. Therefore **status-go provides it in both places**:
- gorush sets `apns-collapse-id = hex(Shake256(chatID))` (already computed as `data.chatId`).
- the `local-notifications` signal includes the **same** `hex(Shake256(ConversationID))` as a dedicated field (e.g. `pushCollapseId`), so the Nim consumer uses it verbatim as the notification identifier.

This mirrors Android keying notifications by `conversationId`; here the key is its Shake256 (privacy-preserving) so it matches the contentless push.

### Components

**status-go (small, 3 changes):**
1. `pushnotificationserver/gorush.go` — add `CollapseID` to `GoRushRequestNotification`, set it to the hashed chatId (`data.chatId`) for APN tokens → APNS `apns-collapse-id`. (Extend `gorush_test.go`.)
2. `services/local-notifications/core.go` — add the `pushCollapseId` field (= `hex(Shake256(ConversationID))`) to the emitted `Notification`, so the device need not hash.
3. Ensure `LocalNotificationsConfig.Enabled = true` for the iOS node config so the signal is emitted (verify; enable if absent).

**status-desktop (Nim):**
4. Add a `local-notifications` `SignalType` (`= "local-notifications"`) + a signal struct (`signal_type.nim`, a new `*_signal.nim`, dispatch in `signals_manager.nim`) parsing the fields above.
5. A handler (extend `NotificationsManager` or a small iOS-gated handler) that, on iOS, applies the suppression rules and calls `PushNotifications.showNotification(displayTitle, displayMessage, identifier = pushCollapseId)`. Reuse the foreground-visible state the app already tracks.
6. Keep desktop on its existing `messages.new → showMessageNotification → StatusOSNotification` path; this new consumer is **iOS-gated** so the two don't double-fire.

**MobileUI:**
7. Verify `PushNotificationIOS::showNotification` posts a `UNNotificationRequest` with `request.identifier = identifier` (required for coalescing with the remote push's collapse-id); set `content.threadIdentifier = identifier` for grouping. Extend if it doesn't.

### Suppression rules (mirror Android `StatusNotificationManager`)
- `deleted == true` → skip.
- `isFromMe == true` → skip (the user's own message, e.g. sent from a paired desktop), unless a notification for that conversation is already active (refresh case).
- app foreground / active → skip (Android's `uiVisible`); reuse the app's foreground signal.
- `category` other than message types (e.g. `contactRequest`) → out of scope for v1; only `newMessage`-category events enrich. Non-message categories leave the anonymous banner.

### Privacy
- Content is the already-privacy-filtered `DisplayTitle`/`DisplayMessage`; users who reduced `notificationsMessagePreview` get less, automatically. Anonymous-level users get no enrichment by construction.
- The push stays contentless **except** the new `apns-collapse-id`. That value is `Shake256(chatID)` — the same one-way hash already in the payload, so no new *content* is exposed. **Tradeoff to accept:** `apns-collapse-id` is an APNS *header* Apple actively uses, so Apple gains a **stable pseudonymous per-conversation key** (it can correlate/count pushes for a given hashed conversation over time). It is not reversible to the chat, and it is required for seamless in-place replacement. A rotating collapse-id would defeat the matching, so the stable hash is intentional.

## The make-or-break unknown (must device-verify early)
Does posting a **local** `UNNotificationRequest` whose `identifier` equals a **delivered remote** notification's `apns-collapse-id` **replace it in place without re-alerting**? This is the crux of "seamless." Verify on a physical device first. Fallbacks if it re-alerts or double-shows: (a) accept the re-alert; (b) investigate suppressing the replacement's alert (interruption level / sound = none on the update); (c) remove-then-repost (flash). This verification gates the rest of the implementation.

## Edge cases
- App not woken (Layer 1b best-effort) → anonymous banner stays (graceful, today's behavior).
- Sync fails / message not retrieved → anonymous stays.
- Multiple messages, same conversation → one notification, updated to the latest (coalesced by identifier).
- Multiple conversations → one notification each (distinct collapse-ids).
- Group/community: works because status-go supplies the identical collapse-id in both the push and the signal; whether a push fires for group/community at all is existing push behavior, not this design.
- `DisplayTitle`/`DisplayMessage` empty (older status-go path) → fall back to `Title`/`Message`, mirroring Android.

## Testing
- **status-go unit test:** extend `gorush_test.go` to assert `apns-collapse-id` (CollapseID) is set to the hashed chatId for APN tokens and absent for Firebase; assert the `pushCollapseId` field is emitted on the local-notification.
- **Nim:** test the signal handler dispatches `showNotification` with `identifier == pushCollapseId` and honors the `deleted`/`isFromMe`/foreground suppression rules (mock the MobileUI show).
- **On-device smoke test (device-bound):** 1-1 message, app backgrounded → anonymous banner appears → after sync, replaced **in place** with sender + message, **no second buzz**. Verify `isFromMe` (send from paired desktop → no notification), `deleted`, and foreground suppression.

## References (code)
- Android reference: `mobile/android/qt6/src/app/status/mobile/ipc/notifications/StatusNotificationManager.java` (signal parsing ~`:92-167`, `conversationId` keying ~`:204`, `isFromMe`/`uiVisible` suppression ~`:95`,`:221`), `NotificationBuilder.java`; ADR-0002.
- Signal payload: `vendor/status-go/services/local-notifications/core.go` (`Notification` struct), `protocol/local_notifications.go` (`applyMessagePreview`/`applyAuthorPrivacy`).
- Push payload / collapse-id: `vendor/status-go/protocol/pushnotificationserver/gorush.go` (`GoRushRequestNotification`, `data.chatId`).
- iOS show primitive: `vendor/MobileUI/pushnotification_ios.{h,mm}` (`showNotification`), `vendor/MobileUI/pushnotifications.{h,cpp}` (QML singleton).
- Nim signal plumbing: `src/app/core/signals/remote_signals/signal_type.nim`, `src/app/core/signals/signals_manager.nim`; notification show path `src/app/core/notifications/notifications_manager.nim`.
- node config: `src/app_service/service/node_configuration/dto/node_config.nim:144` (`LocalNotificationsConfig`).
