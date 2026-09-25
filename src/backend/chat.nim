import json, sequtils, sugar, strutils
import core, ../app_service/common/utils
import response_type
import interpret/cropped_image

export response_type

proc saveChat*(
    chatId: string,
    chatType: int,
    active: bool = true,
    color: string = "#000000",
    ensName: string = "",
    profile: string = "",
    joined: int64 = 0
    ): RpcResponse[JsonNode] =
  # TODO: ideally status-go/stimbus should handle some of these fields instead of having the client
  # send them: lastMessage, unviewedMEssagesCount, timestamp, lastClockValue, name?
  return callPrivateRPC("saveChat".prefix, %* [
    {
      "lastClockValue": 0, # TODO:
      "color": color,
      "name": (if ensName != "": ensName else: chatId),
      "lastMessage": nil, # TODO:
      "active": active,
      "profile": profile,
      "id": chatId,
      "unviewedMessagesCount": 0, # TODO:
      "chatType":  chatType.int,
      "timestamp": 1588940692659,  # TODO:
      "joined": joined
    }
  ])

proc getActiveChats*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = callPrivateRPC("activeChats".prefix, payload)

proc createOneToOneChat*(chatId: string, ensName: string = ""): RpcResponse[JsonNode] =
  let communityId = ""
  let payload = %* [communityId, chatId, ensName]
  result = callPrivateRPC("chat_createOneToOneChat", payload)

proc leaveGroupChat*(chatId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("leaveGroupChat".prefix, %* [chatId, true])

proc deactivateChat*(chatId: string, preserveHistory: bool = false): RpcResponse[JsonNode] =
  callPrivateRPC("deactivateChat".prefix, %* [{ "ID": chatId, "preserveHistory": preserveHistory }])

proc clearChatHistory*(chatId: string): RpcResponse[JsonNode] =
  callPrivateRPC("clearHistory".prefix, %* [{ "id": chatId }])

proc sendChatMessage*(
    chatId: string,
    msg: string,
    replyTo: string,
    contentType: int,
  threadId: string = "",
    preferredUsername: string = "",
    standardLinkPreviews: JsonNode,
    statusLinkPreviews: JsonNode,
    paymentRequests: JsonNode,
    communityId: string = "",
    stickerHash: string = "",
    stickerPack: string = "0",
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("sendChatMessage".prefix, %* [
    {
      "chatId": chatId,
      "text": msg,
      "responseTo": replyTo,
      "threadId": threadId,
      "ensName": preferredUsername,
      "sticker": {
        "hash": stickerHash,
        "pack": parseInt(stickerPack)
      },
      "contentType": contentType,
      "communityId": communityId,
      "linkPreviews": standardLinkPreviews,
      "statusLinkPreviews": statusLinkPreviews,
      "paymentRequests": paymentRequests,
    }
  ])

proc sendImages*(chatId: string,
                 images: var seq[string],
                 msg: string,
                 replyTo: string,
                 preferredUsername: string,
                 threadId: string = "",
                 standardLinkPreviews: JsonNode,
                 statusLinkPreviews: JsonNode,
                 paymentRequests: JsonNode,
                 ): RpcResponse[JsonNode] =
  let imagesJson = %* images.map(image => %*
      {
        "chatId": chatId,
        "contentType": 7, # TODO how do we unhardcode this
        "imagePath": image,
        "ensName": preferredUsername,
        "text": msg,
        "responseTo": replyTo,
        "threadId": threadId,
        "linkPreviews": standardLinkPreviews,
        "statusLinkPreviews": statusLinkPreviews,
        "paymentRequests": paymentRequests,
      }
    )
  callPrivateRPC("sendChatMessages".prefix, %* [imagesJson])

proc createThread*(chatId: string, parentMessageId: string): RpcResponse[JsonNode] =
  let payload = %* [chatId, parentMessageId]
  result = callPrivateRPC("createThread".prefix, payload)

proc fetchChatThreads*(chatId: string): RpcResponse[JsonNode] =
  let payload = %* [chatId]
  result = callPrivateRPC("chatThreads".prefix, payload)

proc muteChat*(chatId: string, interval: int): RpcResponse[JsonNode] =
  result = callPrivateRPC("muteChatV2".prefix, %* [
    {
      "chatId": chatId,
      "mutedType": interval,
    }
  ])

proc unmuteChat*(chatId: string): RpcResponse[JsonNode] =
  let payload = %* [chatId]
  result = callPrivateRPC("unmuteChat".prefix, payload)

proc deleteMessagesByChatId*(chatId: string): RpcResponse[JsonNode] =
  let payload = %* [chatId]
  result = callPrivateRPC("deleteMessagesByChatID".prefix, payload)

proc addGroupMembers*(communityID: string, chatId: string, pubKeys: seq[string]): RpcResponse[JsonNode] =
  let payload = %* [communityID, chatId, pubKeys]
  result = callPrivateRPC("addMembersToGroupChat".prefix, payload)

proc removeMemberFromGroupChat*(communityID: string, chatId: string, pubKey: string): RpcResponse[JsonNode] =
  let payload = %* [communityID, chatId, pubKey]
  result = callPrivateRPC("removeMemberFromGroupChat".prefix, payload)

proc renameGroupChat*(communityID: string, chatId: string, newName: string): RpcResponse[JsonNode] =
  let payload = %* [communityID, chatId, newName]
  result = callPrivateRPC("changeGroupChatName".prefix, payload)

proc makeAdmin*(communityID: string, chatId: string, pubKey: string): RpcResponse[JsonNode] =
  let payload = %* [communityID, chatId, [pubKey]]
  result = callPrivateRPC("addAdminsToGroupChat".prefix, payload)

proc editChat*(communityID: string, chatID: string, name: string, color: string, imageJson: string): RpcResponse[JsonNode] =
  let croppedImage = newCroppedImage(imageJson)
  let payload = %* [communityID, chatID, name, color, croppedImage]
  return core.callPrivateRPC("chat_editChat", payload)
