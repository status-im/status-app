import nimqml

# The section's view state that outlives its UI: the portrait panel shown
QtObject:
  type
    ViewState* = ref object of QObject
      shownPanel: int

  proc setup(self: ViewState)
  proc delete*(self: ViewState)
  proc newViewState*(): ViewState =
    new(result, delete)
    result.setup

  proc shownPanelChanged*(self: ViewState) {.signal.}
  proc setShownPanel*(self: ViewState, value: int) {.slot.} =
    if self.shownPanel == value:
      return
    self.shownPanel = value
    self.shownPanelChanged()
  proc getShownPanel*(self: ViewState): int {.slot.} =
    result = self.shownPanel
  QtProperty[int] shownPanel:
    read = getShownPanel
    write = setShownPanel
    notify = shownPanelChanged

  proc setup(self: ViewState) =
    self.QObject.setup

  proc delete*(self: ViewState) =
    self.QObject.delete
