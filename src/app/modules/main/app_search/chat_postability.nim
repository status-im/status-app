import std/sequtils

import app_service/service/chat/dto/chat
import app_service/service/contacts/dto/contacts

proc canPostInOneToOne*(contactState: ContactRequestState): bool =
  contactState == ContactRequestState.Mutual

# Same rule as the chat input: a 1:1 chat needs a mutual contact, a group chat
# needs membership; community channels carry their own post rights.
proc canPostInChat*(chat: ChatDto, contactState: ContactRequestState, myPubKey: string): bool =
  case chat.chatType
  of ChatType.OneToOne:
    canPostInOneToOne(contactState)
  of ChatType.PrivateGroupChat:
    chat.members.anyIt(it.id == myPubKey)
  else:
    chat.canPost
