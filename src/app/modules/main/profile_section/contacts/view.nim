import nimqml

import ../../../shared_models/[user_model]
import ./io_interface

import models/showcase_contact_generic_model
import models/showcase_contact_accounts_model
import models/showcase_contact_social_links_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      contactsModel: Model
      contactsModelVariant: QVariant
      showcaseContactCommunitiesModel: ShowcaseContactGenericModel
      showcaseContactCommunitiesModelVariant: QVariant
      showcaseContactAccountsModel: ShowcaseContactAccountModel
      showcaseContactAccountsModelVariant: QVariant
      showcaseContactCollectiblesModel: ShowcaseContactGenericModel
      showcaseContactCollectiblesModelVariant: QVariant
      showcaseContactAssetsModel: ShowcaseContactGenericModel
      showcaseContactAssetsModelVariant: QVariant
      showcaseContactSocialLinksModel: ShowcaseContactSocialLinkModel
      showcaseContactSocialLinksModelVariant: QVariant


  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.contactsModel = newModel()
    result.contactsModelVariant = newQVariant(result.contactsModel)
    result.showcaseContactCommunitiesModel = newShowcaseContactGenericModel()
    result.showcaseContactCommunitiesModelVariant = newQVariant(result.showcaseContactCommunitiesModel)
    result.showcaseContactAccountsModel = newShowcaseContactAccountModel()
    result.showcaseContactAccountsModelVariant = newQVariant(result.showcaseContactAccountsModel)
    result.showcaseContactCollectiblesModel = newShowcaseContactGenericModel()
    result.showcaseContactCollectiblesModelVariant = newQVariant(result.showcaseContactCollectiblesModel)
    result.showcaseContactAssetsModel = newShowcaseContactGenericModel()
    result.showcaseContactAssetsModelVariant = newQVariant(result.showcaseContactAssetsModel)
    result.showcaseContactSocialLinksModel = newShowcaseContactSocialLinkModel()
    result.showcaseContactSocialLinksModelVariant = newQVariant(result.showcaseContactSocialLinksModel)

  proc load*(self: View) =
    self.delegate.viewDidLoad()
    
  proc contactsModel*(self: View): Model =
    return self.contactsModel

  proc contactsModelChanged(self: View) {.signal.}
  proc getContactsModel(self: View): QVariant {.slot.} =
    return self.contactsModelVariant
  QtProperty[QVariant] contactsModel:
    read = getContactsModel
    notify = contactsModelChanged

  proc contactInfoRequestFinished(self: View, publicKey: string, ok: bool) {.signal.}

  proc sendContactRequest*(self: View, publicKey: string, message: string) {.slot.} =
    self.delegate.sendContactRequest(publicKey, message)

  proc switchToOrCreateOneToOneChat*(self: View, publicKey: string) {.slot.} =
    self.delegate.switchToOrCreateOneToOneChat(publicKey)

  proc acceptContactRequest*(self: View, publicKey: string, contactRequestId: string) {.slot.} =
    self.delegate.acceptContactRequest(publicKey, contactRequestId)

  proc dismissContactRequest*(self: View, publicKey: string, contactRequestId: string) {.slot.} =
    self.delegate.dismissContactRequest(publicKey, contactRequestId)

  proc getLatestContactRequestForContactAsJson*(self: View, publicKey: string): string {.slot.} =
    self.delegate.getLatestContactRequestForContactAsJson(publicKey)

  proc changeContactNickname*(self: View, publicKey: string, nickname: string) {.slot.} =
    self.delegate.changeContactNickname(publicKey, nickname)

  proc unblockContact*(self: View, publicKey: string) {.slot.} =
    self.delegate.unblockContact(publicKey)

  proc blockContact*(self: View, publicKey: string) {.slot.} =
    self.delegate.blockContact(publicKey)

  proc removeContact*(self: View, publicKey: string) {.slot.} =
    self.delegate.removeContact(publicKey)

  proc markAsTrusted*(self: View, publicKey: string) {.slot.} =
    self.delegate.markAsTrusted(publicKey)

  proc markUntrustworthy*(self: View, publicKey: string) {.slot.} =
    self.delegate.markUntrustworthy(publicKey)

  proc removeTrustStatus*(self: View, publicKey: string) {.slot.} =
    self.delegate.removeTrustStatus(publicKey)

  proc trustStatusRemoved*(self: View, publicKey: string) {.signal.}

  proc contactRemoved*(self: View, displayName: string, theyRemovedUs: bool) {.signal.}

  proc shareUserUrlWithData*(self: View, pubkey: string): string {.slot.} =
    return self.delegate.shareUserUrlWithData(pubkey)

  proc shareUserUrlWithChatKey*(self: View, pubkey: string): string {.slot.} =
    return self.delegate.shareUserUrlWithChatKey(pubkey)

  proc shareUserUrlWithENS*(self: View, pubkey: string): string {.slot.} =
    return self.delegate.shareUserUrlWithENS(pubkey)

  proc populateContactDetails*(self: View, publicKey: string) {.slot.} =
    self.delegate.addOrUpdateContactItem(publicKey)

  proc requestContactInfo*(self: View, publicKey: string) {.slot.} =
    self.delegate.requestContactInfo(publicKey)

  proc onContactInfoRequestFinished*(self: View, publicKey: string, ok: bool) {.slot.} =
    self.contactInfoRequestFinished(publicKey, ok)

  # Showcase models for a contact
  proc getShowcaseContactCommunitiesModel(self: View): QVariant {.slot.} =
    return self.showcaseContactCommunitiesModelVariant
  QtProperty[QVariant] showcaseContactCommunitiesModel:
    read = getShowcaseContactCommunitiesModel

  proc getShowcaseContactAccountsModel(self: View): QVariant {.slot.} =
    return self.showcaseContactAccountsModelVariant
  QtProperty[QVariant] showcaseContactAccountsModel:
    read = getShowcaseContactAccountsModel

  proc getShowcaseContactCollectiblesModel(self: View): QVariant {.slot.} =
    return self.showcaseContactCollectiblesModelVariant
  QtProperty[QVariant] showcaseContactCollectiblesModel:
    read = getShowcaseContactCollectiblesModel

  proc getShowcaseContactAssetsModel(self: View): QVariant {.slot.} =
    return self.showcaseContactAssetsModelVariant
  QtProperty[QVariant] showcaseContactAssetsModel:
    read = getShowcaseContactAssetsModel

  proc getShowcaseContactSocialLinksModel(self: View): QVariant {.slot.} =
    return self.showcaseContactSocialLinksModelVariant
  QtProperty[QVariant] showcaseContactSocialLinksModel:
    read = getShowcaseContactSocialLinksModel

  # Support models for showcase for a contact
  proc showcaseCollectiblesModelChanged*(self: View) {.signal.}
  proc getShowcaseCollectiblesModel(self: View): QVariant {.slot.} =
    return self.delegate.getShowcaseCollectiblesModel()
  QtProperty[QVariant] showcaseCollectiblesModel:
    read = getShowcaseCollectiblesModel
    notify = showcaseCollectiblesModelChanged

  proc showcaseForAContactLoadingChanged*(self: View) {.signal.}
  proc emitShowcaseForAContactLoadingChangedSignal*(self: View) =
    self.showcaseForAContactLoadingChanged()
  proc isShowcaseForAContactLoading*(self: View): bool {.slot.} =
    return self.delegate.isShowcaseForAContactLoading()
  QtProperty[bool] showcaseForAContactLoading:
    read = isShowcaseForAContactLoading
    notify = showcaseForAContactLoadingChanged

  proc fetchProfileShowcaseAccountsByAddress*(self: View, address: string) {.slot.} =
    self.delegate.fetchProfileShowcaseAccountsByAddress(address)

  proc profileShowcaseAccountsByAddressFetched*(self: View, accounts: string) {.signal.}
  proc emitProfileShowcaseAccountsByAddressFetchedSignal*(self: View, accounts: string) =
    self.profileShowcaseAccountsByAddressFetched(accounts)

  proc requestProfileShowcase(self: View, publicKey: string) {.slot.} =
    self.delegate.requestProfileShowcase(publicKey)

  proc clearShowcaseModels*(self: View) {.slot.} =
    self.showcaseContactCommunitiesModel.clear()
    self.showcaseContactAccountsModel.clear()
    self.showcaseContactCollectiblesModel.clear()
    self.showcaseContactAssetsModel.clear()
    self.showcaseContactSocialLinksModel.clear()

  proc loadProfileShowcaseContactCommunities*(self: View, items: seq[ShowcaseContactGenericItem]) =
    self.showcaseContactCommunitiesModel.setItems(items)

  proc loadProfileShowcaseContactAccounts*(self: View, items: seq[ShowcaseContactAccountItem]) =
    self.showcaseContactAccountsModel.setItems(items)

  proc loadProfileShowcaseContactCollectibles*(self: View, items: seq[ShowcaseContactGenericItem]) =
    self.showcaseContactCollectiblesModel.setItems(items)

  proc loadProfileShowcaseContactAssets*(self: View, items: seq[ShowcaseContactGenericItem]) =
    self.showcaseContactAssetsModel.setItems(items)

  proc loadProfileShowcaseContactSocialLinks*(self: View, items: seq[ShowcaseContactSocialLinkItem]) =
    self.showcaseContactSocialLinksModel.setItems(items)

  proc delete*(self: View) =
    self.QObject.delete

