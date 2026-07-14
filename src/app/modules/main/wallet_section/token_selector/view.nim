import nimqml

import ./io_interface
import app/modules/shared_models/token_selector_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      # QVariants wrapping the created models, kept alive for QML's lifetime.
      modelVariants: seq[QVariant]
      tmpKind: int

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.setup()
    result.delegate = delegate

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  # Factory: QML asks for a picker model of a given kind (0=send/owned,
  # 1=swap/all-tokens+search, 2=buy/all-tokens). nimqml cannot return a QVariant
  # from a slot that takes arguments, so this is the prepare-then-get pair (as in
  # main/view.nim getCommunitySectionModule). A QML store wraps the two calls.
  proc prepareModel*(self: View, kind: int) {.slot.} =
    self.tmpKind = kind

  proc getPreparedModel*(self: View): QVariant {.slot.} =
    let model = self.delegate.createModelForKind(self.tmpKind)
    let variant = newQVariant(model)
    self.modelVariants.add(variant)
    return variant

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    for v in self.modelVariants:
      v.delete
    self.QObject.delete
