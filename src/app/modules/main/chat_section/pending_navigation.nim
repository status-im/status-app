type
  ChatNavigation* = object
    chatId*: string
    messageId*: string
    threadId*: string

proc clear*(navigation: var ChatNavigation) =
  navigation = ChatNavigation()

proc resolveInitialNavigation*(pending: var ChatNavigation,
    availableChatIds: openArray[string], preferredChatId: string): ChatNavigation =
  ## Consume a request only once the channel list is complete. A missing
  ## requested channel falls back to the saved selection, then the first chat.
  let requested = pending
  pending.clear()
  if requested.chatId.len > 0 and requested.chatId in availableChatIds:
    return requested
  if preferredChatId.len > 0 and preferredChatId in availableChatIds:
    return ChatNavigation(chatId: preferredChatId)
  if availableChatIds.len > 0:
    return ChatNavigation(chatId: availableChatIds[0])

proc activatesWhenAdded*(requested: bool, sectionBuild: bool, chatCount: int): bool =
  ## A chat added on its own is selected when asked, or when it is the section's
  ## only chat. The first build adds every chat before the list is in place and
  ## then selects one itself.
  requested or (not sectionBuild and chatCount == 1)
