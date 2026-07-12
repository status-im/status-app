import nimqml

import ./io_interface
import app/modules/shared_models/assets_adaptor_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      assetsModel: AssetsAdaptorModel

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.setup()
    result.delegate = delegate
    result.assetsModel = newAssetsAdaptorModel()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc assetsModelChanged(self: View) {.signal.}
  proc getAssetsModel*(self: View): QVariant {.slot.} =
    return newQVariant(self.assetsModel)
  QtProperty[QVariant] assetsModel:
    read = getAssetsModel
    notify = assetsModelChanged

  proc setSourceItems*(self: View, items: seq[AssetItem]) =
    self.assetsModel.setSourceItems(items)

  # Called from QML: the sorter combo box emits a sort intent, wired through the
  # store to re-sort the terminal model in place (no proxy above it).
  proc sortBy*(self: View, roleName: string, order: int) {.slot.} =
    self.assetsModel.sortBy(roleName, order)

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.assetsModel.delete
    self.QObject.delete
