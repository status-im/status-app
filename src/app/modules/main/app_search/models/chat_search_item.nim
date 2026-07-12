type
  ChatSearchItem* = ref object
    chatId: string
    name: string
    color: string
    colorId: int
    icon: string
    sectionId: string
    sectionName: string
    emoji: string
    chatType: int
    lastMessageText: string
    lastMessageTimestamp: int
    canPost: bool

proc initItem*(chatId, name, color: string, colorId: int, icon, sectionId, sectionName, emoji: string, chatType: int, lastMessageText: string, lastMessageTimestamp: int, canPost: bool): ChatSearchItem =
  result = ChatSearchItem()
  result.chatId = chatId
  result.name = name
  result.color = color
  result.colorId = colorId
  result.icon = icon
  result.sectionId = sectionId
  result.sectionName = sectionName
  result.emoji = emoji
  result.chatType = chatType
  result.lastMessageText = lastMessageText
  result.lastMessageTimestamp = lastMessageTimestamp
  result.canPost = canPost

proc chatId*(self: ChatSearchItem): string =
  self.chatId

proc name*(self: ChatSearchItem): string =
  self.name

proc `name=`*(self: ChatSearchItem, value: string) =
  self.name = value

proc color*(self: ChatSearchItem): string =
  self.color

proc `color=`*(self: ChatSearchItem, value: string) =
  self.color = value

proc colorId*(self: ChatSearchItem): int =
  self.colorId

proc icon*(self: ChatSearchItem): string =
  self.icon

proc `icon=`*(self: ChatSearchItem, value: string) =
  self.icon = value

proc sectionId*(self: ChatSearchItem): string =
  self.sectionId

proc sectionName*(self: ChatSearchItem): string =
  self.sectionName

proc `sectionName=`*(self: ChatSearchItem, value: string) =
  self.sectionName = value

proc emoji*(self: ChatSearchItem): string =
  self.emoji

proc `emoji=`*(self: ChatSearchItem, value: string) =
  self.emoji = value

proc lastMessageText*(self: ChatSearchItem): string =
  self.lastMessageText

proc `lastMessageText=`*(self: ChatSearchItem, value: string) =
  self.lastMessageText = value

proc lastMessageTimestamp*(self: ChatSearchItem): int =
  self.lastMessageTimestamp

proc `lastMessageTimestamp=`*(self: ChatSearchItem, value: int) =
  self.lastMessageTimestamp = value

proc canPost*(self: ChatSearchItem): bool =
  self.canPost

proc `canPost=`*(self: ChatSearchItem, value: bool) =
  self.canPost = value

proc chatType*(self: ChatSearchItem): int =
  self.chatType
