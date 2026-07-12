import std/strformat


type
  # {.acyclic.}: only value fields, no refs — ORC must skip cycle tracking so a
  # worker-built preferences row applied on the GUI thread never calls rememberCycle.
  TokenPreferencesItem* {.acyclic.} = ref object of RootObj
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
