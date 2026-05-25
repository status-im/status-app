# iOS Push Enriched Banner (local-notifications replacement) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** After Layer 1b's background sync, replace the anonymous iOS push **in place** with status-go's privacy-filtered `local-notifications` content — Layer 2's enriched banner without an NSE.

**Architecture:** A per-message `apns-collapse-id = hex(messageID)` lets a local notification (posted with `identifier = ` the same messageID) coalesce with / replace the delivered anonymous push. status-go emits the privacy-filtered `local-notifications` signal (which already carries that messageID as `id`); a new Nim consumer applies Android-style suppression rules and, on iOS, routes the show through QML to MobileUI's `PushNotifications.showNotification`. Per-conversation grouping uses a device-side `threadIdentifier` only (never sent to Apple, preserving the contentless/privacy posture).

**Tech Stack:** Go (status-go `pushnotificationserver`), Nim (signals + notifications manager), QML (`AppMain`), Objective-C++ (`vendor/MobileUI`), APNS via gorush.

**Spec:** `docs/superpowers/specs/2026-05-25-ios-push-enriched-banner-design.md`. **Builds on:** Layer 1b (`docs/superpowers/plans/2026-05-25-ios-push-layer1b-background-sync.md`).

---

## Plan shape & scope (read first)

- **Task 1 is a device-bound GATE** (per the spec's make-or-break unknown). Run it first; it requires a physical device + the `~/.status-pns/` pipeline. If in-place replacement re-alerts/double-shows, stop and renegotiate the approach before building Tasks 4–7.
- **status-go has uncommitted local-dev PNS patches** (cluster.go/config.go/client.go — do not commit). The gorush change in Task 2 is the only status-go change meant to land (it belongs in a status-go PR alongside the earlier `89d9d2e378` flags commit).
- **MobileUI changes** (Task 4) land in `vendor/MobileUI` (own git repo) and need their own MobileUI PR + FetchContent pin bump; the local FetchContent override is already in place.
- **Verification is device-bound** (Tasks 1, 7). Subagents can write Tasks 2–6; the device runs on your machine.
- TDD applies to the Go and Nim units; the QML/MobileUI/show wiring and the device tasks are integration-verified.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `vendor/status-go/protocol/pushnotificationserver/gorush.go` (modify) | Set `apns-collapse-id = hex(messageID)` for APN tokens | 2 |
| `vendor/status-go/protocol/pushnotificationserver/server.go` (modify) | Plumb `request.MessageId` into the gorush builder | 2 |
| `vendor/status-go/protocol/pushnotificationserver/gorush_test.go` (modify) | Assert collapse-id == hex(messageID) | 2 |
| status-go iOS node config (verify/modify) | `LocalNotificationsConfig.Enabled = true` | 3 |
| `vendor/MobileUI/pushnotification_ios.{h,mm}`, `pushnotifications.{h,cpp}` (modify) | `showNotification(..., threadIdentifier)` → sets `content.threadIdentifier` | 4 |
| `src/app/core/signals/remote_signals/signal_type.nim` (modify) | Add `LocalNotifications = "local-notifications"` | 5 |
| `src/app/core/signals/remote_signals/local_notifications.nim` (create) | `LocalNotificationsSignal` + `fromEvent` | 5 |
| `src/app/core/signals/signals_manager.nim` (modify) | Dispatch the new signal | 5 |
| `src/app/core/notifications/notifications_manager.nim` (modify) | Consume the signal, suppression rules, iOS show event | 6 |
| `src/app/core/notifications/details.nim` or `app_signals` (modify) | `SIGNAL_DISPLAY_MOBILE_OS_NOTIFICATION` + args | 6 |
| `ui/app/mainui/AppMain.qml` (modify) | QML sink → `PushNotifications.showNotification` | 6 |

---

## Task 1: Device GATE — in-place replacement without re-alert

**Why first:** the entire "seamless" design hinges on iOS replacing a delivered remote notification (identified by `apns-collapse-id`) when a *local* notification is posted with the same `identifier`, **without a second alert**. Verify before building.

**Files:** none (manual verification on a physical device).

- [ ] **Step 1: Send a remote push with a known collapse-id.** With gorush running (`~/.status-pns/`, sandbox APNS) and a registered device token `<TOKEN>`, post directly to gorush:

Run:
```bash
curl -s -X POST http://localhost:8088/api/push -H 'Content-Type: application/json' -d '{
  "notifications":[{"tokens":["<TOKEN>"],"platform":1,"topic":"app.status.mobile",
  "message":"You have a new message","collapse_id":"gatetest123","mutable_content":true,"content_available":true}]}'
```
Expected: gorush returns success; an anonymous banner "You have a new message" appears on the device. Note its `apns-collapse-id` is `gatetest123`.

- [ ] **Step 2: Post a local notification with the SAME identifier.** Add a temporary debug trigger in QML (a button or `Component.onCompleted`) that calls `PushNotifications.showNotification("Alice", "Hey there", "gatetest123")`, build & run, and fire it while the anonymous banner is still on screen. (Throwaway; remove after.)

- [ ] **Step 3: Observe and record the result.** Determine: (a) does the banner update **in place** to "Alice / Hey there" (same notification), or does a **second** notification appear? (b) does the update **re-alert** (sound/vibration/banner re-present)?

- [ ] **Step 4: Decision gate.**
  - **In place, no re-alert** → proceed with the plan as-is.
  - **In place, but re-alerts** → proceed, but add to Task 4 a silent update (set the replacement's `sound = nil` and consider `interruptionLevel = .passive`); re-verify.
  - **Two notifications (no replacement)** → the local-identifier↔remote-collapse-id assumption is false; STOP and renegotiate (fallback: app removes the delivered anonymous notification by reading its `apns-collapse-id` from `getDeliveredNotifications` then posts the enriched one — a flash/re-alert design change).

- [ ] **Step 5: Record findings** in `docs/superpowers/research/2026-ios-push-replacement-gate.md` (the observed behavior + which branch of Step 4 applies) and commit `--no-gpg-sign`.

---

## Task 2: status-go — `apns-collapse-id = hex(messageID)`

**Why:** gives the anonymous push the per-message identifier the local notification will match. Per-message (not per-conversation) — privacy-preserving.

**Files:**
- Modify: `vendor/status-go/protocol/pushnotificationserver/gorush.go` (struct + `PushNotificationRegistrationToGoRushRequest` signature/body)
- Modify: `vendor/status-go/protocol/pushnotificationserver/server.go:465` (`sendPushNotification`) and its caller at `:182` to pass the messageID
- Test: `vendor/status-go/protocol/pushnotificationserver/gorush_test.go`

> Run Go from `vendor/status-go/`. If a `libsds.h` CGO error appears, prefix with `LD_LIBRARY_PATH="/Users/alexjbanca/Repos/nim-sds/build" CGO_LDFLAGS="-L/Users/alexjbanca/Repos/nim-sds/build -lsds" CGO_CFLAGS="-I/Users/alexjbanca/Repos/nim-sds/library"`.

- [ ] **Step 1: Write the failing test.** In `gorush_test.go`, the test builder calls `PushNotificationRegistrationToGoRushRequest(...)`. Change the call to pass a messageID and assert it lands as `CollapseID` on APN entries. Add:
```go
	messageID := []byte("msg-id-42")
	// ... in the call: PushNotificationRegistrationToGoRushRequest(requestAndRegistrations, messageID)
	require.Equal(t, types.EncodeHex(messageID), actualRequests.Notifications[0].CollapseID) // APN token
	require.Empty(t, actualRequests.Notifications[1].CollapseID)                              // Firebase token
```
(Use the existing `actualRequests`/`expectedRequests` style; index 0 is the APN token.)

- [ ] **Step 2: Run the test to verify it fails.**
Run: `make test-single PKG=./protocol/pushnotificationserver/... TEST=TestPushNotificationRegistrationToGoRushRequest`
Expected: FAIL — `CollapseID` undefined / wrong arity.

- [ ] **Step 3: Add the field and parameter.** In `gorush.go`, add to `GoRushRequestNotification`:
```go
	CollapseID string `json:"collapse_id,omitempty"`
```
Change the builder signature and set the field for APN tokens only:
```go
func PushNotificationRegistrationToGoRushRequest(requestAndRegistrations []*RequestAndRegistration, messageID []byte) *GoRushRequest {
	// ... inside the loop, where isAPN is computed:
	collapseID := ""
	if isAPN {
		collapseID = types.EncodeHex(messageID)
	}
	// ... in the appended &GoRushRequestNotification{...}: add  CollapseID: collapseID,
```

- [ ] **Step 4: Plumb the messageID from the caller.** In `server.go`, change `sendPushNotification` to accept and forward the messageID:
```go
func (s *Server) sendPushNotification(requestAndRegistrations []*RequestAndRegistration, messageID []byte) error {
	// ...
	goRushRequest := PushNotificationRegistrationToGoRushRequest(requestAndRegistrations, messageID)
```
At the call site (`server.go:182`, inside `HandlePushNotificationRequest`, where `request` is in scope): `err = s.sendPushNotification(requestsAndRegistrations, request.MessageId)`.

- [ ] **Step 5: Run the test to verify it passes.**
Run: `make test-single PKG=./protocol/pushnotificationserver/... TEST=TestPushNotificationRegistrationToGoRushRequest`
Expected: PASS.

- [ ] **Step 6: Build & vet.**
Run: `go build ./protocol/pushnotificationserver/... && go vet ./protocol/pushnotificationserver/...`
Expected: clean.

- [ ] **Step 7: Commit** (in vendor/status-go).
```bash
git -C vendor/status-go add protocol/pushnotificationserver/gorush.go protocol/pushnotificationserver/server.go protocol/pushnotificationserver/gorush_test.go
git -C vendor/status-go commit --no-gpg-sign -m "feat(push): set per-message apns-collapse-id (messageID) for APN tokens"
```

---

## Task 3: status-go — confirm the `local-notifications` signal fires on iOS — RESOLVED, NO CHANGE

**Finding (verified 2026-05-25):** no config change is needed. `LocalNotificationsConfig.Enabled` is a **phantom field** — it exists only as a Nim DTO deserialization target (`node_config.nim:144`) and is **never used anywhere in status-go's Go code** (`grep LocalNotificationsConfig vendor/status-go` → empty). The `local-notifications` signal is emitted **unconditionally** by `pushMessage` → `signal.SendLocalNotifications` (`services/local-notifications/core.go:151`); the only upstream gate is `GetAllowNotifications()` (`internal/db/multiaccounts/settings_notifications/database.go`), which **defaults to `true`**, and the service is always registered (`pkg/backend/node/status_node_services.go:119` — "We ignore for now local notifications flag").

**So:** the signal already fires on iOS by default. **No edit, no commit for this task.** The only residual risk — that something sets `AllowNotifications = false` on iOS — is confirmed at the device test (Task 7). If Task 7 shows the signal never arrives, investigate `AllowNotifications`, not `LocalNotificationsConfig`.

---

## Task 4: MobileUI — `showNotification` with `threadIdentifier`

**Why:** per-conversation grouping in the shade, device-side only. Also confirm the request identifier == the passed identifier (required for collapse-id matching).

**Files (in `vendor/MobileUI`, own git repo):** `pushnotification_ios.{h,mm}`, `pushnotifications.{h,cpp}`.

- [ ] **Step 1: Confirm the current identifier handling.** Read `pushnotification_ios.mm:222-255`; confirm `UNNotificationRequest requestWithIdentifier:identifierCopy` uses the passed identifier (it does). No change needed there beyond adding the thread param.

- [ ] **Step 2: Add `threadIdentifier` to the iOS impl.** In `pushnotification_ios.h`, change:
```cpp
void showNotification(const QString& title, const QString& message, const QString& identifier, const QString& threadIdentifier);
```
In `pushnotification_ios.mm` (the `showNotification` body, ~`:231`), after building `content`:
```objc
        if (!threadIdentifier.isEmpty())
            content.threadIdentifier = threadIdentifier.toNSString();
```
(Thread the new `threadIdentifier` arg through the lambda/`copy` the same way `identifier` is handled.)

- [ ] **Step 3: Thread it through the cross-platform QObject.** In `pushnotifications.h`, change the `Q_INVOKABLE`:
```cpp
Q_INVOKABLE void showNotification(const QString& title, const QString& message, const QString& identifier, const QString& threadIdentifier = QString());
```
In `pushnotifications.cpp`, forward `threadIdentifier` to `PushNotificationIOS::instance()->showNotification(...)` in the iOS arm; `Q_UNUSED(threadIdentifier)` in the others.

- [ ] **Step 4: Static self-check** — signatures match across `.h`/`.mm`/`.cpp`; default arg keeps existing QML callers (`NotificationsView`) compiling.

- [ ] **Step 5: Commit** (in vendor/MobileUI):
```bash
git -C vendor/MobileUI add pushnotification_ios.h pushnotification_ios.mm pushnotifications.h pushnotifications.cpp
git -C vendor/MobileUI commit --no-gpg-sign -m "feat(ios): showNotification threadIdentifier for per-conversation grouping"
```

---

## Task 5: Nim — add the `local-notifications` SignalType

**Why:** the signal is not consumed today; add the type + struct + dispatch so the app receives it.

**Files:** `signal_type.nim` (modify), `remote_signals/local_notifications.nim` (create), `signals_manager.nim` (modify). Mirror `remote_signals/messages.nim` + its dispatch line `of SignalType.Message: MessageSignal.fromEvent(jsonSignal)`.

- [ ] **Step 1: Add the enum value.** In `src/app/core/signals/remote_signals/signal_type.nim`, add to the `SignalType` enum:
```nim
  LocalNotifications = "local-notifications"
```

- [ ] **Step 2: Create the signal struct.** Create `src/app/core/signals/remote_signals/local_notifications.nim` mirroring `messages.nim`'s structure (imports `base`, `include app_service/common/json_utils`, a `fromEvent` proc). Parse the fields the spec lists:
```nim
import json
import base
include app_service/common/json_utils

type LocalNotificationSignal* = ref object of Signal
  id*: string
  category*: string
  conversationId*: string
  displayTitle*: string
  displayMessage*: string
  title*: string
  message*: string
  deepLink*: string
  isFromMe*: bool
  deleted*: bool

proc fromEvent*(T: type LocalNotificationSignal, event: JsonNode): LocalNotificationSignal =
  result = LocalNotificationSignal()
  result.signalType = SignalType.LocalNotifications
  let e = event["event"]
  result.id = e{"id"}.getStr()
  result.category = e{"category"}.getStr()
  result.conversationId = e{"conversationId"}.getStr()
  result.displayTitle = e{"displayTitle"}.getStr()
  result.displayMessage = e{"displayMessage"}.getStr()
  result.title = e{"title"}.getStr()
  result.message = e{"message"}.getStr()
  result.deepLink = e{"deepLink"}.getStr()
  result.isFromMe = e{"isFromMe"}.getBool()
  result.deleted = e{"deleted"}.getBool()
```
(Confirm the `event` wrapper shape against `messages.nim`; status-go wraps the payload under `"event"`.)

- [ ] **Step 3: Dispatch it.** In `src/app/core/signals/signals_manager.nim`, add to the `case` (next to `of SignalType.Message: ...`):
```nim
      of SignalType.LocalNotifications: LocalNotificationSignal.fromEvent(jsonSignal)
```
Add `import remote_signals/local_notifications` at the top with the other signal imports.

- [ ] **Step 4: Build-check the Nim module compiles** (or defer to Task 7's build). Commit:
```bash
git add src/app/core/signals/remote_signals/signal_type.nim src/app/core/signals/remote_signals/local_notifications.nim src/app/core/signals/signals_manager.nim
git commit --no-gpg-sign -m "feat: parse status-go local-notifications signal"
```

---

## Task 6: Nim consumer + suppression + iOS show wiring

**Why:** turn the parsed signal into an enriched OS notification on iOS, with Android-style suppression, routed through QML to MobileUI.

**Files:** `notifications_manager.nim` (modify), a new `SIGNAL_DISPLAY_MOBILE_OS_NOTIFICATION` (in `notifications_manager.nim` consts + `NotificationArgs` already exists), `ui/app/mainui/AppMain.qml` (modify). The manager already subscribes to global events and has `showOSNotification`.

- [ ] **Step 1: Subscribe to the new signal.** Where `NotificationsManager` wires up (its `setup`/`onAppReady`), subscribe to the `LocalNotifications` signal via the app's signal→eventemitter path (mirror how an existing service subscribes to a `SignalType`). On receipt, call a new `proc onLocalNotification(self, signal: LocalNotificationSignal)`.

- [ ] **Step 2: Implement suppression + show (mirror Android `StatusNotificationManager`).**
```nim
proc onLocalNotification(self: NotificationsManager, s: LocalNotificationSignal) =
  if s.deleted: return
  if s.category != "newMessage": return            # v1: messages only
  if s.isFromMe: return                             # own messages (paired desktop)
  if singletonInstance.engine.isAppInForeground():  # reuse the app's foreground flag; drop if visible
    return
  let title = if s.displayTitle.len > 0: s.displayTitle else: s.title
  let body  = if s.displayMessage.len > 0: s.displayMessage else: s.message
  self.showMobileOSNotification(title, body, s.id, s.conversationId)
```
(Use the project's actual foreground check; if none exists, gate on `not uiVisible`-equivalent or skip suppression for v1 and note it.)

- [ ] **Step 3: Add the iOS show emit.** Add a const + emit (mirroring `SIGNAL_DISPLAY_WINDOWS_OS_NOTIFICATION`):
```nim
const SIGNAL_DISPLAY_MOBILE_OS_NOTIFICATION* = "displayMobileOsNotification"

proc showMobileOSNotification(self: NotificationsManager, title, message, identifier, threadId: string) =
  self.events.emit(SIGNAL_DISPLAY_MOBILE_OS_NOTIFICATION,
    NotificationArgs(title: title, message: message, identifier: identifier,
                     details: NotificationDetails(chatId: threadId)))
```
(Reuse `NotificationArgs`; carry `threadId` in `details.chatId` or extend `NotificationArgs` with a `threadId*` field — pick one and keep it consistent with Step-4 QML reads.)

- [ ] **Step 4: QML sink → MobileUI.** In `ui/app/mainui/AppMain.qml`, add an iOS-gated handler for the emitted event that calls `PushNotifications.showNotification(title, message, identifier, threadId)`. Wire it the same way the app already routes Nim `events`/global signals into QML (follow an existing `SIGNAL_*` → QML consumer in this file). The `identifier` is the messageID (matches the push collapse-id); `threadId` is the conversationId.

- [ ] **Step 5: Lint.** Run `make qml-lint-mobile`; expected no new errors from `AppMain.qml`.

- [ ] **Step 6: Commit.**
```bash
git add src/app/core/notifications/notifications_manager.nim ui/app/mainui/AppMain.qml
git commit --no-gpg-sign -m "feat(ios/push): enrich banner from local-notifications signal (Layer 2 in-app)"
```

---

## Task 7: Integrated on-device test (device-bound)

**Why:** only a real device + APNS + the patched status-go proves the end-to-end replacement. **Runs on your machine.**

- [ ] **Step 1: Build** (clears were done earlier; ensure local MobileUI + patched status-go are picked up):
```bash
export PATH="$PWD/vendor/nimbus-build-system/vendor/Nim/bin:$PATH"
export QMAKE=<qt-6.9.2-ios>/bin/qmake IPHONE_SDK=iphoneos QMAKE_DEVELOPMENT_TEAM=<team>
make mobile-run -j10 V=3 USE_SYSTEM_NIM=1
```

- [ ] **Step 2: 1-1 enrichment.** Background the app; send a 1-1 from a peer (via `~/.status-pns/`). Confirm: anonymous banner → after sync, **replaced in place** with sender + message, **no second buzz** (per Task 1's verdict). Watch `~/.status-pns/pns-*.log` for the push and the device logs for `local-notifications` + `showNotification`.

- [ ] **Step 3: Suppression checks.** Send from a **paired desktop** (own message) → no notification (`isFromMe`). Delete a message → no stray notification (`deleted`). App in **foreground** → no banner.

- [ ] **Step 4: Privacy check.** Capture the APNS payload/headers (gorush log) and confirm `collapse_id` == `hex(messageID)` (a per-message value), not a per-conversation hash.

- [ ] **Step 5: Record results** in `docs/superpowers/research/2026-ios-push-enriched-banner-verification.md`; commit `--no-gpg-sign`.

---

## Self-Review notes

- **Spec coverage:** collapse-id=hex(messageID) → Task 2; LocalNotificationsConfig enable → Task 3; consume `local-notifications` signal (new SignalType) → Task 5; suppression rules (deleted/isFromMe/foreground) + iOS route to MobileUI → Task 6; `threadIdentifier` grouping → Task 4 + Task 6; the make-or-break replacement unknown → Task 1 (gate, first); privacy (per-message id) → Task 2 + verified Task 7 Step 4; testing → Tasks 2 (unit), 7 (device).
- **Placeholder scan:** the latitude points are flagged explicitly (the foreground-flag check in Task 6 Step 2; the exact node-config site in Task 3 Step 1; the QML event-routing idiom in Task 6 Step 4) — each cites the existing pattern to follow rather than inventing API.
- **Type/name consistency:** `CollapseID`/`collapse_id` (Task 2), `LocalNotificationSignal` + fields (Task 5) consumed in Task 6, `showNotification(title, message, identifier, threadIdentifier)` (Task 4) called from QML (Task 6 Step 4), `identifier == messageID == signal.id`, `threadIdentifier == conversationId` — consistent throughout.
