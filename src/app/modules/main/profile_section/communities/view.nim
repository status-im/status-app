import nimqml

import ./io_interface


QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc leaveCommunity*(self: View, communityID: string) {.slot.} =
    self.delegate.leaveCommunity(communityID)

  proc setCommunityMuted*(self: View, communityID: string, mutedType: int) {.slot.} =
    self.delegate.setCommunityMuted(communityID, mutedType)

  proc delete*(self: View) =
    self.QObject.delete

