import app/modules/shared_models/model_utils
import nimqml, std/strformat, tables, sequtils, sets
import ./link_preview_item
import ../../../app_service/service/message/dto/link_preview
import ../../../app_service/service/message/utils/link_preview_utils
import ../../../app_service/service/message/dto/standard_link_preview
import ../../../app_service/service/message/dto/status_contact_link_preview
import ../../../app_service/service/message/dto/status_community_link_preview
import ../../../app_service/service/message/dto/status_community_channel_link_preview
import ../../../app_service/service/contacts/dto/contact_details
import ../../../app_service/service/community/dto/community

type
  ModelRole {.pure.} = enum
    Url = UserRole + 1
    Unfurled
    Immutable
    IsLocalData
    LoadingLocalData
    Empty
    PreviewType
    # Standard unfurled link (oembed, opengraph, image)
    StandardPreview
    StandardPreviewThumbnail
    # Status contact
    StatusContactPreview
    StatusContactPreviewThumbnail
    # Status community
    StatusCommunityPreview
    StatusCommunityPreviewIcon
    StatusCommunityPreviewBanner
    # Status channel
    StatusCommunityChannelPreview
    # NOTE: I know "CommunityChannelCommunity" doesn't sound good, 
    # and we could use existing `StatusCommunityPreview` role for this,
    # but I decided no to mess things around. So there we have it:
    StatusCommunityChannelCommunityPreview 
    StatusCommunityChannelCommunityPreviewIcon
    StatusCommunityChannelCommunityPreviewBanner

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete*(self: Model)
  proc setup(self: Model)
  proc newLinkPreviewModel*(linkPreviews: seq[LinkPreview] = @[]): Model =
    new(result, delete)
    result.setup
    for linkPreview in linkPreviews:
      var item = Item()
      item.unfurled = true
      item.linkPreview = linkPreview
      result.items.add(item)

  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  proc countChanged(self: Model) {.signal.}

  proc getCount*(self: Model): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Url.int:"url",
      ModelRole.Unfurled.int:"unfurled",
      ModelRole.Immutable.int:"immutable",
      ModelRole.IsLocalData.int:"isLocalData",
      ModelRole.LoadingLocalData.int:"loadingLocalData",
      ModelRole.Empty.int:"empty",
      ModelRole.PreviewType.int:"previewType",
      # Standard
      ModelRole.StandardPreview.int:"standardPreview",
      ModelRole.StandardPreviewThumbnail.int:"standardPreviewThumbnail",
      # Contact
      ModelRole.StatusContactPreview.int:"statusContactPreview",
      ModelRole.StatusContactPreviewThumbnail.int:"statusContactPreviewThumbnail",
      # Community
      ModelRole.StatusCommunityPreview.int:"statusCommunityPreview",
      ModelRole.StatusCommunityPreviewIcon.int:"statusCommunityPreviewIcon",
      ModelRole.StatusCommunityPreviewBanner.int:"statusCommunityPreviewBanner",
      # Channel
      ModelRole.StatusCommunityChannelPreview.int:"statusCommunityChannelPreview",
      ModelRole.StatusCommunityChannelCommunityPreview.int:"statusCommunityChannelCommunityPreview",
      ModelRole.StatusCommunityChannelCommunityPreviewIcon.int:"statusCommunityChannelCommunityPreviewIcon",
      ModelRole.StatusCommunityChannelCommunityPreviewBanner.int:"statusCommunityChannelCommunityPreviewBanner",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Url:
      result = newQVariant(item.linkPreview.url)
    of ModelRole.Unfurled:
      result = newQVariant(item.unfurled)
    of ModelRole.Immutable:
      result = newQVariant(item.immutable)
    of ModelRole.IsLocalData:
      result = newQVariant(item.isLocalData)
    of ModelRole.LoadingLocalData:
      result = newQVariant(item.loadingLocalData)
    of ModelRole.Empty:
      result = newQVariant(item.linkPreview.empty()) 
    of ModelRole.PreviewType:
      result = newQVariant(item.linkPreview.previewType.int)
    of ModelRole.StandardPreview:
      if item.linkPreview.standardPreview != nil:
        result = newQVariant(item.linkPreview.standardPreview)
    of ModelRole.StandardPreviewThumbnail:
      if item.linkPreview.standardPreview != nil:
        result = newQVariant(item.linkPreview.standardPreview.getThumbnail())
    of ModelRole.StatusContactPreview:
      if item.linkPreview.statusContactPreview != nil:
        result = newQVariant(item.linkPreview.statusContactPreview)
    of ModelRole.StatusContactPreviewThumbnail:
      if item.linkPreview.statusContactPreview != nil:
        result = newQVariant(item.linkPreview.statusContactPreview.getIcon())
    of ModelRole.StatusCommunityPreview:
      if item.linkPreview.statusCommunityPreview != nil:
        result = newQVariant(item.linkPreview.statusCommunityPreview)
    of ModelRole.StatusCommunityPreviewIcon:
      if item.linkPreview.statusCommunityPreview != nil:
        result = newQVariant(item.linkPreview.statusCommunityPreview.getIcon())
    of ModelRole.StatusCommunityPreviewBanner:
      if item.linkPreview.statusCommunityPreview != nil:
        result = newQVariant(item.linkPreview.statusCommunityPreview.getBanner())
    of ModelRole.StatusCommunityChannelPreview:
      if item.linkPreview.statusCommunityChannelPreview != nil:
        result = newQVariant(item.linkPreview.statusCommunityChannelPreview)
    of ModelRole.StatusCommunityChannelCommunityPreview:
      if (let community = item.linkPreview.getChannelCommunity(); community) != nil:
        result = newQVariant(community)
    of ModelRole.StatusCommunityChannelCommunityPreviewIcon:
      if (let community = item.linkPreview.getChannelCommunity(); community) != nil:
        result = newQVariant(community.getIcon())
    of ModelRole.StatusCommunityChannelCommunityPreviewBanner:
      if (let community = item.linkPreview.getChannelCommunity(); community) != nil:
        result = newQVariant(community.getBanner())
    else:
      result = newQVariant()

  proc removeItemWithIndex(self: Model, ind: int) =
    if(ind < 0 or ind >= self.items.len):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, ind, ind)
    self.items.delete(ind)
    self.endRemoveRows()

  proc getItemAtIndex*(self: Model, index: int): Item =
    if(index < 0 or index >= self.items.len):
      return
    return self.items[index]
  
  proc findUrlIndex(self: Model, url: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].linkPreview.url == url):
        return i
    return -1

  proc previewDataRoles(self: Model): seq[int] =
    return @[
      ModelRole.Unfurled.int,
      ModelRole.Empty.int,
      ModelRole.PreviewType.int,
      ModelRole.StandardPreview.int,
      ModelRole.StandardPreviewThumbnail.int,
      ModelRole.StatusContactPreview.int,
      ModelRole.StatusContactPreviewThumbnail.int,
      ModelRole.StatusCommunityPreview.int,
      ModelRole.StatusCommunityPreviewIcon.int,
      ModelRole.StatusCommunityPreviewBanner.int,
      ModelRole.StatusCommunityChannelPreview.int,
      ModelRole.StatusCommunityChannelCommunityPreview.int,
      ModelRole.StatusCommunityChannelCommunityPreviewIcon.int,
      ModelRole.StatusCommunityChannelCommunityPreviewBanner.int,
    ]

  proc immutablePreviewDataRoles(self: Model): seq[int] =
    return @[
      ModelRole.Unfurled.int,
      ModelRole.Immutable.int,
    ]

  proc moveRow(self: Model, fromRow: int, to: int) =
    if fromRow == to:
      return
    if fromRow < 0 or fromRow >= self.items.len:
      return
    if to < 0 or to >= self.items.len:
      return

    let sourceIndex = newQModelIndex()
    defer: sourceIndex.delete
    let destIndex = newQModelIndex()
    defer: destIndex.delete

    let currentItem = self.items[fromRow]
    self.beginMoveRows(sourceIndex, fromRow, fromRow, destIndex, to)
    self.items.delete(fromRow)
    self.items.insert(currentItem, to)
    self.endMoveRows()

  proc updateLinkPreviews*(self: Model, linkPreviews: Table[string, LinkPreview]) =
    for row, item in self.items:
      if not linkPreviews.hasKey(item.linkPreview.url) or item.immutable:
        continue
      item.unfurled = true
      item.linkPreview = linkPreviews[item.linkPreview.url]
      notifyRangeRolesChanged(row, row, self.previewDataRoles())

  proc setUrls*(self: Model, urls: seq[string]) =
    var itemsToInsert: seq[Item]
    var indexesToRemove: seq[int]

    #remove
    for i in 0 ..< self.items.len:
      if not urls.anyIt(it == self.items[i].linkPreview.url):
        indexesToRemove.add(i)

    while indexesToRemove.len > 0:
      let index = pop(indexesToRemove)
      self.removeItemWithIndex(index)

    # Move or insert
    for i in 0 ..< urls.len:
      let url = urls[i]
      let index = self.findUrlIndex(url)
      if index >= 0:
        self.moveRow(index, i)
        continue

      let linkPreview = initLinkPreview(url)
      var item = Item()
      item.unfurled = false
      item.immutable = false
      item.isLocalData = false
      item.loadingLocalData = false
      item.linkPreview = linkPreview

      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete
      self.beginInsertRows(parentModelIndex, i, i)
      self.items.insert(item, i)
      self.endInsertRows()
      
    self.countChanged()

  proc clearItems*(self: Model) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()

  proc removePreviewData*(self: Model, index: int) {.slot.} =
    if index < 0 or index >= self.items.len:
      return

    self.items[index].markAsImmutable()
    notifyRangeRolesChanged(index, index, self.immutablePreviewDataRoles())

  proc removeAllPreviewData*(self: Model) {.slot.} =
    for i in 0 ..< self.items.len:
      self.items[i].markAsImmutable()

    if self.items.len > 0:
      notifyRangeRolesChanged(0, self.items.len - 1, self.immutablePreviewDataRoles())
      
  proc getLinkPreviewType*(self: Model, url: string): int {.slot.} =
    let index = self.findUrlIndex(url)
    if index == -1:
      return PreviewType.NoPreview.int

    return self.items[index].linkPreview.previewType.int

  proc getUnfuledLinkPreviews*(self: Model): seq[LinkPreview] =
    result = @[]
    for item in self.items:
      if item.unfurled and not item.linkPreview.empty():
        result.add(item.linkPreview)

  proc getLinks*(self: Model): seq[string] =
    result = @[]
    for item in self.items:
      result.add(item.linkPreview.url)


  proc getContactIds*(self: Model): HashSet[string] =
    for item in self.items:
      let contactId = item.linkPreview.getContactId()
      if contactId != "":
        result.incl(contactId)

  proc getCommunityLinks*(self: Model): Table[string, string] =
    for item in self.items:
      let communityId = item.linkPreview.getCommunityId()
      if communityId != "":
        result[communityId] = item.linkPreview.url

  proc setItemLoadingLocalData(self: Model, row: int, value: bool) =
    let ind = row
    updateRolesAndNotify:
      updateRoleWithValue(loadingLocalData, value)

  proc setItemIsLocalData(self: Model, row: int, item: Item) =
    if item.isLocalData:
      return
    let ind = row
    updateRolesAndNotify:
      updateRoleWithValue(isLocalData, true)
      updateRoleWithValue(loadingLocalData, false)

  proc setContactInfo*(self: Model, contactDetails: ContactDetails) =
    for row, item in self.items:
      if item.linkPreview.setContactInfo(contactDetails):
        self.setItemIsLocalData(row, item)

  proc setCommunityInfo*(self: Model, community: CommunityDto) =
    for row, item in self.items:
      if item.linkPreview.setCommunityInfo(community):
        self.setItemIsLocalData(row, item)

  proc onContactDataRequested*(self: Model, contactId: string) =
    for row, item in self.items:
      if item.linkPreview.getContactId() == contactId:
        self.setItemLoadingLocalData(row, true)

  proc onCommunityInfoRequested*(self: Model, communityId: string) =
    for row, item in self.items:
      if item.linkPreview.getCommunityId() == communityId:
        self.setItemLoadingLocalData(row, true)

  proc delete*(self: Model) = 
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
