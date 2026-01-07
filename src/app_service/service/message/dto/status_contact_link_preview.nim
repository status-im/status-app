import json, std/strformat, nimqml, chronicles
import app/global/global_singleton
import link_preview_thumbnail
import ../../contacts/dto/contact_details

include ../../../common/json_utils

QtObject:
  type StatusContactLinkPreview* = ref object of QObject
    publicKey: string
    displayName: string
    description: string
    icon: LinkPreviewThumbnail
    emojiHash: string
  
  proc setup*(self: StatusContactLinkPreview)
  proc delete*(self: StatusContactLinkPreview)

  proc newStatusContactLinkPreview*(publicKey: var string, displayName: string, description: string, icon: LinkPreviewThumbnail, emojiHash: string): StatusContactLinkPreview =
    new(result, delete)
    result.setup()
    result.publicKey = publicKey
    result.displayName = displayName
    result.description = description
    result.icon.copy(icon)
    result.emojiHash = emojiHash

  proc setup*(self: StatusContactLinkPreview) =
    self.QObject.setup()
    self.icon = newLinkPreviewThumbnail()

  proc delete*(self: StatusContactLinkPreview) =
    self.QObject.delete()

  proc publicKeyChanged*(self: StatusContactLinkPreview) {.signal.}
  proc getPublicKey*(self: StatusContactLinkPreview): string {.slot.} =
    result = self.publicKey
  QtProperty[string] publicKey:
    read = getPublicKey
    notify = publicKeyChanged

  proc displayNameChanged*(self: StatusContactLinkPreview) {.signal.}
  proc getDisplayName*(self: StatusContactLinkPreview): string {.slot.} =
    result = self.displayName
  QtProperty[string] displayName:
    read = getDisplayName
    notify = displayNameChanged

  proc descriptionChanged*(self: StatusContactLinkPreview) {.signal.}
  proc getDescription*(self: StatusContactLinkPreview): string {.slot.} =
    result = self.description
  QtProperty[string] description:
    read = getDescription
    notify = descriptionChanged

  proc getIcon*(self: StatusContactLinkPreview): LinkPreviewThumbnail =
    result = self.icon

  proc emojiHashChanged*(self: StatusContactLinkPreview) {.signal.}
  proc getEmojiHash*(self: StatusContactLinkPreview): string {.slot.} =
    result = self.emojiHash
  QtProperty[string] emojiHash:
    read = getEmojiHash
    notify = emojiHashChanged

  proc toStatusContactLinkPreview*(jsonObj: JsonNode): StatusContactLinkPreview =
    var publicKey: string
    var displayName: string
    var description: string
    var icon: LinkPreviewThumbnail
    var emojiHash: string

    discard jsonObj.getProp("publicKey", publicKey)
    discard jsonObj.getProp("displayName", displayName)
    discard jsonObj.getProp("description", description)

    var iconJson: JsonNode
    if jsonObj.getProp("icon", iconJson):
      icon = toLinkPreviewThumbnail(iconJson)

    discard jsonObj.getProp("emojiHash", emojiHash)

    result = newStatusContactLinkPreview(publicKey, displayName, description, icon, emojiHash)

  proc `$`*(self: StatusContactLinkPreview): string =
    result = fmt"""StatusContactLinkPreview(
      publicKey: {self.publicKey},
      displayName: {self.displayName},
      description: {self.description},
      icon: {self.icon},
      emojiHash: {self.emojiHash}
    )"""

  proc `%`*(self: StatusContactLinkPreview): JsonNode =
    return %* {
      "publicKey": self.publicKey,
      "displayName": self.displayName,
      "description": self.description,
      "icon": self.icon,
      "emojiHash": self.emojiHash
    }

  proc empty*(self: StatusContactLinkPreview): bool =
    return self.publicKey.len == 0

  proc getEmojiHashAsJson*(self: StatusContactLinkPreview, publicKey: string): string =
    if publicKey == "" or not singletonInstance.utils.isChatKey(publicKey):
      return ""
    return singletonInstance.utils.getEmojiHashAsJson(publicKey)

  proc setContactInfo*(self: StatusContactLinkPreview, contactDetails: ContactDetails): bool =
    if self.publicKey != contactDetails.dto.id:
      return false
    
    debug "setContactInfo", publicKey = self.publicKey, displayName = $contactDetails.dto.displayname

    if self.displayName != contactDetails.defaultDisplayName:
      self.displayName = contactDetails.defaultDisplayName
      self.displayNameChanged()
    
    if self.description != contactDetails.dto.bio:
      self.description = contactDetails.dto.bio
      self.descriptionChanged()
    
    self.icon.update(0, 0, contactDetails.dto.image.thumbnail, "")

    self.emojiHash = self.getEmojiHashAsJson(self.publicKey)
    
    return true