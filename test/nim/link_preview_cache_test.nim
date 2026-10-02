import unittest, tables

import app/modules/main/chat_section/chat_content/input_area/link_preview_cache
import app_service/service/message/dto/link_preview

proc preview(url: string): LinkPreview =
  result = initLinkPreview(url)
  result.previewType = PreviewType.StandardPreview

proc put(cache: LinkPreviewCache, urls: varargs[string]) =
  var items = initTable[string, LinkPreview]()
  for url in urls:
    items[url] = preview(url)
  discard cache.add(items)

suite "link_preview_cache":
  setup:
    let cache = newLinkPreiewCache()

  test "unknownUrls skips cached and in-flight urls":
    put(cache, "https://cached.example")
    cache.markAsRequested(@["https://pending.example"])
    check cache.unknownUrls(@[
      "https://cached.example",
      "https://pending.example",
      "https://fresh.example",
    ]) == @["https://fresh.example"]

  test "add stores preview and clears in-flight marker":
    let url = "https://example.com"
    cache.markAsRequested(@[url])
    check cache.unknownUrls(@[url]).len == 0
    put(cache, url)
    check cache.linkPreviews(@[url]).hasKey(url)
    check cache.unknownUrls(@[url]).len == 0

  test "linkPreviews and linkPreviewsSeq skip unknown urls":
    put(cache, "https://a.example", "https://b.example")

    let previews = cache.linkPreviews(@["https://a.example", "https://missing.example"])
    check previews.len == 1
    check previews["https://a.example"].url == "https://a.example"

    let ordered = cache.linkPreviewsSeq(@[
      "https://b.example",
      "https://a.example",
      "https://missing.example",
    ])
    check ordered.len == 2
    check ordered[0].url == "https://b.example"
    check ordered[1].url == "https://a.example"

  test "clear resets cache and in-flight requests":
    let url = "https://example.com"
    put(cache, url)
    cache.markAsRequested(@[url])
    cache.clear()
    check cache.unknownUrls(@[url]) == @[url]
    check cache.linkPreviews(@[url]).len == 0
