import std/[sequtils, tables]
import dto/thread
import ../chat/dto/chat
import ../community/dto/community
import ../../common/types

proc canEditThread*(thread: ThreadDto, chat: ChatDto, publicKey: string,
    community: CommunityDto): bool =
  if thread.threadId.len == 0 or publicKey.len == 0 or thread.chatId != chat.id:
    return false
  let isCreator = thread.creatorId.len > 0 and thread.creatorId == publicKey
  case chat.chatType
  of ChatType.OneToOne:
    return isCreator
  of ChatType.PrivateGroupChat:
    for member in chat.members:
      if member.id == publicKey:
        return isCreator or member.role == MemberRole.Owner
    return false
  of ChatType.CommunityChat:
    if community.isOwner or community.isAdmin or community.isTokenMaster:
      return true
    if not chat.canView or not community.members.anyIt(it.id == publicKey):
      return false
    if community.pendingAndBannedMembers.hasKey(publicKey) and
        community.pendingAndBannedMembers[publicKey].isBanned:
      return false
    return isCreator
  else:
    return false
