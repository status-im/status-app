## URL-scheme / deep-link event object, backed by StatusQ's relocated Status::UrlSchemeEvent
## (macOS QFileOpenEvent event-filter, iOS QDesktopServices handler, Android JNI). Converts OS deep
## links into the C++ urlActivated(QString) signal that UrlsManager connects to.
## Replaces the dos_event_*-backed StatusEvent that lived in dotherside_ext.

import nimqml
import statusq_bridge

type UrlSchemeEvent* = ref object of QObject

proc delete*(self: UrlSchemeEvent)

proc newUrlSchemeEvent*(): UrlSchemeEvent =
  new(result, delete)
  result.vptr = statusq_urlscheme_create()

proc delete*(self: UrlSchemeEvent) =
  statusq_urlscheme_delete(self.vptr)
  self.vptr = nil

proc setInstance*(self: UrlSchemeEvent) =
  statusq_urlscheme_set_instance(self.vptr)

proc installEventFilter*(application: QGuiApplication, event: UrlSchemeEvent) =
  statusq_urlscheme_install_event_filter(event.vptr)
