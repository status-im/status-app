import std/strformat

type
  TokenPermissionChatListItem* = object
    key: string
    channelName: string

proc `$`*(self: TokenPermissionChatListItem): string =
  result = fmt"""TokenPermissionChatListItem(
    key: {self.key},
    channelName: {self.channelName}
    ]"""

proc initTokenPermissionChatListItem*(
  key: string,
  channelName: string
): TokenPermissionChatListItem =
  result.key = key
  result.channelName = channelName

proc getKey*(self: TokenPermissionChatListItem): string =
  return self.key

proc getChannelName*(self: TokenPermissionChatListItem): string =
  return self.channelName

proc channelName*(self: TokenPermissionChatListItem): string =
  return self.channelName

proc `channelName=`*(self: var TokenPermissionChatListItem, value: string) =
  self.channelName = value

