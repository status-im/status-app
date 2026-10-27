import std/unittest

import app_service/service/chat/dto/chat
import app_service/service/contacts/dto/contacts
import app/modules/main/app_search/chat_postability

const
  me = "0x04me"
  friend = "0x04friend"

proc oneToOne(): ChatDto =
  ChatDto(id: friend, chatType: ChatType.OneToOne, canPost: true)

proc group(members: seq[string]): ChatDto =
  result = ChatDto(id: "group", chatType: ChatType.PrivateGroupChat, canPost: true)
  for id in members:
    result.members.add(ChatMember(id: id, joined: true))

suite "chat postability":

  test "a 1:1 chat with a mutual contact is postable":
    check canPostInChat(oneToOne(), ContactRequestState.Mutual, me)

  test "a 1:1 chat with a removed contact is not postable":
    check not canPostInChat(oneToOne(), ContactRequestState.None, me)

  test "a 1:1 chat with a pending contact request is not postable":
    check not canPostInChat(oneToOne(), ContactRequestState.Sent, me)
    check not canPostInChat(oneToOne(), ContactRequestState.Received, me)

  test "a group chat is postable while the user is a member":
    check canPostInChat(group(@[me, friend]), ContactRequestState.None, me)

  test "a group chat the user was removed from is not postable":
    check not canPostInChat(group(@[friend]), ContactRequestState.None, me)

  test "a community channel keeps its own post rights":
    var channel = ChatDto(id: "channel", chatType: ChatType.CommunityChat, communityId: "c")
    channel.canPost = false
    check not canPostInChat(channel, ContactRequestState.None, me)
    channel.canPost = true
    check canPostInChat(channel, ContactRequestState.None, me)
