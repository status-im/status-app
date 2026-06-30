import ../../../../../app_service/service/devices/service as devices_service
import ../../../../../app_service/service/devices/dto/[installation]

type
  Item* = ref object
    installation: InstallationDto
    isCurrentDevice: bool

proc initItem*(installation: InstallationDto, isCurrentDevice: bool): Item =
  result = Item()
  result.installation = installation
  result.isCurrentDevice = isCurrentDevice

proc installation*(self: Item): InstallationDto =
  return self.installation

proc `installation=`*(self: Item, installation: InstallationDto) =
  self.installation = installation

proc identity*(self: Item): string =
  self.installation.identity

proc `identity=`*(self: Item, value: string) =
  self.installation.identity = value

proc version*(self: Item): int =
  self.installation.version

proc `version=`*(self: Item, value: int) =
  self.installation.version = value

proc name*(self: Item): string =
  self.installation.metadata.name

proc `name=`*(self: Item, value: string) =
  self.installation.metadata.name = value

proc enabled*(self: Item): bool =
  self.installation.enabled

proc `enabled=`*(self: Item, value: bool) =
  self.installation.enabled = value

proc timestamp*(self: Item): int64 =
  self.installation.timestamp

proc `timestamp=`*(self: Item, value: int64) =
  self.installation.timestamp = value

proc deviceType*(self: Item): string =
  self.installation.metadata.deviceType

proc `deviceType=`*(self: Item, value: string) =
  self.installation.metadata.deviceType = value

proc fcmToken*(self: Item): string =
  self.installation.metadata.fcmToken

proc `fcmToken=`*(self: Item, value: string) =
  self.installation.metadata.fcmToken = value

proc isCurrentDevice*(self: Item): bool =
  self.isCurrentDevice
