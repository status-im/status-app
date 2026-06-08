when defined(android):
  {.push dynlib: "", importc.}
  proc statusq_stopBackgroundService*() {.cdecl, importc: "statusq_stopBackgroundService".}
  {.pop.}

  proc stopBackgroundService*() =
    statusq_stopBackgroundService()

else:
  # Stub for non-Android builds (no separate status-go service process there)
  proc stopBackgroundService*() = discard
