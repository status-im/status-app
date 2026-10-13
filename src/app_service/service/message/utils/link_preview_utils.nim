import chronicles
import ../dto/[link_preview, link_preview_thumbnail, status_community_link_preview, status_community_channel_link_preview]
import ../../community/dto/community
import ../../chat/dto/chat

# This file is to avoid a recursive import of status_community_link_preview

proc setCommunityInfo*(self: StatusCommunityLinkPreview, community: CommunityDto): bool =
  if self.communityId != community.id:
    return false

  debug "setCommunityInfo", communityId = self.communityId, communityName = community.name

  if self.displayName != community.name:
    self.displayName = community.name
    self.displayNameChanged()

  if self.description != community.description:
    self.description = community.description
    self.descriptionChanged()

  if self.membersCount != community.membersCount:
    self.membersCount = community.membersCount
    self.membersCountChanged()

  if self.activeMembersCount != community.activeMembersCount:
    self.activeMembersCount = int(community.activeMembersCount)
    self.activeMembersCountChanged()

  if self.color != community.color:
    self.color = community.color
    self.colorChanged()

  self.icon.update(0, 0, "", community.images.thumbnail)
  self.banner.update(0, 0, "", community.images.banner)

  if self.encrypted != community.encrypted:
    self.encrypted = community.encrypted
    self.encryptedChanged()

  if self.joined != community.joined:
    self.joined = community.joined
    self.joinedChanged()

  return true

proc setCommunityInfo*(self: StatusCommunityChannelLinkPreview, community: CommunityDto): bool =
  if not self.community.setCommunityInfo(community):
    return false

  for chat in community.chats:
    if chat.communityChannelUuid() != self.channelUuid:
      continue

    debug "setChannelInfo", communityId = $self.community.getCommunityId(), channelUuid = $self.channelUuid

    if self.displayName != chat.name:
      self.displayName = chat.name
      self.displayNameChanged()

    if self.description != chat.description:
      self.description = chat.description
      self.descriptionChanged()

    if self.emoji != chat.emoji:
      self.emoji = chat.emoji
      self.emojiChanged()

    if self.color != community.color:
      self.color = community.color
      self.colorChanged()

    return true

proc setCommunityInfo*(self: LinkPreview, community: CommunityDto): bool =
  if self.previewType == PreviewType.StatusCommunityPreview:
    return self.statusCommunityPreview.setCommunityInfo(community)
  if self.previewType == PreviewType.StatusCommunityChannelPreview:
    return self.statusCommunityChannelPreview.setCommunityInfo(community)
  return false