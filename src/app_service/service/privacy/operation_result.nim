import json

type OperationResult* = object
  success*: bool
  errorMsg*: string

# Reply of a privacy threadpool task: {"error": <task error>, "result": {"error": <backend error>}}
proc operationResult*(responseStr: string): OperationResult =
  try:
    let response = responseStr.parseJson
    let taskError = response{"error"}.getStr
    if taskError != "":
      return OperationResult(errorMsg: taskError)
    let res = response{"result"}
    if res.kind != JObject or not res.contains("error"):
      return OperationResult()
    let backendError = res["error"].getStr
    return OperationResult(success: backendError == "", errorMsg: backendError)
  except Exception as e:
    return OperationResult(errorMsg: e.msg)
