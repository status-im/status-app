import std/strformat
import ../../../shared_models/[token_permissions_model, token_permission_item]

type
  CuratedCommunityItem* = object
    id: string
    name: string
    description: string
    available: bool
    icon: string
    banner: string
    color: string
    tags: string
    members: int
    activeMembers: int
    featured: bool
    permissionModel: TokenPermissionsModel
    amIBanned: bool
    joined: bool
    encrypted: bool

proc initCuratedCommunityItem*(
  id: string,
  name: string,
  description: string,
  available: bool,
  icon: string,
  banner: string,
  color: string,
  tags: string,
  members: int,
  activeMembers: int,
  featured: bool,
  tokenPermissionsItems: seq[TokenPermissionItem],
  amIBanned: bool,
  joined: bool,
  encrypted: bool
): CuratedCommunityItem =
  result.id = id
  result.name = name
  result.description = description
  result.available = available
  result.icon = icon
  result.banner = banner
  result.color = color
  result.tags  = tags
  result.members = members
  result.activeMembers = activeMembers
  result.featured = featured
  result.permissionModel = newTokenPermissionsModel()
  if tokenPermissionsItems.len > 0:
    result.permissionModel.setItems(tokenPermissionsItems)
  result.amIBanned = amIBanned
  result.joined = joined
  result.encrypted = encrypted

proc `$`*(self: CuratedCommunityItem): string =
  result = fmt"""CuratedCommunityItem(
    id: {self.id},
    name: {self.name},
    description: {self.description},
    available: {self.available},
    color: {self.color},
    tags: {self.tags},
    members: {self.members}
    activeMembers: {self.activeMembers}
    featured: {self.featured}
    amIBanned: {self.amIBanned}
    joined: {self.joined}
    encrypted: {self.encrypted}
    ]"""

proc getId*(self: CuratedCommunityItem): string =
  return self.id

proc getName*(self: CuratedCommunityItem): string =
  return self.name

proc getDescription*(self: CuratedCommunityItem): string =
  return self.description

proc isAvailable*(self: CuratedCommunityItem): bool =
  return self.available

proc getIcon*(self: CuratedCommunityItem): string =
  return self.icon

proc getBanner*(self: CuratedCommunityItem): string =
  return self.banner

proc getMembers*(self: CuratedCommunityItem): int =
  return self.members

proc getActiveMembers*(self: CuratedCommunityItem): int =
  return self.activeMembers

proc getColor*(self: CuratedCommunityItem): string =
  return self.color

proc getTags*(self: CuratedCommunityItem): string =
  return self.tags

proc getFeatured*(self: CuratedCommunityItem): bool =
  return self.featured

proc getPermissionsModel*(self: CuratedCommunityItem): TokenPermissionsModel =
  return self.permissionModel

proc setPermissionModelItems*(self: CuratedCommunityItem, items: seq[TokenPermissionItem]) =
  self.permissionModel.setItems(items)

proc getAmIBanned*(self: CuratedCommunityItem): bool =
  return self.amIBanned

proc getJoined*(self: CuratedCommunityItem): bool =
  return self.joined

proc getEncrypted*(self: CuratedCommunityItem): bool =
  return self.encrypted
