include ../../common/json_utils
include ../../../app/core/tasks/common

type
  ObtainMarketStickerPacksTaskArg = ref object of QObjectTaskArg
    chainId*: int
  InstallStickerPackTaskArg = ref object of QObjectTaskArg
    packId*: string
    chainId*: int

  AsyncGetRecentStickersTaskArg* = ref object of QObjectTaskArg
  AsyncGetInstalledStickerPacksTaskArg* = ref object of QObjectTaskArg

proc asyncGetRecentStickersTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncGetRecentStickersTaskArg](argEncoded)
  try:
    let response = status_stickers.recent()
    arg.finish(response)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })


proc asyncGetInstalledStickerPacksTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncGetInstalledStickerPacksTaskArg](argEncoded)
  try:
    let response = status_stickers.installed()
    arg.finish(response)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

proc getMarketStickerPacks*(chainId: int):
    tuple[stickers: Table[string, StickerPackDto], error: string] =
  result = (initTable[string, StickerPackDto](), "")
  try:
    let marketResponse = status_stickers.market(chainId)
    if marketResponse.result.kind != JArray: return
    for currItem in marketResponse.result.items():
      let stickerPack = currItem.toStickerPackDto()
      result.stickers[stickerPack.id] = stickerPack
  except RpcException:
    error "Error in getMarketStickerPacks", message = getCurrentExceptionMsg()
    result.error = getCurrentExceptionMsg()

proc obtainMarketStickerPacksTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ObtainMarketStickerPacksTaskArg](argEncoded)
  let (marketStickerPacks, error) = getMarketStickerPacks(arg.chainId)
  var packs: seq[StickerPackDto] = @[]
  for packId, stickerPack in marketStickerPacks.pairs:
    packs.add(stickerPack)
  let tpl: tuple[packs: seq[StickerPackDto], error: string] = (packs, error)
  arg.finish(tpl)

proc installStickerPackTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[InstallStickerPackTaskArg](argEncoded)

  var installed = false
  try:
    let installResponse = status_stickers.install(arg.chainId, arg.packId)
    if installResponse.error == nil:
      installed = true
    else:
      let err = Json.decode($installResponse.error, RpcError)
      error "Error installing stickers", message = err.message
  except RpcException:
    error "Error installing stickers", message = getCurrentExceptionMsg()
  let tpl: tuple[packId: string, installed: bool] = (arg.packId, installed)
  arg.finish(tpl)

type
  AsyncSendStickerTaskArg = ref object of QObjectTaskArg
    chatId: string
    replyTo: string
    threadId: string
    stickerHash: string
    stickerPackId: string
    preferredUsername: string

const asyncSendStickerTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncSendStickerTaskArg](argEncoded)
  try:
    let response = status_chat.sendChatMessage(
      arg.chatId,
      "You can see a nice sticker here!",
      arg.replyTo,
      ContentType.Sticker.int,
      arg.threadId,
      arg.preferredUsername,
      standardLinkPreviews = JsonNode(),
      statusLinkPreviews = JsonNode(),
      paymentRequests = JsonNode(),
      communityId = "", # communityId is not necessary when sending a sticker
      arg.stickerHash,
      arg.stickerPackId,
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
