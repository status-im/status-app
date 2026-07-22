import json, chronicles
import ./core
import ./response_type
import ../app_service/common/utils

import status_go

export response_type

logScope:
  topics = "rpc-node-config"

proc getNodeConfig*(): RpcResponse[JsonNode] =
  try:
    let response = status_go.getNodeConfig()
    result.result = response.parseJSON()

  except RpcException as e:
    error "error doing rpc request", methodName = "getNodeConfig", exception=e.msg
    raise newException(RpcException, e.msg)


proc enableTorrentCommunityHistoryArchiveSupport*(): RpcResponse[JsonNode] =
  return core.callPrivateRPC("enableCommunityHistoryArchiveProtocol".prefix, %* [])

proc enableLogosStorageCommunityHistoryArchiveSupport*(): RpcResponse[JsonNode] =
  return core.callPrivateRPC("enableLogosStorageCommunityHistoryArchiveProtocol".prefix, %* [{}])

proc disableCommunityHistoryArchiveSupport*(): RpcResponse[JsonNode] =
  return core.callPrivateRPC("disableCommunityHistoryArchiveProtocol".prefix, %* [])

proc setLogLevel*(logLevel: LogLevel): RpcResponse[JsonNode] =
  let payload = %*[{
    "logLevel": $logLevel
  }]
  result = core.callPrivateRPC("setLogLevel".prefix, payload)

proc setMaxLogBackups*(maxLogBackups: int): RpcResponse[JsonNode] =
  let payload = %*[{
    "maxLogBackups": maxLogBackups
  }]
  return core.callPrivateRPC("setMaxLogBackups".prefix, payload)

proc setLightClient*(enabled: bool): RpcResponse[JsonNode] =
  let payload = %*[{
    "enabled": enabled
  }]
  return core.callPrivateRPC("setLightClient".prefix, payload)
