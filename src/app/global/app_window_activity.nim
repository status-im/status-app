## Whether the user is looking at the app, from the application state and the main window visibility.

const
  WindowHidden = 0 # QWindow::Hidden
  WindowMinimized = 3 # QWindow::Minimized

proc isInUse*(appActive: bool, mainWindowVisibility: int): bool =
  ## On macOS the app stays active with its window hidden in the tray or minimized.
  appActive and mainWindowVisibility != WindowHidden and mainWindowVisibility != WindowMinimized
