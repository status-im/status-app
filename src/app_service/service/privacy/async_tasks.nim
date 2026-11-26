import ../../../backend/privacy as status_privacy

type
  ChangeDatabasePasswordTaskArg = ref object of QObjectTaskArg
    accountId: string
    currentPassword: string
    newPassword: string
    rekey: bool

proc changeDatabasePasswordTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ChangeDatabasePasswordTaskArg](argEncoded)
  let output = %* {
    "error": "",
    "result": ""
  }

  try:
    let result = status_privacy.changeDatabasePassword(arg.accountId, arg.currentPassword, arg.newPassword, arg.rekey)
    output["result"] = %result.result
  except Exception as e:
    output["error"] = %e.msg

  arg.finish(output)

type
  SetZeroOnboardedProfilePasswordTaskArg = ref object of QObjectTaskArg
    keyUid: string
    newPassword: string

proc setZeroOnboardedProfilePasswordTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[SetZeroOnboardedProfilePasswordTaskArg](argEncoded)
  let output = %* {
    "error": "",
    "result": ""
  }

  try:
    let result = status_privacy.setZeroOnboardedProfilePassword(arg.keyUid, arg.newPassword)
    output["result"] = %result.result
  except Exception as e:
    output["error"] = %e.msg

  arg.finish(output)
