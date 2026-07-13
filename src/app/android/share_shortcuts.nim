## Android direct-share shortcuts, Nim side. Publishing is driven from QML
## (the shortcut publisher consumes the recent-postable-destinations model and
## calls SystemUtils.publishShareShortcuts); this binding covers the logout
## path, where the shortcuts must be cleared unconditionally — chat names and
## avatars live on OS surfaces outside the app and must not linger for a
## logged-out profile.

when defined(android):
  {.push dynlib: "", importc.}
  proc statusq_clearShareShortcuts*() {.cdecl, importc: "statusq_clearShareShortcuts".}
  {.pop.}

  proc clearShareShortcuts*() =
    statusq_clearShareShortcuts()

else:
  # Stub for non-Android builds (direct-share shortcuts are Android-only)
  proc clearShareShortcuts*() = discard
