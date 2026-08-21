import nimqml
import io_interface, model

type
  BackupImportState* {.pure.} = enum
    None,
    InProgress,
    Completed,

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: Model
      backupImportState: BackupImportState
      backupDataState: BackupImportState
      backupImportError: string
      backupDataError: string

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.model = newModel()
    result.backupImportState = BackupImportState.None
    result.backupDataState = BackupImportState.None
    result.backupImportError = ""
    result.backupDataError = ""

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc model*(self: View): Model =
    return self.model

  proc modelChanged*(self: View) {.signal.}
  proc getModel(self: View): QAbstractListModel {.slot.} =
    return self.model

  QtProperty[QAbstractListModel] model:
    read = getModel
    notify = modelChanged

  proc useMailserversChanged*(self: View) {.signal.}

  proc getUseMailservers*(self: View): bool {.slot.} =
    return self.delegate.getUseMailservers()

  proc setUseMailservers*(self: View, value: bool) {.slot.} =
    if value == self.delegate.getUseMailservers():
      return
    self.delegate.setUseMailservers(value)

  QtProperty[bool] useMailservers:
    read = getUseMailservers
    notify = useMailserversChanged
    write = setUseMailservers

  proc backupImportStateChanged*(self: View) {.signal.}

  proc getBackupImportState*(self: View): int {.slot.} =
    return self.backupImportState.int

  proc setBackupImportState*(self: View, state: BackupImportState) = # not a slot
    if state == self.backupImportState:
      return
    self.backupImportState = state
    self.backupImportStateChanged()

  QtProperty[int] backupImportState:
    read = getBackupImportState
    notify = backupImportStateChanged

  proc backupDataStateChanged*(self: View) {.signal.}

  proc getBackupDataState*(self: View): int {.slot.} =
    return self.backupDataState.int

  proc setBackupDataState*(self: View, state: BackupImportState) = # not a slot
    if state == self.backupDataState:
      return
    self.backupDataState = state
    self.backupDataStateChanged()

  QtProperty[int] backupDataState:
    read = getBackupDataState
    notify = backupDataStateChanged

  proc backupImportErrorChanged*(self: View) {.signal.}

  proc getBackupImportError*(self: View): string {.slot.} =
    return self.backupImportError

  proc setBackupImportError*(self: View, error: string) = # not a slot
    if error == self.backupImportError:
      return
    self.backupImportError = error
    self.backupImportErrorChanged()

  QtProperty[string] backupImportError:
    read = getBackupImportError
    notify = backupImportErrorChanged

  proc backupDataErrorChanged*(self: View) {.signal.}

  proc getBackupDataError*(self: View): string {.slot.} =
    return self.backupDataError

  proc setBackupDataError*(self: View, error: string) = # not a slot
    if error == self.backupDataError:
      return
    self.backupDataError = error
    self.backupDataErrorChanged()

  QtProperty[string] backupDataError:
    read = getBackupDataError
    notify = backupDataErrorChanged

  proc localBackupExportCompleted*(self: View, success: bool) {.signal.}
  proc localBackupImportCompleted*(self: View, success: bool) {.signal.}

  proc onLocalBackupImportCompleted*(self: View, error: string) = # not a slot
    self.setBackupImportState(BackupImportState.Completed)
    self.setBackupImportError(error)
    self.localBackupImportCompleted(error.len == 0)

  proc performLocalBackup*(self: View) {.slot.} =
    self.setBackupDataState(BackupImportState.InProgress)
    self.setBackupDataError("")

    self.delegate.performLocalBackup()

  proc onBackupCompleted*(self: View, error: string) = # not a slot
    self.setBackupDataState(BackupImportState.Completed)
    self.setBackupDataError(error)
    self.localBackupExportCompleted(error.len == 0)

  proc resetBackupDataState*(self: View): int {.slot.} =
    self.setBackupDataState(BackupImportState.None)
    self.setBackupDataError("")

  proc importLocalBackupFile*(self: View, filePath: string) {.slot.} =
    self.setBackupImportState(BackupImportState.InProgress)
    self.setBackupImportError("")
    self.delegate.importLocalBackupFile(filePath)

  proc delete*(self: View) =
    self.QObject.delete

