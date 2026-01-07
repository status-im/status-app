import std/strformat
import ../../../app_service/service/community/dto/community
import ../../../app_service/service/chat/dto/chat
import token_criteria_model
import token_criteria_item
import token_permission_chat_list_model
import token_permission_chat_list_item

type
  TokenPermissionItem* = object
    id*: string
    `type`*: int
    tokenCriteria*: TokenCriteriaModel
    chatList*: TokenPermissionChatListModel
    isPrivate*: bool
    tokenCriteriaMet*: bool
    state*: TokenPermissionState

proc `$`*(self: TokenPermissionItem): string =
  result = fmt"""TokenPermissionItem(
    id: {self.id},
    type: {self.type},
    isPrivate: {self.isPrivate},
    tokenCriteriaMet: {self.tokenCriteriaMet},
    state: {self.state}
    )"""

proc initTokenPermissionItem*(
  id: string,
  `type`: int,
  tokenCriteria: seq[TokenCriteriaItem],
  chatList: seq[TokenPermissionChatListItem],
  isPrivate: bool,
  tokenCriteriaMet: bool,
  state: TokenPermissionState
): TokenPermissionItem =
  result.id = id
  result.`type` = `type`
  result.tokenCriteria = newTokenCriteriaModel()
  result.chatList = newTokenPermissionChatListModel()
  result.isPrivate = isPrivate
  result.tokenCriteriaMet = tokenCriteriaMet
  result.state = state

  result.tokenCriteria.setItems(tokenCriteria)
  result.chatList.setItems(chatList)

proc addTokenCriteria*(self: TokenPermissionItem, tokenCriteria: TokenCriteriaItem) =
  self.tokenCriteria.addItem(tokenCriteria)

proc getId*(self: TokenPermissionItem): string =
  return self.id

proc getType*(self: TokenPermissionItem): int =
  return self.`type`

proc getTokenCriteria*(self: TokenPermissionItem): TokenCriteriaModel =
  return self.tokenCriteria

proc getChatList*(self: TokenPermissionItem): TokenPermissionChatListModel =
  return self.chatList

proc getIsPrivate*(self: TokenPermissionItem): bool =
  return self.isPrivate

proc getTokenCriteriaMet*(self: TokenPermissionItem): bool =
  return self.tokenCriteriaMet

proc getState*(self: TokenPermissionItem): int =
  return self.state.int

proc buildTokenPermissionItem*(tokenPermission: CommunityTokenPermissionDto, chats: seq[ChatDto]): TokenPermissionItem =
  var tokenCriteriaItems: seq[TokenCriteriaItem] = @[]

  for tc in tokenPermission.tokenCriteria:

    let tokenCriteriaItem = initTokenCriteriaItem(
      tc.symbol,
      tc.name,
      tc.amountInWei,
      tc.`type`.int,
      tc.ensPattern,
      false, # tokenCriteriaMet will be updated by a call to checkPermissionsToJoin
      tc.contractAddresses
    )

    tokenCriteriaItems.add(tokenCriteriaItem)

  var tokenPermissionChatListItems: seq[TokenPermissionChatListItem] = @[]

  for chat in chats:    
    tokenPermissionChatListItems.add(initTokenPermissionChatListItem(chat.id, chat.name))

  let tokenPermissionItem = initTokenPermissionItem(
      tokenPermission.id, 
      tokenPermission.`type`.int, 
      tokenCriteriaItems,
      tokenPermissionChatListItems,
      tokenPermission.isPrivate,
      false, # allTokenCriteriaMet will be updated by a call to checkPermissionsToJoin
      tokenPermission.state
  )

  return tokenPermissionItem
