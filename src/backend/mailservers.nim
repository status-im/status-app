import json, chronicles
import core, ../app_service/common/utils
import response_type

export response_type

logScope:
  topics = "mailserver"

proc toggleUseMailservers*(value: bool): RpcResponse[JsonNode] =
  result = core.callPrivateRPC("toggleUseMailservers".prefix, %*[ value ])

proc syncChatFromSyncedFrom*(chatId: string): RpcResponse[JsonNode] =
  let payload = %*[chatId]
  result = core.callPrivateRPC("syncChatFromSyncedFrom".prefix, payload)
  info "syncChatFromSyncedFrom", topics="mailserver-interaction", rpc_method="wakuext_syncChatFromSyncedFrom", chatId, result

proc fillGaps*(chatId: string, messageIds: seq[string]): RpcResponse[JsonNode] =
  let payload = %*[chatId, messageIds]
  result = core.callPrivateRPC("fillGaps".prefix, payload)
  info "fillGaps", topics="mailserver-interaction", rpc_method="wakuext_fillGaps", chatId, messageIds, result

proc requestAllHistoricMessagesWithRetries*(forceFetchingBackup: bool): RpcResponse[JsonNode] =
  let payload = %*[forceFetchingBackup]
  result = core.callPrivateRPC("requestAllHistoricMessagesWithRetries".prefix, payload)
