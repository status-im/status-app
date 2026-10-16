## The app's QML imports NimQtCamera and NimQrScan. Their install() adds import
## paths inside the build checkout, which don't exist where the app is
## installed, so both modules must also be in resources.rcc, found through the
## app's "qrc:/" import path. Run from the repo root after `make rcc`.

import std/[os, unittest]
import nimqml
import seaqt/QtQml/gen_qqmlapplicationengine

putEnv("QT_QPA_PLATFORM", "offscreen")

suite "Nim library QML modules in resources.rcc":
  test "both modules load from resources only, without checkout paths":
    let app = newQGuiApplication()
    check fileExists("resources.rcc")
    QResource.registerResource("resources.rcc")
    let engine = newQQmlApplicationEngine()
    engine.addImportPath("qrc:/") # as nim_status_client.nim does; no checkout dirs
    engine.loadData("""
      import QtQuick
      import NimQtCamera 1.0
      import NimQrScan 1.0
      Item {}
    """)
    check engine.seaqt.rootObjects().len == 1
    engine.delete()
    app.delete()
