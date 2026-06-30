#################################################
# Async get chats
#################################################

type
  AsyncGetActiveChatsTaskArg = ref object of QObjectTaskArg

proc asyncGetActiveChatsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncGetActiveChatsTaskArg](argEncoded)
  try:
    let response = status_chat.getActiveChats()

    arg.finish(%*{
      "chats": response.result,
      "error": response.error,
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

type
  AsyncCheckChannelPermissionsTaskArg = ref object of QObjectTaskArg
    communityId: string
    chatId: string

proc asyncCheckChannelPermissionsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCheckChannelPermissionsTaskArg](argEncoded)
  try:
    let response = status_communities.checkCommunityChannelPermissions(arg.communityId, arg.chatId).result

    arg.finish(%* {
      "response": response,
      "communityId": arg.communityId,
      "chatId": arg.chatId,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "chatId": arg.chatId,
      "error": e.msg,
    })

type
  AsyncCheckAllChannelsPermissionsTaskArg = ref object of QObjectTaskArg
    communityId: string
    addresses: seq[string]

proc asyncCheckAllChannelsPermissionsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCheckAllChannelsPermissionsTaskArg](argEncoded)
  try:
    let result = status_communities.checkAllCommunityChannelsPermissions(arg.communityId, arg.addresses).result
    let allChannelsPermissions = result.toCheckAllChannelsPermissionsResponseDto()
    arg.finish(%* {
      "response": allChannelsPermissions,
      "communityId": arg.communityId,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "error": e.msg,
    })

type
  AsyncSendMessageTaskArg = ref object of QObjectTaskArg
    chatId: string
    processedMsg: string
    replyTo: string
    contentType: int
    preferredUsername: string
    communityId: string
    standardLinkPreviews: JsonNode
    statusLinkPreviews: JsonNode
    paymentRequests: JsonNode

const asyncSendMessageTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncSendMessageTaskArg](argEncoded)
  try:
    
    let response = status_chat.sendChatMessage(
      arg.chatId,
      arg.processedMsg,
      arg.replyTo,
      arg.contentType,
      arg.preferredUsername,
      arg.standardLinkPreviews,
      arg.statusLinkPreviews,
      arg.paymentRequests,
      arg.communityId)

    arg.finish(%* {
      "response": response,
      "chatId": arg.chatId,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "chatId": arg.chatId,
    })

type
  AsyncSendImagesTaskArg = ref object of QObjectTaskArg
    chatId: string
    imagePathsJson: string
    msg: string
    replyTo: string
    preferredUsername: string
    standardLinkPreviews: JsonNode
    statusLinkPreviews: JsonNode
    paymentRequests: JsonNode

const asyncSendImagesTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncSendImagesTaskArg](argEncoded)
  try:
    var images = Json.decode(arg.imagePathsJson, seq[string])
    var imagePaths: seq[string] = @[]

    for imagePathOrSource in images.mitems:
      if utils.isBase64DataUrl(imagePathOrSource):
        let imagePath = common_utils.save_byte_image_to_file(imagePathOrSource)
        if imagePath != "":
          imagePaths.add(imagePath)
      else:
        imagePaths.add(imagePathOrSource)

    let response = status_chat.sendImages(
      arg.chatId,
      imagePaths,
      arg.msg,
      arg.replyTo,
      arg.preferredUsername,
      arg.standardLinkPreviews,
      arg.statusLinkPreviews,
      arg.paymentRequests
    )

    arg.finish(%* {
      "response": response,
      "chatId": arg.chatId,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "chatId": arg.chatId,
    })
