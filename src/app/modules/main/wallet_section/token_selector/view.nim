import nimqml, tables

import ./io_interface
import app/modules/shared_models/token_selector_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      # QVariants wrapping the created models, keyed by the id handed to QML so a
      # released model's QVariant can be dropped (freeing the model).
      modelVariants: Table[int, QVariant]
      tmpKind: int
      lastPreparedId: int

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.setup()
    result.delegate = delegate
    result.modelVariants = initTable[int, QVariant]()
    result.lastPreparedId = -1

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  # Factory: QML asks for a picker model of a given kind (0=send/owned,
  # 1=swap/all-tokens+search, 2=buy/all-tokens). nimqml cannot return a QVariant
  # from a slot that takes arguments, so this is the prepare-then-get pair (as in
  # main/view.nim getCommunitySectionModule). A QML store wraps the two calls.
  proc prepareModel*(self: View, kind: int) {.slot.} =
    self.tmpKind = kind

  proc getPreparedModel*(self: View): QVariant {.slot.} =
    let (id, model) = self.delegate.createModelForKind(self.tmpKind)
    let variant = newQVariant(model)
    self.modelVariants[id] = variant
    self.lastPreparedId = id
    return variant

  # The id of the model returned by the most recent getPreparedModel, so QML can
  # hand it back to releaseModel when the owning modal is destroyed.
  proc getLastPreparedModelId*(self: View): int {.slot.} =
    self.lastPreparedId
  QtProperty[int] lastPreparedModelId:
    read = getLastPreparedModelId

  proc releaseModel*(self: View, id: int) {.slot.} =
    self.delegate.releaseModel(id)
    if self.modelVariants.hasKey(id):
      self.modelVariants[id].delete
      self.modelVariants.del(id)

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    for v in self.modelVariants.values:
      v.delete
    self.QObject.delete

  when defined(testing) or defined(QT_MODEL_SPY):
    proc trackedModelIdsForTest*(self: View): seq[int] =
      for id in self.modelVariants.keys: result.add(id)
