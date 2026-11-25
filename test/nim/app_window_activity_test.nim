## The notification manager treats the app as in use only when it is active and its main window is shown.

import unittest
import app/global/app_window_activity

const
  Hidden = 0
  AutomaticVisibility = 1
  Windowed = 2
  Minimized = 3
  Maximized = 4
  FullScreen = 5

suite "isInUse":
  test "active with a shown window is in use":
    for visibility in [AutomaticVisibility, Windowed, Maximized, FullScreen]:
      check isInUse(true, visibility)

  test "active with a hidden window is not in use":
    check not isInUse(true, Hidden)

  test "active with a minimized window is not in use":
    check not isInUse(true, Minimized)

  test "inactive is never in use":
    for visibility in [Hidden, AutomaticVisibility, Windowed, Minimized, Maximized, FullScreen]:
      check not isInUse(false, visibility)
