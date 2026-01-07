import std/strformat

type
  Item* = object
    address: string
    ensName: string
    tags: seq[string]
    avatar: string

proc initItem*(
  address: string,
  ensName: string,
  tags: seq[string],
  avatar: string
): Item =
  result.address = address
  result.ensName = ensName
  result.tags = tags
  result.avatar = avatar

proc `$`*(self: Item): string =
  result = fmt"""FollowingAddressItem(
    address: {self.address},
    ensName: {self.ensName},
    tags: {self.tags},
    avatar: {self.avatar},
    ]"""

proc isEmpty*(self: Item): bool =
  return self.address.len == 0

proc getAddress*(self: Item): string =
  return self.address

proc getEnsName*(self: Item): string =
  return self.ensName

proc getTags*(self: Item): seq[string] =
  return self.tags

proc getName*(self: Item): string =
  # Use ENS name if available, otherwise use address
  if self.ensName.len > 0:
    return self.ensName
  return self.address

proc getAvatar*(self: Item): string =
  return self.avatar
