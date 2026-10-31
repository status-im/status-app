import unittest
import nimqml
from seaqt/qcoreapplication import QCoreApplication, create

import app/modules/main/browser_section/view as browser_view
from app/modules/main/browser_section/io_interface import AccessInterface

type MockDelegate = ref object of AccessInterface

method viewDidLoad*(self: MockDelegate) =
  discard

QtObject:
  type UrlCapture = ref object of QObject
    urls: seq[string]

  proc delete(self: UrlCapture)

  proc newUrlCapture(): UrlCapture =
    new(result, delete)
    result.QObject.setup

  proc delete(self: UrlCapture) =
    self.QObject.delete

  proc onOpenUrl*(self: UrlCapture, url: string) {.slot.} =
    self.urls.add url

discard QCoreApplication.create()

suite "browser section view openUrl signal":
  test "sendOpenUrlSignal emits openUrl with the url":
    let delegate = MockDelegate()
    let view = browser_view.newView(delegate, nil)
    let capture = newUrlCapture()
    discard QObject.connect(view, openUrl, capture, onOpenUrl)

    view.sendOpenUrlSignal("https://example.com/dapp")

    check capture.urls == @["https://example.com/dapp"]

    capture.delete()
    view.delete()
