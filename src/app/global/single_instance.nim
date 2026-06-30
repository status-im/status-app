## Single-instance IPC
##
## The first instance listens on a QLocalServer named after `uniqueName`; a later
## ("second") instance connects and forwards `eventStr` (a deep-link URL) to the
## first, which re-emits it via the `eventReceived` signal

import nimqml
import chronicles
from seaqt/QtNetwork/gen_qlocalserver import QLocalServer,
  QLocalServernewConnectionSlot, create, onNewConnection, close, isListening,
  listen, nextPendingConnection, removeServer
from seaqt/QtNetwork/gen_qlocalsocket import QLocalSocket, create,
  connectToServer, waitForConnected, waitForBytesWritten, waitForReadyRead,
  canReadLine, close
from seaqt/QtCore/gen_qiodevice import write, readLine

const
  ReadWriteTimeoutMs = 1000      # ad-hoc value
  ConnectProbeTimeoutMs = 100    # ad-hoc value

QtObject:
  type SingleInstance* = ref object of QObject
    localServer: QLocalServer

  proc eventReceived*(self: SingleInstance, eventStr: string) {.signal.}
  proc secondInstanceDetected*(self: SingleInstance) {.signal.}

  proc handleNewConnection(self: SingleInstance) =
    self.secondInstanceDetected()
    let sock = self.localServer.nextPendingConnection()
    if sock.waitForReadyRead(ReadWriteTimeoutMs) and sock.canReadLine():
      let raw = sock.readLine()
      var line = newStringOfCap(raw.len)
      for b in raw: line.add(char(b))
      self.eventReceived(line)
    sock.close()

  proc newSingleInstance*(uniqueName, eventStr: string): SingleInstance =
    new(result)
    result.QObject.setup
    result.localServer = QLocalServer.create()
    let socketName = when defined(windows): uniqueName else: "/tmp/" & uniqueName

    var probe = QLocalSocket.create()
    probe.connectToServer(socketName)
    if not probe.waitForConnected(ConnectProbeTimeoutMs):
      # No server answered -> we are the first instance.
      let self = result  # capture a non-`result` ref for the closure
      result.localServer.onNewConnection(proc() = self.handleNewConnection())
      # On *nix a crashed run leaves a stale socket file that blocks listen(); clear it
      # (no-op on Windows).
      discard QLocalServer.removeServer(socketName)
      if not result.localServer.listen(socketName):
        warn "SingleInstance: QLocalServer.listen failed", socketName
    elif eventStr.len > 0:
      # A server answered -> we are a second instance; forward the event.
      let payload = eventStr & "\n"
      discard probe.write(payload.cstring)
      discard probe.waitForBytesWritten(ReadWriteTimeoutMs)

  proc delete*(self: SingleInstance) =
    if not self.localServer.h.isNil and self.localServer.isListening():
      self.localServer.close()
    reset(self.localServer)
    self.QObject.delete

  proc secondInstance*(self: SingleInstance): bool =
    ## True when another instance already owns the socket (we are not listening).
    not self.localServer.isListening()
