import json, tables, strutils, options

import app_service/service/message/dto/urls_unfurling_plan
import app_service/service/message/dto/link_preview
import app_service/service/settings/dto/settings
import app_service/service/chat/image_batches

const SHARE_LINK_PREVIEWS_LIMIT* = 5  # same cap as the in-chat input area
const SHARE_MAX_DESTINATIONS* = 5     # the picker disables rows past this; enforced here too
const SHARE_IMAGES_PER_MESSAGE* = IMAGES_PER_MESSAGE

type
  ShareDestination* = object
    sectionId*: string
    chatId*: string

  ImageSend* = object
    token*: string
    chatId*: string
    imagePaths*: seq[string]
    withText*: bool

  PendingShare* = object
    token*: string
    destinations*: seq[ShareDestination]
    text*: string
    imagePaths*: seq[string]
    contentType*: int
    planRequestUuid*: string
    unfurlRequestUuid*: string
    urls*: seq[string]
    linkPreviews*: seq[LinkPreview]
    imageSends*: seq[ImageSend]
    nextImageSend*: int

  ImageDispatch* = object
    token*: string
    chatId*: string
    imagePaths*: seq[string]
    withText*: bool
    releaseCachedFiles*: bool

proc parseShareDestinations*(destinationsJson: string): seq[ShareDestination] =
  var node: JsonNode
  try:
    node = parseJson(destinationsJson)
  except CatchableError:
    return @[]
  if node.kind != JArray:
    return @[]
  var destinations: seq[ShareDestination] = @[]
  for entry in node:
    if destinations.len >= SHARE_MAX_DESTINATIONS:
      break
    let chatId = entry{"chatId"}.getStr()
    if chatId == "":
      continue
    destinations.add(ShareDestination(sectionId: entry{"sectionId"}.getStr(), chatId: chatId))
  return destinations

proc isStatusMessageUrl(url: string): bool =
  url.startsWith("https://status.app/m/") or url.startsWith("http://status.app/m/") or
    url.startsWith("status-app://m/")

# Share sends never prompt: only urls the plan already allows are unfurled.
proc unfurlableUrls*(plan: UrlsUnfurlingPlan, limit: int): seq[string] =
  var urls: seq[string] = @[]
  for metadata in plan.urls:
    if urls.len >= limit:
      break
    if metadata.permission != UrlUnfurlingAllowed or isStatusMessageUrl(metadata.url):
      continue
    urls.add(metadata.url)
  return urls

proc orderedLinkPreviews*(urls: seq[string], previews: Table[string, LinkPreview]): seq[LinkPreview] =
  var ordered: seq[LinkPreview] = @[]
  for url in urls:
    if previews.hasKey(url):
      ordered.add(previews[url])
  return ordered

proc imageSendPlan*(destinations: seq[ShareDestination], imagePaths: seq[string], shareToken: string,
    perMessage = SHARE_IMAGES_PER_MESSAGE): seq[ImageSend] =
  ## One message per destination per chunk of `perMessage` images, in
  ## destination order; the text rides on each destination's first chunk.
  ## Each send gets its own token so it can be dispatched and finished on its own.
  var sends: seq[ImageSend] = @[]
  for dest in destinations:
    for batch in imageBatches(imagePaths, shareToken, perMessage, firstIndex = sends.len):
      sends.add(ImageSend(token: batch.token, chatId: dest.chatId, imagePaths: batch.imagePaths,
        withText: batch.withText))
  return sends

proc needsUnfurl*(mode: UrlUnfurlingMode, text: string): bool =
  mode == UrlUnfurlingMode.Enabled and text.strip() != ""

proc enqueueShare*(queue: var seq[PendingShare], share: PendingShare): bool =
  ## Appends to the queue; returns true iff it became the active share (index 0).
  queue.add(share)
  return queue.len == 1

proc finishActiveShare*(queue: var seq[PendingShare]): bool =
  ## Drops the active share (index 0); returns true iff another share is now active.
  if queue.len == 0:
    return false
  queue = queue[1..^1]
  return queue.len > 0

proc takeNextImageDispatch*(queue: var seq[PendingShare]): Option[ImageDispatch] =
  ## Advances queue[0].nextImageSend BEFORE returning, so a finished signal
  ## emitted synchronously by the send still matches. Only the last send
  ## releases the cached copies.
  if queue.len == 0:
    return none(ImageDispatch)
  let active = queue[0]
  let i = active.nextImageSend
  if i >= active.imageSends.len:
    return none(ImageDispatch)
  queue[0].nextImageSend = i + 1
  let send = active.imageSends[i]
  return some(ImageDispatch(token: send.token, chatId: send.chatId, imagePaths: send.imagePaths,
    withText: send.withText, releaseCachedFiles: i == active.imageSends.len - 1))

proc matchesActiveImageSend*(queue: seq[PendingShare], chatId, sendToken: string): bool =
  ## True iff the finished signal belongs to the active share's current image send:
  ## that send's own token, and chatId is the destination it was dispatched to.
  if queue.len == 0:
    return false
  let active = queue[0]
  let sentIndex = active.nextImageSend - 1
  if sentIndex < 0 or sentIndex >= active.imageSends.len:
    return false
  let send = active.imageSends[sentIndex]
  return send.token == sendToken and send.chatId == chatId

proc unfurlFailureMatchesActive*(queue: seq[PendingShare], requestUuid: string): bool =
  ## True iff a failed unfurl hop (plan request or urls request) belongs to the active share.
  ## An empty uuid (unparseable payload) matches whenever a hop is pending.
  if queue.len == 0:
    return false
  let active = queue[0]
  if requestUuid == "":
    return active.planRequestUuid != "" or active.unfurlRequestUuid != ""
  return requestUuid == active.planRequestUuid or requestUuid == active.unfurlRequestUuid
