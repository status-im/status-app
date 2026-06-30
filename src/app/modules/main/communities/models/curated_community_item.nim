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

proc id*(self: CuratedCommunityItem): string =
  return self.id

proc `id=`*(self: var CuratedCommunityItem, value: string) =
  self.id = value

proc getName*(self: CuratedCommunityItem): string =
  return self.name

proc name*(self: CuratedCommunityItem): string =
  return self.name

proc `name=`*(self: var CuratedCommunityItem, value: string) =
  self.name = value

proc getDescription*(self: CuratedCommunityItem): string =
  return self.description

proc description*(self: CuratedCommunityItem): string =
  return self.description

proc `description=`*(self: var CuratedCommunityItem, value: string) =
  self.description = value

proc isAvailable*(self: CuratedCommunityItem): bool =
  return self.available

proc available*(self: CuratedCommunityItem): bool =
  return self.available

proc `available=`*(self: var CuratedCommunityItem, value: bool) =
  self.available = value

proc getIcon*(self: CuratedCommunityItem): string =
  return self.icon

proc icon*(self: CuratedCommunityItem): string =
  return self.icon

proc `icon=`*(self: var CuratedCommunityItem, value: string) =
  self.icon = value

proc getBanner*(self: CuratedCommunityItem): string =
  return self.banner

proc banner*(self: CuratedCommunityItem): string =
  return self.banner

proc `banner=`*(self: var CuratedCommunityItem, value: string) =
  self.banner = value

proc getMembers*(self: CuratedCommunityItem): int =
  return self.members

proc members*(self: CuratedCommunityItem): int =
  return self.members

proc `members=`*(self: var CuratedCommunityItem, value: int) =
  self.members = value

proc getActiveMembers*(self: CuratedCommunityItem): int =
  return self.activeMembers

proc activeMembers*(self: CuratedCommunityItem): int =
  return self.activeMembers

proc `activeMembers=`*(self: var CuratedCommunityItem, value: int) =
  self.activeMembers = value

proc getColor*(self: CuratedCommunityItem): string =
  return self.color

proc color*(self: CuratedCommunityItem): string =
  return self.color

proc `color=`*(self: var CuratedCommunityItem, value: string) =
  self.color = value

proc getTags*(self: CuratedCommunityItem): string =
  return self.tags

proc tags*(self: CuratedCommunityItem): string =
  return self.tags

proc `tags=`*(self: var CuratedCommunityItem, value: string) =
  self.tags = value

proc getFeatured*(self: CuratedCommunityItem): bool =
  return self.featured

proc featured*(self: CuratedCommunityItem): bool =
  return self.featured

proc `featured=`*(self: var CuratedCommunityItem, value: bool) =
  self.featured = value

proc getPermissionsModel*(self: CuratedCommunityItem): TokenPermissionsModel =
  return self.permissionModel

proc permissionModel*(self: CuratedCommunityItem): TokenPermissionsModel =
  return self.permissionModel

proc `permissionModel=`*(self: var CuratedCommunityItem, value: TokenPermissionsModel) =
  self.permissionModel = value

proc setPermissionModelItems*(self: CuratedCommunityItem, items: seq[TokenPermissionItem]) =
  self.permissionModel.setItems(items)

proc getAmIBanned*(self: CuratedCommunityItem): bool =
  return self.amIBanned

proc amIBanned*(self: CuratedCommunityItem): bool =
  return self.amIBanned

proc `amIBanned=`*(self: var CuratedCommunityItem, value: bool) =
  self.amIBanned = value

proc getJoined*(self: CuratedCommunityItem): bool =
  return self.joined

proc joined*(self: CuratedCommunityItem): bool =
  return self.joined

proc `joined=`*(self: var CuratedCommunityItem, value: bool) =
  self.joined = value

proc getEncrypted*(self: CuratedCommunityItem): bool =
  return self.encrypted

proc encrypted*(self: CuratedCommunityItem): bool =
  return self.encrypted

proc `encrypted=`*(self: var CuratedCommunityItem, value: bool) =
  self.encrypted = value
