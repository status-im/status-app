type
  FetchHttpTrafficReportTaskArg = ref object of QObjectTaskArg
    endpoints: string
    key: string

proc fetchHttpTrafficReportTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchHttpTrafficReportTaskArg](argEncoded)
  let output = %* {
    "error": "",
    "report": "",
    "endpoints": arg.endpoints,
    "key": arg.key
  }
  try:
    output["report"] = %status_node.getHttpTrafficReport(arg.endpoints, arg.key)
  except Exception as e:
    output["error"] = %e.msg
  arg.finish(output)
