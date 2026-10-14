import std/[unittest, json]

import app_service/service/chat/dto/chat
import app_service/service/community/dto/community
import app_service/service/message/dto/status_community_link_preview
import app_service/service/message/utils/link_preview_utils

const
  keyA = "0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
  keyB = "0x04c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a"

proc communityJson(): JsonNode =
  %*{
    "id": "0x02aaaa",
    "name": "c",
    "membersCount": 2,
    "members": {
      keyA: {"roles": [1]},
      keyB: {"roles": []},
    },
    "chats": {
      "open": {"id": "open", "name": "open", "tokenGated": false},
      "gated": {
        "id": "gated", "name": "gated", "tokenGated": true,
        "members": {keyA: {"roles": [1]}},
      },
    },
  }

suite "community DTOs do not hold the member list":
  test "the member count comes from membersCount":
    let community = communityJson().toCommunityDto()
    check community.membersCount == 2

  test "community channels hold no members, gated or not":
    let community = communityJson().toCommunityDto()
    check community.chats.len == 2
    for chat in community.chats:
      check chat.members.len == 0

  test "a community channel parsed on its own holds no members":
    let chat = %*{"id": "gated", "tokenGated": true, "members": {keyA: {"roles": [1]}}}
    check chat.toChatDto("0x02aaaa").members.len == 0

  test "group chats keep their members":
    let group = %*{
      "id": "group", "chatType": ChatType.PrivateGroupChat.int,
      "members": [{"id": keyA, "admin": true, "joined": true}, {"id": keyB, "admin": false, "joined": true}],
    }
    check group.toChatDto().members.len == 2

suite "member count consumers read membersCount":
  test "a community link preview takes its member count from membersCount":
    let preview = toStatusCommunityLinkPreview(%*{"communityId": "0x02aaaa", "membersCount": 0})
    check preview.setCommunityInfo(communityJson().toCommunityDto())
    check preview.getMembersCount() == 2

suite "single-community messenger responses":
  test "the community comes from the top-level communities, not communityChanges":
    var community = communityJson()
    community["categories"] = %*{"cat": {"id": "cat", "name": "Cat", "position": 0}}
    let response = %*{
      "communities": [community],
      "communityChanges": [{"communityId": "0x02aaaa", "categoriesAdded": {"cat": {"id": "cat"}}}],
    }
    let parsed = response.responseCommunity()
    check parsed.id == "0x02aaaa"
    check parsed.membersCount == 2
    check parsed.categories.len == 1
    check parsed.categories[0].name == "Cat"
