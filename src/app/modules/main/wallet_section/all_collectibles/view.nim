import nimqml, sequtils, strutils, chronicles, tables

import ./io_interface

import app/modules/shared_models/collectibles_model as collectibles_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      allCollectiblesModel: collectibles_model.Model
      # QVariants wrapping the created picker models, keyed by the id handed to
      # QML so a released model's QVariant can be dropped (freeing the model).
      selectorModelVariants: Table[int, QVariant]
      lastCreatedSelectorModelId: int

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.allCollectiblesModel = delegate.getAllCollectiblesModel()
    result.selectorModelVariants = initTable[int, QVariant]()
    result.lastCreatedSelectorModelId = -1

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc getAllCollectiblesModel(self: View): QVariant {.slot.} =
    return newQVariant(self.allCollectiblesModel)
  QtProperty[QVariant] allCollectiblesModel:
    read = getAllCollectiblesModel

  # Picker factory for the send modal. No-arg QVariant slot (nimqml allows a
  # QVariant return only when the slot takes no args), paired with an id property
  # the caller passes back to releaseCollectiblesSelectorModel on teardown.
  proc createCollectiblesSelectorModel*(self: View): QVariant {.slot.} =
    let (id, model) = self.delegate.createCollectiblesSelectorModel()
    let variant = newQVariant(model)
    self.selectorModelVariants[id] = variant
    self.lastCreatedSelectorModelId = id
    return variant

  proc getLastCreatedSelectorModelId(self: View): int {.slot.} =
    self.lastCreatedSelectorModelId
  QtProperty[int] lastCreatedSelectorModelId:
    read = getLastCreatedSelectorModelId

  proc releaseCollectiblesSelectorModel*(self: View, id: int) {.slot.} =
    self.delegate.releaseCollectiblesSelectorModel(id)
    if self.selectorModelVariants.hasKey(id):
      self.selectorModelVariants[id].delete
      self.selectorModelVariants.del(id)

  # Connected to the collectibles model's countChanged/itemsDataUpdated so live
  # picker models re-derive when the universe changes.
  proc onCollectiblesUniverseChanged*(self: View) {.slot.} =
    self.delegate.refreshCollectiblesSelectorModels()

  proc collectiblePreferencesUpdated*(self: View, result: bool) {.signal.}

  proc updateCollectiblePreferences*(self: View, collectiblePreferencesJson: string) {.slot.} =
    self.delegate.updateCollectiblePreferences(collectiblePreferencesJson)

  proc getCollectiblePreferencesJson(self: View): QVariant {.slot.} =
    let preferences = self.delegate.getCollectiblePreferencesJson()
    return newQVariant(preferences)

  QtProperty[QVariant] collectiblePreferencesJson:
    read = getCollectiblePreferencesJson

  proc collectibleGroupByCommunityChanged*(self: View) {.signal.}

  proc getCollectibleGroupByCommunity(self: View): bool {.slot.} =
    return self.delegate.getCollectibleGroupByCommunity()

  QtProperty[bool] collectibleGroupByCommunity:
    read = getCollectibleGroupByCommunity
    notify = collectibleGroupByCommunityChanged

  proc toggleCollectibleGroupByCommunity*(self: View): bool {.slot.} =
    if not self.delegate.toggleCollectibleGroupByCommunity():
      error "Failed to toggle collectibleGroupByCommunity"
      return
    self.collectibleGroupByCommunityChanged()

  proc collectibleGroupByCollectionChanged*(self: View) {.signal.}

  proc getCollectibleGroupByCollection(self: View): bool {.slot.} =
    return self.delegate.getCollectibleGroupByCollection()

  QtProperty[bool] collectibleGroupByCollection:
    read = getCollectibleGroupByCollection
    notify = collectibleGroupByCollectionChanged

  proc toggleCollectibleGroupByCollection*(self: View): bool {.slot.} =
    if not self.delegate.toggleCollectibleGroupByCollection():
      error "Failed to toggle collectibleGroupByCollection"
      return
    self.collectibleGroupByCollectionChanged()

  proc delete*(self: View) =
    for v in self.selectorModelVariants.values:
      v.delete
    self.QObject.delete

