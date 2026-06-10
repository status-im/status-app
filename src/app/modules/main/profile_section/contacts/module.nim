import nimqml, chronicles

import io_interface, view, controller, json
import ../../../shared_models/user_item
import ../../../shared_models/user_model
import ../io_interface as delegate_interface

import ../../../../core/eventemitter
import app_service/common/types
import app_service/common/utils as utils
import app_service/service/contacts/dto/contacts as contacts_dto
import app_service/service/contacts/service as contacts_service
import app_service/service/chat/service as chat_service
import app_service/service/network/service as network_service

import app/modules/shared_modules/collectibles/controller as collectiblesc
import backend/collectibles as backend_collectibles
import app_service/service/contacts/dto/profile_showcase

import models/showcase_contact_generic_model
import models/showcase_contact_accounts_model
import models/showcase_contact_social_links_model

export io_interface

const COLLECTIBLES_CACHE_AGE_SECONDS = 60

logScope:
  topics = "profile-section-contacts-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: controller.Controller
    collectiblesController: collectiblesc.Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    showcasePublicKey: string
    showcaseForAContactLoading: bool

proc newModule*(delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  contactsService: contacts_service.Service,
  chatService: chat_service.Service,
  networkService: network_service.Service):
  Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, contactsService, chatService, networkService)
  result.collectiblesController = collectiblesc.newController(
    requestId = int32(backend_collectibles.CollectiblesRequestID.ProfileShowcase),
    loadType = collectiblesc.LoadType.AutoLoadSingleUpdate,
    networkService = networkService,
    events = events,
    fetchCriteria = backend_collectibles.FetchCriteria(
      fetchType: backend_collectibles.FetchType.FetchIfCacheOld,
      maxCacheAgeSeconds: COLLECTIBLES_CACHE_AGE_SECONDS
    )
  )
  result.moduleLoaded = false
  result.showcaseForAContactLoading = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.collectiblesController.delete

proc createItemFromPublicKey(self: Module, publicKey: string): UserItem =
  let contactDetails = self.controller.getContactDetails(publicKey)
  return createItemFromDto(
    contactDetails,
    toOnlineStatus(self.controller.getStatusForContactWithId(publicKey).statusType),
    contactDetails.dto.contactRequestState,
  )

proc buildModel(self: Module, model: Model, group: ContactsGroup) =
  var items: seq[UserItem]
  let contacts =  self.controller.getContacts(group)
  for c in contacts:
    items.add(self.createItemFromPublicKey(c.id))

  model.addItems(items)

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.contactsModuleDidLoad()

method onContactsLoaded*(self: Module) =
  self.buildModel(self.view.contactsModel(), ContactsGroup.AllKnownContacts)

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method sendContactRequest*(self: Module, publicKey: string, message: string) =
  self.controller.sendContactRequest(publicKey, message)

method acceptContactRequest*(self: Module, publicKey: string, contactRequestId: string) =
  self.controller.acceptContactRequest(publicKey, contactRequestId)

method dismissContactRequest*(self: Module, publicKey: string, contactRequestId: string) =
  self.controller.dismissContactRequest(publicKey, contactRequestId)

method getLatestContactRequestForContactAsJson*(self: Module, publicKey: string): string =
  let contactRequest = self.controller.getLatestContactRequestForContact(publicKey)
  let jsonObj = %* {
    "id": contactRequest.id,
    "from": contactRequest.from,
    "clock": contactRequest.clock,
    "text": contactRequest.text,
    "contactRequestState": contactRequest.contactRequestState.int,
  }
  return $jsonObj

method switchToOrCreateOneToOneChat*(self: Module, publicKey: string) =
  self.controller.switchToOrCreateOneToOneChat(publicKey)

method unblockContact*(self: Module, publicKey: string) =
  self.controller.unblockContact(publicKey)

method blockContact*(self: Module, publicKey: string) =
  self.controller.blockContact(publicKey)

method removeContact*(self: Module, publicKey: string) =
  self.controller.removeContact(publicKey)

method changeContactNickname*(self: Module, publicKey: string, nickname: string) =
  self.controller.changeContactNickname(publicKey, nickname)

method addOrUpdateContactItem*(self: Module, publicKey: string) =
  let ind = self.view.contactsModel().findIndexByPubKey(publicKey)
  let item = self.createItemFromPublicKey(publicKey)
  if ind == -1:
    self.view.contactsModel().addItem(item)
    return
  self.view.contactsModel().updateItem(
    publicKey,
    item.displayName,
    item.ensName,
    item.isEnsVerified,
    item.localNickname,
    item.alias,
    item.icon,
    item.trustStatus,
    item.onlineStatus,
    item.isContact,
    item.isBlocked,
    item.contactRequest,
    item.lastUpdated,
    item.lastUpdatedLocally,
    item.bio,
    item.thumbnailImage,
    item.largeImage,
    item.isContactRequestReceived,
    item.isContactRequestSent,
    item.isRemoved,
  )

method onContactRemoved*(self: Module, publicKey: string, displayName: string, theyRemovedUs: bool) =
  let contactDetails = self.controller.getContactDetails(publicKey)
  self.view.contactRemoved(displayName, theyRemovedUs)

method contactsStatusUpdated*(self: Module, statusUpdates: seq[StatusUpdateDto]) =
  for s in statusUpdates:
    self.view.contactsModel().setOnlineStatus(s.publicKey, toOnlineStatus(s.statusType))

method contactNicknameChanged*(self: Module, publicKey: string) =
  let contactDetails = self.controller.getContactDetails(publicKey)

  self.view.contactsModel().setName(
    publicKey,
    contactDetails.dto.displayName,
    contactDetails.dto.name,
    contactDetails.dto.localNickname,
  )

method contactTrustStatusChanged*(self: Module, publicKey: string, trustStatus: TrustStatus) =
  self.view.contactsModel().updateTrustStatus(publicKey, trustStatus)

method onTrustStatusRemoved(self: Module, publicKey: string) =
  self.view.trustStatusRemoved(publicKey)

method markAsTrusted*(self: Module, publicKey: string): void =
  self.controller.markAsTrusted(publicKey)

method markUntrustworthy*(self: Module, publicKey: string): void =
  self.controller.markUntrustworthy(publicKey)

method removeTrustStatus*(self: Module, publicKey: string): void =
  self.controller.removeTrustStatus(publicKey)

method requestContactInfo*(self: Module, publicKey: string) =
  self.controller.requestContactInfo(publicKey)

method onContactInfoRequestFinished*(self: Module, publicKey: string, ok: bool) =
  if ok:
    self.addOrUpdateContactItem(publicKey)
  self.view.onContactInfoRequestFinished(publicKey, ok)

method shareUserUrlWithData*(self: Module, pubkey: string): string =
  return self.controller.shareUserUrlWithData(pubkey)

method shareUserUrlWithChatKey*(self: Module, pubkey: string): string =
  return self.controller.shareUserUrlWithChatKey(pubkey)

method shareUserUrlWithENS*(self: Module, pubkey: string): string =
  return self.controller.shareUserUrlWithENS(pubkey)

# Profile showcase for a contanct related stuff
method requestProfileShowcase*(self: Module, publicKey: string) =
  if self.showcasePublicKey != publicKey:
    self.view.clearShowcaseModels()
    self.showcasePublicKey = publicKey

  self.showcaseForAContactLoading = true
  self.view.emitShowcaseForAContactLoadingChangedSignal()
  self.controller.requestProfileShowcaseForContact(publicKey, false)

method onProfileShowcaseUpdated(self: Module, publicKey: string) =
  if self.showcasePublicKey == publicKey:
    self.controller.requestProfileShowcaseForContact(publicKey, true)

method loadProfileShowcase(self: Module, profileShowcase: ProfileShowcaseDto, validated: bool) =
  if self.showcasePublicKey != profileShowcase.contactId:
    warn "Got profile showcase for wrong contact id"
    return

  var communityItems: seq[ShowcaseContactGenericItem] = @[]
  for community in profileShowcase.communities:
    if not validated or community.membershipStatus == ProfileShowcaseMembershipStatus.ProvenMember:
      communityItems.add(ShowcaseContactGenericItem(
        showcaseKey: community.communityId,
        showcasePosition: community.order
      ))
  self.view.loadProfileShowcaseContactCommunities(communityItems)

  var accountItems: seq[ShowcaseContactAccountItem] = @[]
  var accountAddresses: seq[string] = @[]
  for account in profileShowcase.accounts:
    accountItems.add(ShowcaseContactAccountItem(
      address: account.address,
      name: account.name,
      emoji: account.emoji,
      colorId: account.colorId,
      showcasePosition: account.order
    ))
    accountAddresses.add(account.address)
  self.view.loadProfileShowcaseContactAccounts(accountItems)

  var collectibleItems: seq[ShowcaseContactGenericItem] = @[]
  var collectibleChainIds: seq[int] = @[]
  for collectible in profileShowcase.collectibles:
    collectibleItems.add(ShowcaseContactGenericItem(
      showcaseKey: collectible.toCombinedCollectibleId(),
      showcasePosition: collectible.order
    ))
    if not collectibleChainIds.contains(collectible.chainId):
      collectibleChainIds.add(collectible.chainId)
  self.view.loadProfileShowcaseContactCollectibles(collectibleItems)

  var assetItems: seq[ShowcaseContactGenericItem] = @[]
  for token in profileShowcase.verifiedTokens:
    assetItems.add(ShowcaseContactGenericItem(
      showcaseKey: token.symbol,
      showcasePosition: token.order
    ))
  for token in profileShowcase.unverifiedTokens:
    assetItems.add(ShowcaseContactGenericItem(
      showcaseKey: token.toCombinedTokenId(),
      showcasePosition: token.order
    ))
  self.view.loadProfileShowcaseContactAssets(assetItems)

  var socialLinkItems: seq[ShowcaseContactSocialLinkItem] = @[]
  for socialLink in profileShowcase.socialLinks:
    socialLinkItems.add(ShowcaseContactSocialLinkItem(
      url: socialLink.url,
      text: socialLink.text,
      showcasePosition: socialLink.order
    ))
  self.view.loadProfileShowcaseContactSocialLinks(socialLinkItems)

  if validated:
    self.showcaseForAContactLoading = false
    self.view.emitShowcaseForAContactLoadingChangedSignal()
  else:
    let enabledChainIds = self.controller.getEnabledChainIds()

    let combinedNetworks = utils.intersectSeqs(collectibleChainIds, enabledChainIds)
    self.collectiblesController.setFilterAddressesAndChains(accountAddresses, combinedNetworks)
    self.controller.requestProfileShowcaseForContact(self.showcasePublicKey, true)

method fetchProfileShowcaseAccountsByAddress*(self: Module, address: string) =
  self.controller.fetchProfileShowcaseAccountsByAddress(address)

method onProfileShowcaseAccountsByAddressFetched*(self: Module, accounts: seq[ProfileShowcaseAccount]) =
  let jsonObj = % accounts
  self.view.emitProfileShowcaseAccountsByAddressFetchedSignal($jsonObj)

method getShowcaseCollectiblesModel*(self: Module): QVariant =
  return self.collectiblesController.getModelAsVariant()

method isShowcaseForAContactLoading*(self: Module): bool =
  return self.showcaseForAContactLoading
