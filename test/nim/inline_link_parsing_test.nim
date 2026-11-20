import std/[json, unittest]
import app/modules/main/shared_urls/view as urls_view
import app/modules/main/shared_urls/io_interface
import app_service/service/shared_urls/dto/url_data

type ParserDelegate = ref object of AccessInterface

method parseSharedUrl(self: ParserDelegate, url: string): UrlDataDto =
  UrlDataDto(community: CommunityUrlDataDto(communityId: "community", displayName: "Status"),
    channel: CommunityChannelUrlDataDto(uuid: "channel", displayName: "general"))
method parseMessageUrl(self: ParserDelegate, url: string): MessageUrlDataDto =
  MessageUrlDataDto(chatId: "chat", messageId: "message", communityId: "community")
method parseThreadUrl(self: ParserDelegate, url: string): ThreadUrlDataDto =
  ThreadUrlDataDto(chatId: "chat", threadId: "thread", communityId: "community")

suite "existing shared-url parsers exposed to QML":
  test "shared, message and thread slots serialize the existing DTOs":
    let view = urls_view.newView(ParserDelegate())
    defer: view.delete()
    let shared = parseJson(view.parseSharedUrl("url"))
    check shared["community"]["communityId"].getStr == "community"
    check shared["channel"]["uuid"].getStr == "channel"
    check parseJson(view.parseMessageUrl("url"))["messageId"].getStr == "message"
    check parseJson(view.parseThreadUrl("url"))["threadId"].getStr == "thread"
