import nimqml
import section_item

QtObject:
  type SectionDetails* = ref object of QObject
    id: string
    sectionType: SectionType
    joined: bool

  proc setup(self: SectionDetails)
  proc delete*(self: SectionDetails)
  proc newActiveSection*(): SectionDetails =
    new(result, delete)
    result.setup

  proc idChanged*(self: SectionDetails) {.signal.}
  proc getId*(self: SectionDetails): string {.slot.} =
    return self.id

  QtProperty[string] id:
    read = getId
    notify = idChanged

  proc sectionTypeChanged*(self: SectionDetails) {.signal.}
  proc getSectionType(self: SectionDetails): int {.slot.} =
    return self.sectionType.int

  QtProperty[int] sectionType:
    read = getSectionType
    notify = sectionTypeChanged

  proc joinedChanged*(self: SectionDetails) {.signal.}
  proc getJoined(self: SectionDetails): bool {.slot.} =
    return self.joined

  QtProperty[bool] joined:
    read = getJoined
    notify = joinedChanged

  proc setActiveSectionData*(self: SectionDetails, item: SectionItem) =
    var idChanged = false
    var joinedChanged = false
    var sectionTypeChanged = false

    if self.id != item.id:
      self.id = item.id
      idChanged = true

    if self.joined != item.joined:
      self.joined = item.joined
      joinedChanged = true

    if self.sectionType != item.sectionType:
      self.sectionType = item.sectionType
      sectionTypeChanged = true

    if idChanged:
      self.idChanged()
    if joinedChanged:
      self.joinedChanged()
    if sectionTypeChanged:
      self.sectionTypeChanged()

  proc setup(self: SectionDetails) =
    self.QObject.setup
    self.sectionType = SectionType.LoadingSection

  proc delete*(self: SectionDetails) =
    self.QObject.delete

