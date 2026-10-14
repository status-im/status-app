## Who keeps a community roster alive. The first holder loads it; at zero
## holders it is dropped after RosterIdleReleaseMs (Idle release), and at once
## when the app goes to the background. Holders are counted by handle objects
## (community_roster_handle), never by hand.

type
  RosterReleaseTimer* = object
    start*: proc(ms: int)
    stop*: proc()

  RosterHolders* = ref object
    count: int
    active: bool
    timer: RosterReleaseTimer
    onLoad: proc()
    onDrop: proc()

const RosterIdleReleaseMs* = 120_000

proc newRosterHolders*(timer: RosterReleaseTimer, onLoad: proc(), onDrop: proc()): RosterHolders =
  RosterHolders(timer: timer, onLoad: onLoad, onDrop: onDrop)

proc holderCount*(self: RosterHolders): int =
  self.count

proc isActive*(self: RosterHolders): bool =
  ## A load was requested and the roster has not been dropped since.
  self.active

proc load(self: RosterHolders) =
  self.active = true
  self.onLoad()

proc drop(self: RosterHolders) =
  self.active = false
  self.onDrop()

proc acquire*(self: RosterHolders) =
  inc self.count
  if self.count > 1:
    return
  self.timer.stop()
  if not self.active:
    self.load()

proc release*(self: RosterHolders) =
  if self.count == 0:
    return
  dec self.count
  if self.count == 0 and self.active:
    self.timer.start(RosterIdleReleaseMs)

proc onReleaseTimeout*(self: RosterHolders) =
  if self.count == 0 and self.active:
    self.drop()

proc onBackgrounded*(self: RosterHolders) =
  if not self.active:
    return
  self.timer.stop()
  self.drop()

proc onForegrounded*(self: RosterHolders) =
  if self.count > 0 and not self.active:
    self.load()

proc onLoadFailed*(self: RosterHolders) =
  self.active = false
