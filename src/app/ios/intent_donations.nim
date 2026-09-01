## iOS send-message intent donations, Nim side. Donating is driven from QML
## (SendMessageIntentDonor consumes the recent-postable-destinations model and
## calls MobileUI.donateSendMessageInteraction after each successful send);
## this binding covers the logout path, where every donated interaction must
## be deleted unconditionally — donated chat names and avatars power the iOS
## share-sheet suggestion chips, OS surfaces outside the app, and must not
## linger for a logged-out profile. The iOS counterpart of
## app/android/share_shortcuts.nim.

when defined(ios):
  {.push dynlib: "", importc.}
  proc statusq_deleteDonatedInteractions*() {.cdecl, importc: "statusq_deleteDonatedInteractions".}
  {.pop.}

  proc deleteDonatedInteractions*() =
    statusq_deleteDonatedInteractions()

else:
  # Stub for non-iOS builds (intent donations are iOS-only)
  proc deleteDonatedInteractions*() = discard
