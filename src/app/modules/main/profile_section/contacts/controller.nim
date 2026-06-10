import io_interface

import ../../../../core/eventemitter
import app_service/service/contacts/service as contacts_service
import app_service/service/chat/service as chat_service
import app_service/service/network/service as network_service
import app_service/service/message/dto/message as message_dto

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    contactsService: contacts_service.Service
    chatService: chat_service.Service
    networkService: network_service.Service

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  contactsService: contacts_service.Service,
  chatService: chat_service.Service,
  networkService: network_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.contactsService = contactsService
  result.chatService = chatService
  result.networkService = networkService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_CONTACTS_LOADED) do(e:Args):
    self.delegate.onContactsLoaded()

  self.events.on(SIGNAL_CONTACT_ADDED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.addOrUpdateContactItem(args.contactId)

  self.events.on(SIGNAL_CONTACT_BLOCKED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.addOrUpdateContactItem(args.contactId)

  self.events.on(SIGNAL_CONTACT_UNBLOCKED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.addOrUpdateContactItem(args.contactId)

  self.events.on(SIGNAL_CONTACT_REMOVED) do(e: Args):
    var args = ContactRemovedArgs(e)
    self.delegate.addOrUpdateContactItem(args.contactId)
    self.delegate.onContactRemoved(args.contactId, args.displayName, args.theyRemovedUs)

  self.events.on(SIGNAL_CONTACT_NICKNAME_CHANGED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.contactNicknameChanged(args.contactId)

  self.events.on(SIGNAL_CONTACT_UNTRUSTWORTHY) do(e: Args):
    var args = TrustArgs(e)
    self.delegate.contactTrustStatusChanged(args.publicKey, args.trustStatus)

  self.events.on(SIGNAL_CONTACT_TRUSTED) do(e: Args):
    var args = TrustArgs(e)
    self.delegate.contactTrustStatusChanged(args.publicKey, args.trustStatus)

  self.events.on(SIGNAL_REMOVED_TRUST_STATUS) do(e: Args):
    var args = TrustArgs(e)
    self.delegate.contactTrustStatusChanged(args.publicKey, args.trustStatus)
    self.delegate.onTrustStatusRemoved(args.publicKey)
    
  self.events.on(SIGNAL_CONTACT_UPDATED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.addOrUpdateContactItem(args.contactId)

  self.events.on(SIGNAL_CONTACTS_STATUS_UPDATED) do(e: Args):
    let args = ContactsStatusUpdatedArgs(e)
    self.delegate.contactsStatusUpdated(args.statusUpdates)

  self.events.on(SIGNAL_CONTACT_INFO_REQUEST_FINISHED) do(e: Args):
    let args = ContactInfoRequestArgs(e)
    self.delegate.onContactInfoRequestFinished(args.publicKey, args.ok)

  self.events.on(SIGNAL_CONTACT_PROFILE_SHOWCASE_UPDATED) do(e: Args):
    let args = ProfileShowcaseContactIdArgs(e)
    self.delegate.onProfileShowcaseUpdated(args.contactId)

  self.events.on(SIGNAL_CONTACT_PROFILE_SHOWCASE_LOADED) do(e: Args):
    let args = ProfileShowcaseForContactArgs(e)
    self.delegate.loadProfileShowcase(args.profileShowcase, args.validated)

  self.events.on(SIGNAL_CONTACT_SHOWCASE_ACCOUNTS_BY_ADDRESS_FETCHED) do(e: Args):
    let args = ProfileShowcaseForContactArgs(e)
    self.delegate.onProfileShowcaseAccountsByAddressFetched(args.profileShowcase.accounts)

proc getContacts*(self: Controller, group: ContactsGroup): seq[ContactsDto] =
  return self.contactsService.getContactsByGroup(group)

proc getContact*(self: Controller, id: string): ContactsDto =
  return self.contactsService.getContactById(id)

proc getContactNameAndImage*(self: Controller, contactId: string):
    tuple[name: string, image: string, largeImage: string] =
  return self.contactsService.getContactNameAndImage(contactId)

proc getContactDetails*(self: Controller, contactId: string): ContactDetails =
  return self.contactsService.getContactDetails(contactId)

proc unblockContact*(self: Controller, publicKey: string) =
  self.contactsService.unblockContact(publicKey)

proc blockContact*(self: Controller, publicKey: string) =
  self.contactsService.blockContact(publicKey)

proc removeContact*(self: Controller, publicKey: string) =
  self.contactsService.removeContact(publicKey)

proc changeContactNickname*(self: Controller, publicKey: string, nickname: string) =
  self.contactsService.changeContactNickname(publicKey, nickname)

proc sendContactRequest*(self: Controller, publicKey: string, message: string) =
  self.contactsService.sendContactRequest(publicKey, message)

proc acceptContactRequest*(self: Controller, publicKey: string, contactRequestId: string) =
  self.contactsService.acceptContactRequest(publicKey, contactRequestId)

proc dismissContactRequest*(self: Controller, publicKey: string, contactRequestId: string) =
  self.contactsService.dismissContactRequest(publicKey, contactRequestId)

proc getLatestContactRequestForContact*(self: Controller, publicKey: string): message_dto.MessageDto =
  self.contactsService.getLatestContactRequestForContact(publicKey)

proc switchToOrCreateOneToOneChat*(self: Controller, chatId: string) =
  self.chatService.switchToOrCreateOneToOneChat(chatId, "")

proc markAsTrusted*(self: Controller, publicKey: string) =
  self.contactsService.markAsTrusted(publicKey)

proc markUntrustworthy*(self: Controller, publicKey: string) =
  self.contactsService.markUntrustworthy(publicKey)

proc removeTrustStatus*(self: Controller, publicKey: string) =
  self.contactsService.removeTrustStatus(publicKey)

proc getStatusForContactWithId*(self: Controller, publicKey: string): StatusUpdateDto =
  return self.contactsService.getStatusForContactWithId(publicKey)

proc requestContactInfo*(self: Controller, publicKey: string) =
  self.contactsService.requestContactInfo(publicKey)

proc shareUserUrlWithData*(self: Controller, pubkey: string): string =
  self.contactsService.shareUserUrlWithData(pubkey)

proc shareUserUrlWithChatKey*(self: Controller, pubkey: string): string =
  self.contactsService.shareUserUrlWithChatKey(pubkey)

proc shareUserUrlWithENS*(self: Controller, pubkey: string): string =
  self.contactsService.shareUserUrlWithENS(pubkey)

proc requestProfileShowcaseForContact*(self: Controller, contactId: string, validated: bool) =
  self.contactsService.requestProfileShowcaseForContact(contactId, validated)

proc fetchProfileShowcaseAccountsByAddress*(self: Controller, address: string) =
  self.contactsService.fetchProfileShowcaseAccountsByAddress(address)

proc getEnabledChainIds*(self: Controller): seq[int] =
  return self.networkService.getEnabledChainIds()
