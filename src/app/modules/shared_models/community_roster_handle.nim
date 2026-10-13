import nimqml

import community_roster_holders

QtObject:
  ## Holding one keeps the community roster loaded: creating it acquires,
  ## destroying it releases.
  type CommunityRosterHandle* = ref object of QObject
    holders: RosterHolders
    model: QVariant

  proc delete*(self: CommunityRosterHandle)
  proc newCommunityRosterHandle*(holders: RosterHolders, model: QVariant): CommunityRosterHandle =
    new(result, delete)
    result.QObject.setup
    result.holders = holders
    result.model = model
    holders.acquire()

  proc getModel(self: CommunityRosterHandle): QVariant {.slot.} =
    self.model

  QtProperty[QVariant] model:
    read = getModel

  proc delete*(self: CommunityRosterHandle) =
    if not self.holders.isNil:
      self.holders.release()
      self.holders = nil
    self.QObject.delete
