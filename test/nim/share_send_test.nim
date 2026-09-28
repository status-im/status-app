import unittest, json, tables, sequtils, strutils, options

import app/modules/main/share_send
import app_service/service/message/dto/urls_unfurling_plan
import app_service/service/message/dto/link_preview
import app_service/service/settings/dto/settings

proc meta(url: string, permission: UrlUnfurlingPermission, status = false): UrlUnfurlingMetadata =
  result = UrlUnfurlingMetadata()
  result.url = url
  result.permission = permission
  result.isStatusSharedUrl = status

suite "share send - destinations":
  test "parses sectionId/chatId pairs in order":
    let dests = parseShareDestinations("""[{"sectionId":"c1","chatId":"ch1"},{"sectionId":"p","chatId":"0x04a"}]""")
    check(dests.len == 2)
    check(dests[0].sectionId == "c1" and dests[0].chatId == "ch1")
    check(dests[1].chatId == "0x04a")

  test "invalid json or missing chatId yields no destinations":
    check(parseShareDestinations("not json").len == 0)
    check(parseShareDestinations("""[{"sectionId":"c1"}]""").len == 0)

  test "keeps only the first SHARE_MAX_DESTINATIONS destinations":
    var entries: seq[string] = @[]
    for i in 0 ..< SHARE_MAX_DESTINATIONS + 2:
      entries.add("""{"sectionId":"p","chatId":"chat-""" & $i & "\"}")
    let dests = parseShareDestinations("[" & entries.join(",") & "]")
    check(dests.len == SHARE_MAX_DESTINATIONS)
    check(dests[^1].chatId == "chat-" & $(SHARE_MAX_DESTINATIONS - 1))

suite "share send - unfurlable urls":
  test "keeps allowed urls, skips ask/forbidden/unsupported and status message links":
    let plan = UrlsUnfurlingPlan(urls: @[
      meta("https://a.example", UrlUnfurlingAllowed),
      meta("https://b.example", UrlUnfurlingAskUser),
      meta("https://c.example", UrlUnfurlingForbiddenBySettings),
      meta("https://d.example", UrlUnfurlingNotSupported),
      meta("https://status.app/m/abc", UrlUnfurlingAllowed),
      meta("https://status.app/c/xyz", UrlUnfurlingAllowed, status = true),
    ])
    check(unfurlableUrls(plan, limit = 5) == @["https://a.example", "https://status.app/c/xyz"])

  test "respects the limit":
    let plan = UrlsUnfurlingPlan(urls: @[
      meta("https://1.example", UrlUnfurlingAllowed),
      meta("https://2.example", UrlUnfurlingAllowed),
      meta("https://3.example", UrlUnfurlingAllowed),
    ])
    check(unfurlableUrls(plan, limit = 2).len == 2)

suite "share send - ordered previews":
  test "returns previews in url order and skips missing ones":
    var previews = initTable[string, LinkPreview]()
    previews["https://b.example"] = initLinkPreview("https://b.example")
    previews["https://a.example"] = initLinkPreview("https://a.example")
    let ordered = orderedLinkPreviews(@["https://a.example", "https://x.example", "https://b.example"], previews)
    check(ordered.len == 2)
    check(ordered[0].url == "https://a.example")
    check(ordered[1].url == "https://b.example")

suite "share send - dispatch rules":
  test "test_imageSendsAreSequentialAndReleaseOnLast":
    var queue: seq[PendingShare] = @[]
    let dests = @[ShareDestination(chatId: "a"), ShareDestination(chatId: "b"), ShareDestination(chatId: "c")]
    discard enqueueShare(queue, PendingShare(token: "t", destinations: dests,
      imagePaths: @["/cache/img.png"], imageSends: imageSendPlan(dests, @["/cache/img.png"], "t")))
    var flags: seq[bool] = @[]
    while true:
      let d = takeNextImageDispatch(queue)
      if d.isNone: break
      flags.add(d.get().releaseCachedFiles)
    check(flags == @[false, false, true])

  test "test_imagesAreChunkedPerDestinationWithTextOnTheFirstChunk":
    let dests = @[ShareDestination(chatId: "a"), ShareDestination(chatId: "b")]
    var paths: seq[string] = @[]
    for i in 0 ..< 13: paths.add("/cache/" & $i & ".png")
    let sends = imageSendPlan(dests, paths, "t")
    check(sends.len == 6)
    check(sends.mapIt(it.chatId) == @["a", "a", "a", "b", "b", "b"])
    check(sends.mapIt(it.imagePaths.len) == @[6, 6, 1, 6, 6, 1])
    check(sends.mapIt(it.withText) == @[true, false, false, true, false, false])
    check(sends[0].imagePaths[0] == "/cache/0.png" and sends[2].imagePaths[0] == "/cache/12.png")
    check(sends.mapIt(it.token) == @["t-0", "t-1", "t-2", "t-3", "t-4", "t-5"])
    check(imageSendPlan(dests, @[], "t").len == 0)

  test "test_sendSharedContentSkipsUnfurlWhenNotEnabled":
    check(not needsUnfurl(UrlUnfurlingMode.AlwaysAsk, "https://a.example"))
    check(not needsUnfurl(UrlUnfurlingMode.Disabled, "https://a.example"))
    check(not needsUnfurl(UrlUnfurlingMode.Enabled, "   "))
    check(needsUnfurl(UrlUnfurlingMode.Enabled, "https://a.example"))

suite "share send - queue":
  test "test_secondShareWaitsUntilFirstFinishes":
    var queue: seq[PendingShare] = @[]
    check(enqueueShare(queue, PendingShare(token: "a")) == true)
    check(enqueueShare(queue, PendingShare(token: "b")) == false)
    check(finishActiveShare(queue) == true)
    check(queue.len == 1 and queue[0].token == "b")
    check(finishActiveShare(queue) == false)
    check(queue.len == 0)

  test "test_finishedSignalMatchesOnlyActiveTokenAndChat":
    var queue: seq[PendingShare] = @[]
    let dests = @[ShareDestination(chatId: "chat-a"), ShareDestination(chatId: "chat-b")]
    discard enqueueShare(queue, PendingShare(token: "token-a", destinations: dests,
      imagePaths: @["/cache/img.png"], imageSends: imageSendPlan(dests, @["/cache/img.png"], "token-a")))
    discard takeNextImageDispatch(queue)   # chat-a is in flight
    check(matchesActiveImageSend(queue, "chat-a", "token-b-0") == false)
    check(matchesActiveImageSend(queue, "chat-b", "token-a-0") == false)
    check(matchesActiveImageSend(queue, "chat-a", "token-a-1") == false)  # chat-b's send, not yet dispatched
    check(matchesActiveImageSend(queue, "chat-a", "token-a") == false)    # share token is not a send token
    check(matchesActiveImageSend(queue, "chat-a", "token-a-0") == true)
    check(matchesActiveImageSend(@[], "chat-a", "token-a-0") == false)

  test "test_unfurlFailureFallsBackToPlainSend":
    var queue: seq[PendingShare] = @[]
    discard enqueueShare(queue, PendingShare(token: "t", planRequestUuid: "plan-1", unfurlRequestUuid: "unfurl-1"))
    check(unfurlFailureMatchesActive(queue, "") == true)
    check(unfurlFailureMatchesActive(queue, "plan-1") == true)
    check(unfurlFailureMatchesActive(queue, "unfurl-1") == true)
    check(unfurlFailureMatchesActive(queue, "other") == false)

  test "test_unfurlFailureEmptyUuidFalseWhenNoHopPending":
    var queue: seq[PendingShare] = @[]
    discard enqueueShare(queue, PendingShare(token: "t"))
    check(unfurlFailureMatchesActive(queue, "") == false)

  test "test_synchronousFinishedSignalStillMatchesAfterDispatch":
    var queue: seq[PendingShare] = @[]
    let dests = @[ShareDestination(chatId: "chat-a"), ShareDestination(chatId: "chat-b")]
    discard enqueueShare(queue, PendingShare(token: "tok", destinations: dests,
      imagePaths: @["/cache/img.png"], imageSends: imageSendPlan(dests, @["/cache/img.png"], "tok")))

    let first = takeNextImageDispatch(queue)
    check(first.isSome)
    check(first.get().chatId == "chat-a")
    check(first.get().token == "tok-0")
    check(first.get().releaseCachedFiles == false)
    check(matchesActiveImageSend(queue, "chat-a", "tok-0") == true)

    let second = takeNextImageDispatch(queue)
    check(second.isSome)
    check(second.get().chatId == "chat-b")
    check(second.get().token == "tok-1")
    check(second.get().releaseCachedFiles == true)
    check(matchesActiveImageSend(queue, "chat-b", "tok-1") == true)

    let third = takeNextImageDispatch(queue)
    check(third.isNone)
