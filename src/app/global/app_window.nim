## Helpers for managing the main application window via a QQmlApplicationEngine.
## Ported from DOtherSide dos_app_is_active / dos_app_make_it_active.

import nimqml
import seaqt/QtCore/gen_qobject
import seaqt/QtGui/gen_qwindow
import seaqt/QtQuick/gen_qquickwindow
from seaqt/QtQml/gen_qqmlapplicationengine import rootObjects

proc app_isActive*(engine: QQmlApplicationEngine): bool =
  ## Returns true when the main QQuickWindow is the active (focused) window.
  let rootObjs = engine.seaqt.rootObjects()
  if rootObjs.len == 0:
    return false
  let topObj = rootObjs[0]
  if topObj.objectName() == "mainWindow" and topObj.inherits("QQuickWindow"):
    let win = gen_qquickwindow_types.QQuickWindow(h: topObj.h, owned: false)
    return win.isActive()
  return false

proc app_makeItActive*(engine: QQmlApplicationEngine) =
  ## Brings the main QQuickWindow to the front and requests focus.
  let rootObjs = engine.seaqt.rootObjects()
  if rootObjs.len == 0:
    return
  let topObj = rootObjs[0]
  if topObj.objectName() == "mainWindow" and topObj.inherits("QQuickWindow"):
    let win = gen_qquickwindow_types.QQuickWindow(h: topObj.h, owned: false)
    win.show()
    win.raiseX()
    win.requestActivate()
