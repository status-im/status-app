import json, std/strformat, chronicles, tables
include ../../../common/json_utils

type 
  UrlUnfurlingPermission* {.pure.} = enum
    UrlUnfurlingAllowed = 0
    UrlUnfurlingAskUser
    UrlUnfurlingForbiddenBySettings
    UrlUnfurlingNotSupported

  UrlUnfurlingMetadata* = ref object
    url*: string
    permission*: UrlUnfurlingPermission
    isStatusSharedUrl*: bool

  UrlsUnfurlingPlan* = ref object
    urls*: seq[UrlUnfurlingMetadata]

proc initUrlsUnfurlingPlan*(): UrlsUnfurlingPlan =
  result = UrlsUnfurlingPlan()
  result.urls = newSeq[UrlUnfurlingMetadata]()

proc toUrlUnfurlingPermission*(value: int): UrlUnfurlingPermission =
  try:
    return UrlUnfurlingPermission(value)
  except RangeDefect:
    return UrlUnfurlingPermission.UrlUnfurlingForbiddenBySettings

proc toUrlUnfurlingMetadata*(jsonObj: JsonNode): UrlUnfurlingMetadata =
  result = UrlUnfurlingMetadata()

  if jsonObj.kind != JObject:
    warn "node is not an object", source = "toUrlUnfurlingMetadata"
    return

  result.url = jsonObj{"url"}.getStr()
  result.permission = toUrlUnfurlingPermission(jsonObj{"permission"}.getInt)
  result.isStatusSharedUrl = jsonObj{"isStatusSharedURL"}.getBool()

proc toUrlUnfurlingPlan*(jsonObj: JsonNode): UrlsUnfurlingPlan =
  result = UrlsUnfurlingPlan()
  
  if jsonObj.kind != JObject:
    warn "node is not an object", source = "toUrlUnfurlingPlan"
    return

  let urlsSeq = jsonObj["urls"]

  if urlsSeq.kind != JArray:
    warn "urls is not an array", source = "toUrlUnfurlingPlan"
    return

  for metadata in urlsSeq:
    result.urls.add(toUrlUnfurlingMetadata(metadata))

proc `$`*(self: UrlUnfurlingMetadata): string =
  if self == nil:
    return "nil"
  return fmt"""UrlUnfurlingMetadata( permission: {self.permission}, isStatusSharedUrl: {self.isStatusSharedUrl} )"""

proc `$`*(self: UrlsUnfurlingPlan): string =
  if self == nil:
    return ""

  var rows = ""
  for url, metadata in self.urls:
    rows = fmt"""{rows}
    url: {url}, metadata: {metadata}"""

  result = fmt"""UrlsUnfurlingPlan({rows}
  )""" 
