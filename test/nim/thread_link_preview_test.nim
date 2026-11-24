import std/[json, unittest]

import app_service/service/message/dto/link_preview
import app_service/service/message/dto/standard_link_preview
import app_service/service/message/dto/link_preview_thumbnail

suite "thread link previews":
  test "thread metadata keeps its type, title, subtitle, parent and banner when sent":
    let url = "https://status.app/cc/channel?thread-id=thread#community"
    let preview = toLinkPreview(%*{
      "url": url, "type": 0, "hostname": "status.app", "title": "Release planning", "description": "Status Community", "threadParentName": "#general", "threadAccessible": true,
      "thumbnail": {"width": 320, "height": 170, "url": "https://localhost:1234/banner"}
    }, standard = true)
    check preview.previewType == PreviewType.StatusThreadPreview
    check not preview.empty()
    check preview.standardPreview.getTitle() == "Release planning"
    check preview.standardPreview.getThumbnail().getUrl() == "https://localhost:1234/banner"
    let (standard, status) = extractLinkPreviewsLists(@[preview])
    check standard.len == 1
    check status.len == 0
    let payload = %standard[0]
    check payload["url"].getStr() == url
    check payload["description"].getStr() == "Status Community"
    check payload["threadParentName"].getStr() == "#general"
    check preview.standardPreview.getThreadParentName() == "#general"
    check preview.standardPreview.getThreadAccessible()
    check payload["threadAccessible"].getBool()
    check payload["thumbnail"]["url"].getStr() == "https://localhost:1234/banner"
    preview.updateMediaServerPort(4321)
    check preview.standardPreview.getThumbnail().getUrl() == "https://localhost:4321/banner"

  test "ordinary link and channel previews retain their existing types":
    let web = toLinkPreview(%*{"url": "https://example.org/", "type": 0, "hostname": "example.org", "title": "Example"}, true)
    check web.previewType == PreviewType.StandardPreview
    check web.standardPreview.getThreadParentName() == ""
    check not (%web.standardPreview).hasKey("threadParentName")
    let channel = toLinkPreview(%*{"url": "https://status.app/cc/channel#community",
      "channel": {"channelUuid": "channel", "displayName": "general"}}, false)
    check channel.previewType == PreviewType.StatusCommunityChannelPreview

  test "identity-free direct thread links keep the thread preview type":
    for prefix in ["https://status.app/", "http://status.app/", "status-app://"]:
      let url = prefix & "p/?thread-id=thread"
      let preview = toLinkPreview(%*{"url": url, "type": 0, "hostname": "status.app", "title": "Thread", "description": "Chat"}, true)
      check preview.previewType == PreviewType.StatusThreadPreview
      check preview.url == url
      check not preview.empty()

  test "missing local authorization remains inaccessible":
    let preview = toLinkPreview(%*{"url": "https://status.app/p/?thread-id=thread", "type": 0,
      "hostname": "status.app", "title": "Legacy title", "description": "Legacy origin"}, true)
    check preview.previewType == PreviewType.StatusThreadPreview
    check not preview.standardPreview.getThreadAccessible()
