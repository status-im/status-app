type
  ExportKeypairState* = ref object of State

proc newExportKeypairState*(backState: State): ExportKeypairState =
  result = ExportKeypairState()
  result.setup(StateType.ExportKeypair, backState)

proc delete*(self: ExportKeypairState) =
  self.State.delete

method executePrePrimaryStateCommand*(self: ExportKeypairState, controller: Controller) =
  controller.closeKeypairImportPopup()

method executePreSecondaryStateCommand*(self: ExportKeypairState, controller: Controller) =
  controller.authenticateLoggedInUser()