# Android Push Notifications — FURPS Requirements

---

## Functionality

### F1 — Notification delivery
- **F1.1** The system must deliver notifications for incoming 1-1 messages, group chat messages, community channel messages, contact requests, and group/community invites.
- **F1.2** Notifications must be delivered via the Waku message stream processed by `StatusGoService`. No dependency on Google Firebase (FCM) or any third-party push gateway.
- **F1.3** Notifications must be delivered when the app UI is in the background, when the screen is off, and when the app is in a killed state (provided `StatusGoService` is running).
- **F1.4** Notifications must be suppressed when the app UI is in the foreground and the user is actively using the app.
- **F1.5** Sending a message must not produce a self-notification unless an existing conversation notification is already active in the OS notification shade, in which case it must append to that notification and refresh it.

### F2 — Privacy levels
- **F2.1** The system must enforce three user-configurable privacy levels: Anonymous (0), Name only (1), and Name and message (2).
- **F2.2** Privacy enforcement must be applied by `status-go` before the notification signal is emitted. The Android layer must not apply additional content filtering.
- **F2.3** At level 0 (Anonymous): title must be "Status", body must be "You have a new message", and no sender name, avatar, community icon, or group icon must be present in the payload.
- **F2.4** At level 1 (Name only): title must be the sender / chat / community name; body must be "You have a new message"; icons must be present.
- **F2.5** At level 2 (Name and message): title must be the sender / chat / community name; body must be the actual message content; icons must be present.

### F3 — Notification types and content
- **F3.1** 1-1 message notifications must show the contact name as the title and the contact avatar as the large icon (levels 1–2).
- **F3.2** Group chat notifications must show the group name as the title and the group icon as the large icon (levels 1–2).
- **F3.3** Community channel notifications must show the community / channel name as the title and the community icon as the large icon (levels 1–2).
- **F3.4** Contact request notifications must show the requester name and avatar (levels 1–2) and provide Accept / Reject actions (level 2 only).
- **F3.5** When no icon URI is provided by `status-go` (anonymous mode), the Android app launcher icon must be used as the large icon.
- **F3.6** The Status notification logo must always be used as the small icon (visible in the status bar).

### F4 — Conversation grouping
- **F4.1** Multiple messages from the same conversation must be grouped into a single `MessagingStyle` notification showing the conversation thread.
- **F4.2** The thread must display sender name, avatar, message content, and timestamp per message entry.
- **F4.3** When a new message arrives for a conversation that already has an active OS notification, the system must extract the existing message history from that notification using `MessagingStyle.extractMessagingStyleFromNotification()`, append the new message, and re-post the updated notification. No separate in-process message buffer is maintained.
- **F4.4** When a new message arrives for a conversation with no active notification, a fresh notification must be spawned.
- **F4.5** The message thread must be capped at `MessagingStyle.MAXIMUM_RETAINED_MESSAGES` entries; older entries must be dropped when the limit is exceeded.
- **F4.6** The large icon and title used for an existing conversation notification must be preserved from the active OS notification across updates, so the icon does not flicker or reset when new messages arrive.

### F5 — Actions
- **F5.1** Message notifications at level 2 must include an inline **Reply** action.
- **F5.2** Contact request notifications at level 2 must include **Accept** and **Reject** action buttons.
- **F5.3** A successful inline reply must update the notification thread with the sent message without requiring the app to be opened.
- **F5.4** A failed inline reply must post a "Reply failed" notification to inform the user.
- **F5.5** Dismissing (swiping away) a notification removes it from the OS notification shade; since conversation state is held in the active notification itself, dismissal is sufficient to reset the thread — no additional cleanup is required.

### F6 — Deep linking
- **F6.1** Tapping a notification must deep-link the user into the correct chat, community, or contact request screen inside the app.

---

## Usability

### U1 — Clarity
- **U1.1** The notification content at each privacy level must unambiguously communicate the appropriate amount of information and no more.
- **U1.2** At Anonymous level, the notification must be recognisable as coming from the Status app (via the app icon and "Status" title) without revealing any conversation details.
- **U1.3** The inline reply experience must not require the user to open the app; composing and sending the reply must be completable entirely from the notification shade.

### U2 — Consistency
- **U2.1** The notification visual style (icons, grouping, actions) must be consistent across all supported Android API levels (API 28+).
- **U2.2** The privacy level must take effect on the next received notification without requiring an app restart.
- **U2.3** The conversation title and large icon must remain stable across successive messages in the same notification thread; they must not reset or change when new messages arrive.

### U3 — Icon legibility
- **U3.1** Avatar and icon images used as large icons must be rendered as circles to match the Status design language.
- **U3.2** The large icon must be no larger than 256 × 256 px to avoid excessive memory usage; source images larger than this must be scaled down.

---

## Reliability

### R1 — Delivery guarantee
- **R1.1** Every `local-notifications` signal emitted by `status-go` while the service is running must result in an OS notification being posted or an existing conversation notification being updated, unless the UI is in the foreground.
- **R1.2** Any failure in notification processing (JSON parse error, missing fields, icon decode failure, active notification read failure) must be caught, logged, and silently discarded — it must not crash `StatusGoService`.

### R2 — Thread safety
- **R2.1** The `uiVisible` flag in `StatusNotificationManager` must be declared `volatile` and safe to read/write from any thread.
- **R2.2** All access to the OS notification shade (`NotificationManagerCompat.getActiveNotifications()`) must be wrapped in a `try/catch (Throwable)` block to handle any platform-level exceptions gracefully.

### R3 — Service resilience
- **R3.1** If `StatusGoService` is killed by the OS and restarted, any previously posted notifications remain visible in the OS notification shade. The next incoming message for a conversation with an active notification must correctly append to it by re-reading the existing `MessagingStyle` from the OS.
- **R3.2** Notification delivery must resume automatically when the service restarts without user intervention.

### R4 — Stale state
- **R4.1** When the app UI comes to the foreground, all active notifications on the messages channel must be cancelled. Since conversation state lives in the OS notification itself, cancelling the notification is sufficient — no additional in-process state needs to be cleared.

---

## Performance

### P1 — Latency
- **P1.1** The time from `StatusGoService.onNativeSignal()` receiving a notification signal to `NotificationManagerCompat.notify()` being called must be under **100 ms** on the handler thread.
- **P1.2** Icon decoding (base64 data URI → Bitmap) must not block the handler thread; failures must return `null` quickly and not stall notification posting.
- **P1.3** Reading back the existing `MessagingStyle` from the active OS notification must be treated as a best-effort operation; if it fails or returns no result, the system must proceed with a fresh notification rather than blocking or retrying.

### P2 — Memory
- **P2.1** Icon bitmaps must be scaled to at most 256 × 256 px before being passed to the notification system to avoid excessive heap allocation.
- **P2.2** The message thread displayed in a notification must be capped at `MessagingStyle.MAXIMUM_RETAINED_MESSAGES`; the system must not accumulate an unbounded number of entries.
- **P2.3** `StatusNotificationManager` must hold a `WeakReference<Context>` to the service to avoid leaking the service context.
- **P2.4** No in-process conversation buffer is maintained between notifications; all per-conversation state is stored in the OS notification itself, eliminating the risk of unbounded in-memory growth across conversations.

### P3 — Battery / CPU
- **P3.1** Notification processing must be event-driven (signal-triggered); there must be no polling or wake-lock held by the notification subsystem itself.

---

## Supportability

### S1 — Logging
- **S1.1** All non-fatal errors in the notification pipeline (JSON parse failures, icon decode failures, active notification read failures, shortcut push failures) must be logged at `WARN` level with the tag of the originating class.
- **S1.2** Logging must not include message content or sender identity at any log level (to avoid leaking private data to logcat).

### S2 — Maintainability
- **S2.1** Privacy enforcement logic must live exclusively in `status-go` (`local_notifications.go`) so it can be updated and tested without Android build changes.
- **S2.2** The Android notification layer must remain a stateless renderer: `NotificationBuilder` must own no buffers or caches and receive all data as parameters.
- **S2.3** `NotificationIconHelper` must be a stateless utility class with no Android lifecycle dependencies.
- **S2.4** Conversation state (message history, title, large icon) must be stored in the OS notification, not in any in-process data structure, so the state survives `StatusGoService` restarts and does not require explicit lifecycle management.

### S3 — Extensibility
- **S3.1** Adding a new notification category must require changes only in `status-go` (signal payload) and `NotificationIconHelper.pickLargeIconUri()` (icon selection); no structural changes to `NotificationBuilder` or `StatusNotificationManager` should be needed.
- **S3.2** Adding a new privacy level must require changes only in `status-go` (`applyMessagePreview`, `applyAuthorPrivacy`); the Android layer must need no modification.

### S4 — Testability
- **S4.1** `NotificationIconHelper` must be testable in isolation (pure static methods, no Android lifecycle).
- **S4.2** Privacy-level enforcement must be covered by Go unit tests in `status-go` independently of the Android build.

### S5 — API compatibility
- **S5.1** The implementation must support Android API 28 (`minSdkVersion`) as the minimum and must not crash on any API level between 28 and the current `compileSdkVersion`.
- **S5.2** API-level-gated code paths (e.g. conversation shortcuts on API 30+, `getLargeIcon()` on API 23+) must be guarded by `Build.VERSION.SDK_INT` checks and must degrade gracefully on older versions.
