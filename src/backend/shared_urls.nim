import json
import core

proc prefix*(methodName: string): string =
  result = "sharedurls_" & methodName

proc shareCommunityUrlWithChatKey*(communityId: string): RpcResponse[JsonNode] =
  return callPrivateRPC("shareCommunityURLWithChatKey".prefix, %*[communityId])

proc shareCommunityUrlWithData*(communityId: string): RpcResponse[JsonNode] =
  return callPrivateRPC("shareCommunityURLWithData".prefix, %*[communityId])

proc shareCommunityChannelUrlWithChatKey*(communityId: string, channelId: string): RpcResponse[JsonNode] =
  return callPrivateRPC("shareCommunityChannelURLWithChatKey".prefix, %*[communityId, channelId])

proc shareCommunityChannelUrlWithData*(communityId: string, channelId: string): RpcResponse[JsonNode] =
  return callPrivateRPC("shareCommunityChannelURLWithData".prefix, %*[communityId, channelId])

proc shareUserUrlWithData*(pubkey: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("shareUserURLWithData".prefix, %*[pubkey])

proc shareUserUrlWithChatKey*(pubkey: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("shareUserURLWithChatKey".prefix, %*[pubkey])

proc shareUserUrlWithENS*(pubkey: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("shareUserURLWithENS".prefix, %*[pubkey])

proc shareMessageUrl*(chatId: string, messageId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("shareMessageURL".prefix, %*[chatId, messageId])

proc parseSharedUrl*(url: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("parseSharedURL".prefix, %*[url])

proc parseMessageUrl*(url: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("parseMessageURL".prefix, %*[url])