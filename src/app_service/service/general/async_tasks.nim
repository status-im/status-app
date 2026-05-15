
type
  AsyncImportLocalBackupFileTaskArg = ref object of QObjectTaskArg
    filePath: string

proc asyncImportLocalBackupFileTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncImportLocalBackupFileTaskArg](argEncoded)
  try:
    let response = status_go.loadLocalBackup($(%* {"filePath": arg.filePath}))
    arg.finish(%* {
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

type
  AsyncStartMessengerTaskArg = ref object of QObjectTaskArg
    discard

proc asyncStartMessengerTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncStartMessengerTaskArg](argEncoded)
  try:
    let response = status_general.startMessenger()
    var trimmed = newJObject()
    if not response.result.isNil and response.result.kind == JObject and
        response.result.hasKey("activityCenterNotifications"):
      trimmed["activityCenterNotifications"] = response.result["activityCenterNotifications"]
    arg.finish(%* {
      "response": trimmed,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })
