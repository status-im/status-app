import nimqml
import io_interface, model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      exemptionsLoaded: bool
      exemptionsModel: Model
      exemptionsModelVariant: QVariant
      
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.exemptionsLoaded = false
    result.exemptionsModel = newModel()
    result.exemptionsModelVariant = newQVariant(result.exemptionsModel)
    
  proc load*(self: View) =
    self.delegate.viewDidLoad()
    
  proc loadExemptions*(self: View) {.slot.} =
    if self.exemptionsLoaded:
      return
    self.delegate.initModel()
    self.exemptionsLoaded = true

  proc sendTestNotification*(self: View, title: string, message: string) {.slot.} =
    self.delegate.sendTestNotification(title, message)

  proc exemptionsModel*(self: View): Model =
    return self.exemptionsModel

  proc getExemptionsModel(self: View): QVariant {.slot.} =
    return self.exemptionsModelVariant
  QtProperty[QVariant] exemptionsModel:
    read = getExemptionsModel

  proc saveExemptions*(self: View, itemId: string, muteAllMessages: bool, personalMentions: string, 
    globalMentions: string, otherMessages: string) {.slot.} =
    self.delegate.saveExemptions(itemId, muteAllMessages, personalMentions, globalMentions, otherMessages)

  proc delete*(self: View) =
    self.QObject.delete

