import nimqml
import json
import io_interface
import ../wallet_section/activity/controller as activity_controller

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      activityController: activity_controller.Controller

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface,
                activityController: activity_controller.Controller): View =
    new(result, delete)
    result.delegate = delegate
    result.activityController = activityController
    result.setup()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc openUrl*(self: View, url: string) {.signal.}
  proc sendOpenUrlSignal*(self: View, url: string) =
    self.openUrl(url)

  proc getActivityController*(self: View): QVariant {.slot.} =
    return newQVariant(self.activityController)

  QtProperty[QVariant] activityController:
    read = getActivityController

  proc purgePreferenceCategory(self: View, category: string, validKeysJson: string) {.slot.} =
    var validKeys: seq[string] = @[]
    if validKeysJson.len > 0:
      try:
        let parsed = parseJson(validKeysJson)
        if parsed.kind == JArray:
          for keyNode in parsed.items:
            let prefKey = keyNode.getStr()
            if prefKey.len > 0:
              validKeys.add(prefKey)
      except CatchableError:
        discard
    self.delegate.purgePreferenceCategory(category, validKeys)

  proc putPreference(self: View, category: string, prefKey: string, value: string) {.slot.} =
    self.delegate.putPreference(category, prefKey, value)

  proc getPreference(self: View, category: string, prefKey: string): string {.slot.} =
    self.delegate.getPreference(category, prefKey)

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

