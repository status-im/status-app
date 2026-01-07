import std/strformat


type
  TokenPreferencesItem* = ref object of RootObj
    key*: string # key used here should be crossChainId if not empty, otherwise tokenKey
    position*: int
    groupPosition*: int
    visible*: bool
    communityId*: string

proc `$`*(self: TokenPreferencesItem): string =
  result = fmt"""TokenPreferencesItem[
    key: {self.key},
    position: {self.position},
    groupPosition: {self.groupPosition},
    visible: {self.visible},
    communityId: {self.communityId}
    ]"""
