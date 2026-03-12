# ADR-0003: Android Waku-Driven Local Notifications

## Status
- **Proposed**
- **Date**: 2026-03-11
- **Owners**: Status Desktop (Android target)

## Why

Status Android must deliver chat notifications **without depending on Google Firebase (FCM/GMS)**. This is a hard requirement for de-googled phones (e.g. GrapheneOS, CalyxOS) and aligns with the principle that infrastructure should not spy on communication metadata.

At the same time, notification delivery must respect the user's configured **privacy level** so the OS notification shade never reveals more than the user has consented to expose.

This ADR documents the architecture and key decisions for the waku-driven local notification pipeline now implemented.

---

## Context

### Constraints
- No Google Play Services dependency.
- Notifications must work while the app UI is not in the foreground.
- The Android OS notification shade is outside the app sandbox; content shown there must be privacy-filtered.
- The notification system must support inline reply without opening the app.
- The implementation must be maintainable across status-go and Android (Java) codebases that evolve independently.

### Existing infrastructure
- `StatusGoService` runs in a separate process and keeps `libstatus.so` alive (see ADR-0001).
- `status-go` already produces a `local-notifications` signal stream for in-app use.

---

## Decision

### 1. Waku as the notification transport

Notifications are driven entirely by the **Waku message stream** received by the running `StatusGoService`. There is no dependency on FCM, APNs, or any third-party push gateway.

`status-go` processes each received message through its local-notifications pipeline and emits a `local-notifications` JSON signal when a notification should be shown. `StatusGoService` dispatches these signals to `StatusNotificationManager`, which posts the OS notification.

**Why not FCM as a fallback?**
FCM leaks metadata (sender, timing) to Google infrastructure. For the initial implementation we accept that notifications require the service to be running. A push-as-wakeup extension (see Follow-ups) can add FCM as an opt-in layer later without changing this architecture.

---

### 2. status-go is the intelligence layer; Android is a dumb renderer

All decisions about **what to show** are made in `status-go`:

- Which notifications to emit (per chat settings, mute, exemptions).
- What the title, body, and icon URIs contain (based on privacy level).
- Whether identity-revealing fields (sender name, avatar, community icon) are included.

The Android layer (`StatusNotificationManager`, `NotificationBuilder`) is a **renderer**. It reads the JSON payload and posts the OS notification exactly as instructed. It does not apply additional content filtering or privacy logic.

**Rationale:** this separation keeps the privacy logic in one place (Go, testable with unit tests), avoids duplicating business logic across platforms, and makes the Android side easier to reason about.

---

### 3. Privacy enforcement in status-go

User privacy is configured via **Settings → Notifications → Show notifications** with three levels:

| Level | Value | Title | Body | Identity (author, icons) |
|---|---|---|---|---|
| Anonymous | 0 | "Status" | "You have a new message" | Stripped |
| Name only | 1 | sender / chat name | "You have a new message" | Preserved |
| Name and message | 2 | sender / chat name | actual message | Preserved |

`status-go` applies two transformations before emitting the notification signal:

**`applyMessagePreview`** — controls `displayTitle` and `displayMessage` based on the level.

**`applyAuthorPrivacy`** — when level is Anonymous, clears `Author` (name, icon, ID), `CommunityIcon`, and `ChatIcon` from the notification payload. The Android side receives empty icon URIs and renders without them.

Both transformations are applied in every notification builder function (`toMessageNotification`, `toContactRequestNotification`, `toPrivateGroupInviteNotification`, `toCommunityRequestToJoinNotification`).

---

### 4. Notification types and icon strategy

The Android renderer selects the large icon based on category and the icon URIs present in the payload:

| Notification type | Large icon (level ≥ 1) | Large icon (level 0 / no URI) | Small icon |
|---|---|---|---|
| 1-1 message | Contact avatar (circular) | App launcher icon | Status logo |
| Group chat | Group chat icon (circular) | App launcher icon | Status logo |
| Community channel | Community icon (circular) | App launcher icon | Status logo |
| Contact request | Requester avatar (circular) | App launcher icon | Status logo |

When no icon URI is present (anonymous mode), `NotificationIconHelper.appIconBitmap()` loads the app's launcher icon via `PackageManager.getApplicationIcon()` — the same icon the user sees in the app list. The Status notification logo is always used as the small icon (required by Android; visible in the status bar).

---

### 5. MessagingStyle for conversation grouping

Message notifications use `NotificationCompat.MessagingStyle` rather than plain `BigTextStyle`. This:

- Groups multiple messages from the same conversation under a single notification.
- Shows the conversation thread natively (sender name, avatar, message, timestamp per bubble).
- Supports inline reply via `RemoteInput` without opening the app.
- Enables Android conversation shortcuts and bubbles (API 30+) via `ShortcutInfoCompat`.

`MessageBufferManager` maintains a per-conversation `LinkedList<MessageEntry>` (capped at 5 messages) that survives multiple incoming notifications. Access to each list is `synchronized` on the list instance; `getMessages()` returns a snapshot `ArrayList` to prevent `ConcurrentModificationException` during iteration.

---

### 6. Outgoing message handling (`isFromMe`)

When the user sends a message, `status-go` emits a `local-notifications` signal with `isFromMe: true`. The Android layer uses this to:

- **Skip** posting a notification if no incoming-message notification for this conversation is currently active (the user is the first sender; nothing to refresh).
- **Refresh** an existing conversation notification by appending the sent message to the MessagingStyle thread, so the notification reflects the full conversation.

This prevents the user from seeing a notification for their own messages while still keeping an active notification up to date.

---

### 7. Foreground suppression

`StatusNotificationManager` tracks a `uiVisible` flag (set by `StatusGoService.setUiVisible()`). When `true`, all incoming local-notification signals are silently dropped — the user is looking at the app and does not need an OS notification.

When the UI comes to the foreground, all active notifications are cancelled and message buffers cleared so there is no stale state when the user returns to the background.

---

### 8. Inline reply

`NotificationReplyReceiver` is a `BroadcastReceiver` that handles the `ACTION_REPLY` intent emitted when the user taps Reply on a notification. It:

1. Extracts the reply text from `RemoteInput`.
2. Calls `StatusGoService.callRpc("wakuext_sendChatMessage", ...)` directly (same process — no Binder round-trip needed).
3. On success the notification is updated with the sent message via a new `local-notifications` signal from `status-go`.
4. On failure a "Reply failed" notification is shown.

---

## What was considered

### FCM as the primary transport
Rejected. FCM requires Google Play Services (unavailable on de-googled phones) and leaks metadata to Google infrastructure, which is incompatible with Status privacy principles.

### Decrypt-and-notify from FCM payload (iOS-style)
Considered for a future push-as-wakeup extension (see ADR-0002). Not suitable as the primary mechanism because it requires keys to be available in a restricted background context.

### Privacy enforcement on the Android side
Rejected. Duplicates logic, is harder to test in isolation, and creates a divergence risk as notification types evolve. `status-go` is the single source of truth for what content is safe to expose.
---

## Architecture diagram

```
  status-go (Go)                         Android (Java)
  ─────────────────────────────          ─────────────────────────────────────────
  Waku message received
        │
  local_notifications.go
  - applyMessagePreview()        JSON signal
  - applyAuthorPrivacy()    ───────────────────►  StatusGoService.onNativeSignal()
        │                                                │
  signal/events_pn.go                     StatusNotificationManager.handleSignal()
  SendLocalNotifications()                               │
                                          ┌────────────────────────────┐
                                          │  parse JSON fields:        │
                                          │  displayTitle/Message      │
                                          │  notificationAuthor        │
                                          │  communityIcon/chatIcon    │
                                          │  category, isFromMe        │
                                          └────────────┬───────────────┘
                                                       │
                                          NotificationBuilder
                                          - MessagingStyle / BigTextStyle
                                          - large icon (sender / app icon)
                                          - small icon (Status logo)
                                          - Reply / Accept / Reject actions
                                                       │
                                          NotificationManagerCompat.notify()
```

---

## Consequences

### Positive
- No Google dependency; works on all Android devices including de-googled.
- Privacy enforcement is centralised in `status-go`, testable, and consistent across platforms.
- Conversation thread grouping (MessagingStyle) provides a native, high-quality notification UX.
- Inline reply does not require opening the app.
- Clean separation: `status-go` decides what to show; Android decides how to render it.

### Negative / trade-offs
- Notifications require `StatusGoService` to be running. If the OS kills the service, notifications stop until the app is reopened.
- The "always-on foreground service" notification (from ADR-0001) is required for reliable background delivery, which some users may find intrusive.
- Higher battery usage

---

## Follow-ups

- **Push-as-wakeup (optional):** FCM data message wakes the service; Waku re-syncs and delivers the actual notification through the normal local-notifications pipeline. No payload decryption in the push handler.
- **Push-as-backup (optional):** Register the device for FCM push notifications whenever the status-go service gets shut-down
- **Light mode for status-go:** Whenever the app is either killed or in background status-go should stop all the background work except for waku. Resume will re-enable the services
- **Proper sign out:**  Shut down the android service whenever the user will manually sign out and quit
- **Speed-up the app loading:** The app loading time is quite high when restoring the logged-in state
- **Keep status-go in-process when push notifications are disabled** Status-go could potentially be keps in-process whenever the push notifications are not enabled.
---

## References (code)

- Notification orchestrator: `mobile/android/qt6/src/app/status/mobile/ipc/notifications/StatusNotificationManager.java`
- Notification builder: `mobile/android/qt6/src/app/status/mobile/ipc/notifications/NotificationBuilder.java`
- Icon helpers: `mobile/android/qt6/src/app/status/mobile/ipc/notifications/NotificationIconHelper.java`
- Inline reply: `mobile/android/qt6/src/app/status/mobile/ipc/NotificationReplyReceiver.java`
- status-go notification logic: `vendor/status-go/protocol/local_notifications.go`
- status-go notification core: `vendor/status-go/services/local-notifications/core.go`
- status-go signal emission: `vendor/status-go/signal/events_pn.go`
