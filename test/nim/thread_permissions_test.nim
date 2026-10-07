import std/[unittest, tables]
import app_service/service/message/dto/thread
import app_service/service/message/thread_permissions
import app_service/service/chat/dto/chat
import app_service/service/community/dto/community
import app_service/common/types

suite "thread editing permissions":
  let thread = ThreadDto(threadId: "thread", chatId: "chat", creatorId: "creator")

  test "one-to-one creator only and no legacy provenance inference":
    let chat = ChatDto(id: "chat", chatType: ChatType.OneToOne)
    check canEditThread(thread, chat, "creator", CommunityDto())
    check not canEditThread(thread, chat, "root-author", CommunityDto())
    check not canEditThread(ThreadDto(threadId: "legacy", chatId: "chat"), chat, "creator", CommunityDto())

  test "private-group membership is required even for the creator":
    var chat = ChatDto(id: "chat", chatType: ChatType.PrivateGroupChat,
      members: @[ChatMember(id: "member", role: MemberRole.None)])
    check not canEditThread(thread, chat, "creator", CommunityDto())
    check not canEditThread(thread, chat, "member", CommunityDto())
    chat.members.add(ChatMember(id: "creator", role: MemberRole.None))
    check canEditThread(thread, chat, "creator", CommunityDto())

  test "private-group administrators may rename legacy threads":
    let legacy = ThreadDto(threadId: "legacy", chatId: "chat")
    let chat = ChatDto(id: "chat", chatType: ChatType.PrivateGroupChat,
      members: @[ChatMember(id: "admin", role: MemberRole.Owner)])
    check canEditThread(legacy, chat, "admin", CommunityDto())

  test "community creator may rename a read-only channel thread":
    let chat = ChatDto(id: "chat", chatType: ChatType.CommunityChat, canView: true, canPost: false)
    let community = CommunityDto(members: @[ChatMember(id: "creator")])
    check canEditThread(thread, chat, "creator", community)

  test "owners admins and token masters may rename others and legacy threads":
    let chat = ChatDto(id: "chat", chatType: ChatType.CommunityChat, canView: true)
    let legacy = ThreadDto(threadId: "legacy", chatId: "chat")
    for role in [MemberRole.Owner, MemberRole.Admin, MemberRole.TokenMaster]:
      let community = CommunityDto(memberRole: role, members: @[ChatMember(id: "admin")])
      check canEditThread(thread, chat, "admin", community)
      check canEditThread(legacy, chat, "admin", community)
    let member = CommunityDto(members: @[ChatMember(id: "member")])
    check not canEditThread(thread, chat, "member", member)
    check not canEditThread(legacy, chat, "member", member)

  test "removed banned and channel-inaccessible creators cannot rename":
    var chat = ChatDto(id: "chat", chatType: ChatType.CommunityChat, canView: true)
    var community = CommunityDto(members: @[ChatMember(id: "creator")])
    chat.canView = false
    check not canEditThread(thread, chat, "creator", community)
    chat.canView = true
    community.pendingAndBannedMembers["creator"] = CommunityMemberPendingBanOrKick.Banned
    check not canEditThread(thread, chat, "creator", community)
    community.pendingAndBannedMembers.clear()
    community.members = @[]
    check not canEditThread(thread, chat, "creator", community)

  test "missing mismatched and unsupported identifiers fail closed":
    check not canEditThread(ThreadDto(), ChatDto(), "creator", CommunityDto())
    check not canEditThread(thread, ChatDto(id: "other", chatType: ChatType.OneToOne), "creator", CommunityDto())
    check not canEditThread(thread, ChatDto(id: "chat", chatType: ChatType.OneToOne), "", CommunityDto())
    check not canEditThread(thread, ChatDto(id: "chat", chatType: ChatType.Public), "creator", CommunityDto())
