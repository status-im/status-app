## What QML may use of the app sessions. SessionHost itself stays out of QML: its slots
## are backend delivery entry points.

import nimqml, chronicles

import app/boot/session_lifecycle
import app/global/global_singleton

logScope:
  topics = "session-view"

QtObject:
  type SessionView* = ref object of QObject
    autoLoginPolicy: proc(): AutoLoginPolicy

  proc delete*(self: SessionView)

  proc newSessionView*(autoLoginPolicy: proc(): AutoLoginPolicy): SessionView =
    new(result, delete)
    result.QObject.setup
    result.autoLoginPolicy = autoLoginPolicy

  proc delete*(self: SessionView) =
    self.QObject.delete

  proc allowsAutoLogin*(self: SessionView, keyUid: string): bool {.slot.} =
    ## Whether the login screen may attempt a silent login for `keyUid`: decided by the
    ## policy the current session started with and the persisted rules.
    let blockedBy = autoLoginBlockedBy(self.autoLoginPolicy(),
      singletonInstance.localAppSettings.getTestEnvironment(),
      singletonInstance.localAppSettings.isAutoLoginSuppressed(keyUid))
    if blockedBy.len > 0:
      info "auto-login disabled", reason = blockedBy
    blockedBy.len == 0
