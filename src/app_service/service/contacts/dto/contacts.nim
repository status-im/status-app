{.used.}

import json, std/strformat, strutils

include ../../../common/json_utils
include ../../../common/utils

type
  Images* = object
    thumbnail*: string
    large*: string

type ContactRequestState* {.pure.} = enum
  None = 0
  Mutual = 1
  Sent = 2
  Received = 3
  Dismissed = 4

type ContactsDto* = object
  id*: string
  name*: string
  ensVerified*: bool
  displayName*: string
  alias*: string
  lastUpdated*: int64
  lastUpdatedLocally*: int64
  localNickname*: string
  bio*: string
  image*: Images
  added*: bool
  blocked*: bool
  hasAddedUs*: bool
  removed*: bool
  trustStatus*: TrustStatus
  contactRequestState*: ContactRequestState

proc `$`(self: Images): string =
  result = fmt"""Images(
    thumbnail: {self.thumbnail},
    large: {self.large},
    ]"""

proc `$`*(self: ContactsDto): string =
  result = fmt"""ContactsDto(
    id: {self.id},
    name: {self.name},
    ensVerified: {self.ensVerified},
    alias: {self.alias},
    lastUpdated: {self.lastUpdated},
    lastUpdatedLocally: {self.lastUpdatedLocally},
    localNickname: {self.localNickname},
    displayName: {self.displayName},
    image:[
      {$self.image}
    ],
    added:{self.added},
    blocked:{self.blocked},
    hasAddedUs:{self.hasAddedUs},
    removed:{self.removed},
    trustStatus:{self.trustStatus},
    contactRequestState:{self.contactRequestState},
    )"""

proc toImages*(jsonObj: JsonNode): Images =
  result = Images()

  var largeObj: JsonNode
  if jsonObj.getProp("large", largeObj):
    discard largeObj.getProp("localUrl", result.large)

  var thumbnailObj: JsonNode
  if jsonObj.getProp("thumbnail", thumbnailObj):
    discard thumbnailObj.getProp("localUrl", result.thumbnail)

proc toImagesFromArray*(jsonObj: JsonNode): Images =
  result = Images()

  for image in jsonObj:
    if image.kind == JObject:
      var imgType: string
      discard image.getProp("type", imgType)
      if imgType == "large":
        discard image.getProp("localUrl", result.large)
      elif imgType == "thumbnail":
        discard image.getProp("localUrl", result.thumbnail)

proc toContactRequestState*(value: int): ContactRequestState =
  result = ContactRequestState.None
  if value >= ord(low(ContactRequestState)) and value <= ord(high(ContactRequestState)):
      result = ContactRequestState(value)

proc toTrustStatus*(value: int): TrustStatus =
  result = TrustStatus.Unknown
  if value >= ord(low(TrustStatus)) and value <= ord(high(TrustStatus)):
      result = TrustStatus(value)

proc toContactsDto*(jsonObj: JsonNode): ContactsDto =
  result = ContactsDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("ensVerified", result.ensVerified)
  result.name = ""
  if (result.ensVerified):
    discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("displayName", result.displayName)
  discard jsonObj.getProp("alias", result.alias)
  discard jsonObj.getProp("lastUpdated", result.lastUpdated)
  discard jsonObj.getProp("lastUpdatedLocally", result.lastUpdatedLocally)
  discard jsonObj.getProp("localNickname", result.localNickname)
  discard jsonObj.getProp("bio", result.bio)

  result.contactRequestState = ContactRequestState.None
  var contactRequestState: int
  discard jsonObj.getProp("contactRequestState", contactRequestState)
  result.contactRequestState = contactRequestState.toContactRequestState()

  result.trustStatus = TrustStatus.Unknown
  var trustStatusInt: int
  discard jsonObj.getProp("trustStatus", trustStatusInt)
  result.trustStatus = trustStatusInt.toTrustStatus()

  var imagesObj: JsonNode
  if jsonObj.getProp("images", imagesObj):
    result.image = toImages(imagesObj)

  discard jsonObj.getProp("added", result.added)
  discard jsonObj.getProp("blocked", result.blocked)
  discard jsonObj.getProp("hasAddedUs", result.hasAddedUs)
  discard jsonObj.getProp("Removed", result.removed)

proc userExtractedName(contact: ContactsDto): string =
  if(contact.name.len > 0 and contact.ensVerified):
    result = contact.name
  elif contact.displayName.len > 0:
    result = contact.displayName
  else:
    result = contact.alias

proc userDefaultDisplayName*(contact: ContactsDto): string =
  if(contact.localNickname.len > 0):
    result = contact.localNickname
  else:
    result = userExtractedName(contact)

proc userOptionalName*(contact: ContactsDto): string =
  if(contact.localNickname.len > 0):
    result = userExtractedName(contact)

proc isContactRequestReceived*(self: ContactsDto): bool =
  return self.hasAddedUs

proc isReceivedContactRequestRejected*(self: ContactsDto): bool =
  return self.contactRequestState == ContactRequestState.Dismissed

proc isContactRequestSent*(self: ContactsDto): bool =
  return self.added

proc isContactRemoved*(self: ContactsDto): bool =
  return self.removed

# Temporary commented until we provide appropriate flags on the `status-go` side to cover all sections.
# proc isSentContactRequestRejected*(self: ContactsDto): bool =
#   # TODO not implemented in `status-go` yet
#   # We don't have this prop for now.
#   return false

proc isBlocked*(self: ContactsDto): bool =
  return self.blocked

proc isContact*(self: ContactsDto): bool =
  # TODO not implemented in `status-go` yet
  # But for now we consider that contact is mutual contact if I added him and he added me.
  return self.hasAddedUs and self.added and not self.removed and not self.blocked

proc trustStatus*(self: ContactsDto): TrustStatus =
  result = self.trustStatus

proc isContactVerified*(self: ContactsDto): bool =
  return self.trustStatus == TrustStatus.Trusted

proc isContactUntrustworthy*(self: ContactsDto): bool =
  return self.trustStatus == TrustStatus.Untrustworthy

proc isContactMarked*(self: ContactsDto): bool =
  return self.isContactVerified() or self.isContactUntrustworthy()
