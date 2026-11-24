## Timers owned by an app session: their callbacks stop running session code once the
## session has ended, while the backend logs out (in-process logout).

import chronicles
from seaqt/qtimer import QTimer, onTimeout

import app/core/signal_handler

logScope:
  topics = "session-timer"

proc onSessionTimeout*(timer: QTimer, label: string, body: proc()) =
  ## Like `timer.onTimeout(body)`, for a timer of the current session: `body` is skipped
  ## once the session has ended, and what it raises is logged.
  let generation = currentSessionGeneration()
  timer.onTimeout(proc() {.closure, raises: [].} =
    if hasSessionEnded(generation):
      return
    try:
      body()
    except Exception as e:
      error "session timer callback failed", timer = label, msg = e.msg
  )
