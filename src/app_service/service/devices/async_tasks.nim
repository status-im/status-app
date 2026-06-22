include ../../common/json_utils
include ../../../app/core/tasks/common

type
  AsyncLoadDevicesTaskArg = ref object of QObjectTaskArg

type
  AsyncInputConnectionStringArg = ref object of QObjectTaskArg
    connectionString: string
    configJSON: JsonNode

proc asyncLoadDevicesTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncLoadDevicesTaskArg](argEncoded)
  try:
    let rpcResponse = status_installations.getOurInstallations()
    arg.finish(%* {
      "response": rpcResponse.result,
      "error": rpcResponse.error,
    })

  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

proc asyncInputConnectionStringTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncInputConnectionStringArg](argEncoded)
  try:
    let response = status_go.inputConnectionStringForBootstrapping(arg.connectionString, $arg.configJSON)
    arg.finish(response)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

proc asyncInputConnectionStringForImportingKeystoreTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncInputConnectionStringArg](argEncoded)
  try:
    let response = status_go.inputConnectionStringForImportingKeypairsKeystores(arg.connectionString, $arg.configJSON)
    arg.finish(response)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })