import nimqml, sequtils, sets, strutils
import ../../../../shared_models/[member_model]
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: Model

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.model = newModel()

  proc model*(self: View): Model =
    return self.model

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc modelChanged*(self: View) {.signal.}

  proc getModel*(self: View): QAbstractListModel {.slot.} =
    return self.model

  QtProperty[QAbstractListModel] model:
    read = getModel
    notify = modelChanged

  proc groupMembersUpdateRequested*(self: View, membersPubKeysList: string) {.slot.} =
    # Parse the incoming hash into a set of pubKeys
    var newIDs: HashSet[string]
    if membersPubKeysList.len > 0:
      newIDs = membersPubKeysList.split(",").toHashSet
    else:
      newIDs = initHashSet[string]()

    let currentIDs = self.model.getItemIds().toHashSet

    # Update current users model with new members:
    let membersAdded = toSeq(newIDs - currentIDs)
    let membersRemoved = toSeq(currentIDs - newIDs)

    if membersAdded.len > 0:
      self.delegate.addGroupMembers(membersAdded)

    if membersRemoved.len > 0:
      self.delegate.removeGroupMembers(membersRemoved)

  proc delete*(self: View) =
    self.QObject.delete

