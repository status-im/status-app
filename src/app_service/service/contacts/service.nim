import nimqml, tables, json, sequtils, std/strformat, chronicles, strutils, times, std/times

import app/global/global_singleton
import app/core/signals/types
import app/core/eventemitter
import app/core/tasks/[qt, threadpool]

import ../../common/types as common_types
import ../../common/conversion as service_conversion
import ../../common/activity_center

import ../settings/service as settings_service
import ../network/service as network_service
import ../message/dto/message as message_dto
import ../visual_identity/service as procs_from_visual_identity_service

import ./dto/contacts as contacts_dto
import ./dto/status_update as status_update_dto
import ./dto/contact_details
import ./dto/profile_showcase

import backend/contacts as status_contacts
import backend/accounts as status_accounts
import backend/shared_urls as status_shared_urls

export contacts_dto, status_update_dto, contact_details

const PK_LENGTH_0X_INCLUDED = 132

include async_tasks

logScope:
  topics = "contacts-service"

type
  ContactArgs* = ref object of Args
    contactId*: string
    fromBackup*: bool

  TrustArgs* = ref object of Args
    publicKey*: string
    trustStatus*: TrustStatus

  ResolvedContactArgs* = ref object of Args
    pubkey*: string
    address*: string
    uuid*: string
    reason*: string

  ContactsStatusUpdatedArgs* = ref object of Args
    statusUpdates*: seq[StatusUpdateDto]

  ContactInfoRequestArgs* = ref object of Args
    publicKey*: string
    ok*: bool

  AppendChatMessagesArgs* = ref object of Args
    chatId*: string
    messages*: JsonNode

  ProfileShowcaseForContactArgs* = ref object of Args
    profileShowcase*: ProfileShowcaseDto
    validated*: bool

  ProfileShowcaseContactIdArgs* = ref object of Args
    contactId*: string

# Signals which may be emitted by this service:
const SIGNAL_ENS_RESOLVED* = "ensResolved"
const SIGNAL_CONTACTS_LOADED* = "contactsLoaded"
const SIGNAL_CONTACT_ADDED* = "contactAdded"
const SIGNAL_CONTACT_BLOCKED* = "contactBlocked"
const SIGNAL_CONTACT_UNBLOCKED* = "contactUnblocked"
const SIGNAL_CONTACT_REMOVED* = "contactRemoved"
const SIGNAL_CONTACT_NICKNAME_CHANGED* = "contactNicknameChanged"
const SIGNAL_CONTACTS_STATUS_UPDATED* = "contactsStatusUpdated"
const SIGNAL_CONTACT_UPDATED* = "contactUpdated"
const SIGNAL_LOGGEDIN_USER_NAME_CHANGED* = "loggedInUserNameChanged"
const SIGNAL_LOGGEDIN_USER_IMAGE_CHANGED* = "loggedInUserImageChanged"
const SIGNAL_REMOVED_TRUST_STATUS* = "removedTrustStatus"
const SIGNAL_CONTACT_UNTRUSTWORTHY* = "contactUntrustworthy"
const SIGNAL_CONTACT_TRUSTED* = "contactTrusted"
const SIGNAL_CONTACT_INFO_REQUEST_FINISHED* = "contactInfoRequestFinished"
const SIGNAL_APPEND_CHAT_MESSAGES* = "appendChatMessages"

const SIGNAL_CONTACT_PROFILE_SHOWCASE_UPDATED* = "contactProfileShowcaseUpdated"
const SIGNAL_CONTACT_PROFILE_SHOWCASE_LOADED* = "contactProfileShowcaseLoaded"
const SIGNAL_CONTACT_SHOWCASE_ACCOUNTS_BY_ADDRESS_FETCHED* = "profileShowcaseAccountsByAddressFetched"

type
  ContactsGroup* {.pure.} = enum
    AllKnownContacts
    MyMutualContacts
    IncomingPendingContactRequests
    OutgoingPendingContactRequests
    IncomingRejectedContactRequests
    OutgoingRejectedContactRequests
    BlockedContacts

QtObject:
  type Service* = ref object of QObject
    threadpool: ThreadPool
    networkService: network_service.Service
    settingsService: settings_service.Service
    contacts: Table[string, ContactDetails] # [contact_id, ContactDetails]
    contactsStatus: Table[string, StatusUpdateDto] # [contact_id, StatusUpdateDto]
    events: EventEmitter
    closingApp: bool
    imageServerUrl: string

  # Forward declaration
  proc getContactById*(self: Service, id: string): ContactsDto
  proc saveContact(self: Service, contact: ContactsDto)
  proc requestContactInfo*(self: Service, pubkey: string)
  proc constructContactDetails(self: Service, contactDto: ContactsDto, isCurrentUser: bool = false): ContactDetails
  proc parseContactsResponse*(self: Service, contacts: JsonNode, fromBackup: bool = false)

  proc delete*(self: Service)
  proc newService*(
      events: EventEmitter,
      threadpool: ThreadPool,
      networkService: network_service.Service,
      settingsService: settings_service.Service
      ): Service =
    new(result, delete)
    result.QObject.setup
    result.closingApp = false
    result.events = events
    result.networkService = networkService
    result.settingsService = settingsService
    result.threadpool = threadpool
    result.contacts = initTable[string, ContactDetails]()
    result.contactsStatus = initTable[string, StatusUpdateDto]()

  proc addContact(self: Service, contact: ContactDetails) =
    # Private proc, used for adding contacts only.
    self.contacts[contact.dto.id] = contact
    self.contactsStatus[contact.dto.id] = StatusUpdateDto(publicKey: contact.dto.id, statusType: StatusType.Unknown)

  proc fetchContacts*(self: Service) =
    let arg = AsyncFetchContactsTaskArg(
      tptr: asyncFetchContactsTask,
      vptr: cast[uint](self.vptr),
      slot: "fetchContactsDone",
    )
    self.threadpool.start(arg)
    
  proc fetchContactsDone*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson
      for elem in rpcResponseObj["response"]["result"].getElems():
        let contactDto = elem.toContactsDto()
        self.addContact(self.constructContactDetails(
          contactDto,
          isCurrentUser = contactDto.id == singletonInstance.userProfile.getPubKey()
        ))
      self.events.emit(SIGNAL_CONTACTS_LOADED, Args())
    except Exception as e:
      error "error fetching contacts", msg = e.msg

  proc updateAndEmitStatuses(self: Service, statusUpdates: seq[StatusUpdateDto]) =
    for s in statusUpdates:
      if(not self.contactsStatus.hasKey(s.publicKey)):
        # we shouldn't be here ever, but the following line ensures we have added a contact before setting status for it
        discard self.getContactById(s.publicKey)

      self.contactsStatus[s.publicKey] = s

    let data = ContactsStatusUpdatedArgs(statusUpdates: statusUpdates)
    self.events.emit(SIGNAL_CONTACTS_STATUS_UPDATED, data)

  proc doConnect(self: Service) =
    self.events.on(SignalType.Message.event) do(e:Args):
      var receivedData = MessageSignal(e)
      if(receivedData.statusUpdates.len > 0):
        self.updateAndEmitStatuses(receivedData.statusUpdates)

      if receivedData.contacts.len > 0:
        for c in receivedData.contacts:
          let localContact = self.getContactById(c.id)
          var receivedContact = c

          self.saveContact(receivedContact)

          # Check if the contact request was sent by us and if it was approved by the recipient
          if localContact.added and not localContact.hasAddedUs and receivedContact.hasAddedUs:
            singletonInstance.globalEvents.showAcceptedContactRequest(
              "Contact request accepted",
              fmt "{receivedContact.displayName} accepted your contact request",
              receivedContact.id)

          let data = ContactArgs(contactId: c.id)
          self.events.emit(SIGNAL_CONTACT_UPDATED, data)

    self.events.on(SignalType.Message.event) do(e: Args):
      let receivedData = MessageSignal(e)
      if receivedData.updatedProfileShowcaseContactIDs.len > 0:
        for contactId in receivedData.updatedProfileShowcaseContactIDs:
          self.events.emit(SIGNAL_CONTACT_PROFILE_SHOWCASE_UPDATED,
            ProfileShowcaseContactIdArgs(contactId: contactId))

    self.events.on(SignalType.StatusUpdatesTimedout.event) do(e:Args):
      var receivedData = StatusUpdatesTimedoutSignal(e)
      if(receivedData.statusUpdates.len > 0):
        self.updateAndEmitStatuses(receivedData.statusUpdates)

  proc setImageServerUrl(self: Service) =
    try:
      let response = status_contacts.getImageServerURL()
      self.imageServerUrl = response.result.getStr()
    except Exception as e:
      let errDesription = e.msg
      error "error: ", errDesription
      return

  proc init*(self: Service) =
    self.setImageServerUrl()
    self.fetchContacts()
    self.doConnect()

    signalConnect(singletonInstance.userProfile, "nameChanged()", self, "onLoggedInUserNameChange()", 2)
    signalConnect(singletonInstance.userProfile, "imageChanged()", self, "onLoggedInUserImageChange()", 2)

  proc onLoggedInUserNameChange*(self: Service) {.slot.} =
    let data = Args()
    self.events.emit(SIGNAL_LOGGEDIN_USER_NAME_CHANGED, data)

  proc onLoggedInUserImageChange*(self: Service) {.slot.} =
    let data = Args()
    self.events.emit(SIGNAL_LOGGEDIN_USER_IMAGE_CHANGED, data)

  proc getContactsByGroup*(self: Service, group: ContactsGroup): seq[ContactsDto] =
    # Having this logic here we ensure that the same contact group in each part of the app will have the same list
    # of contacts. Be sure when you change any condition here.
    let myPubKey = singletonInstance.userProfile.getPubKey()

    var contacts: seq[ContactsDto] = @[]
    for cd in self.contacts.values:
      let dto = cd.dto
      if dto.id == myPubKey:
        continue
      case group
      of ContactsGroup.AllKnownContacts:
        contacts.add(dto)
      of ContactsGroup.IncomingPendingContactRequests:
        if dto.isContactRequestReceived() and
           not dto.isContactRequestSent() and
           not dto.isContactRemoved() and
           not dto.isReceivedContactRequestRejected() and
           not dto.isBlocked():
          contacts.add(dto)
      of ContactsGroup.OutgoingPendingContactRequests:
        if dto.isContactRequestSent() and
           not dto.isContactRequestReceived() and
           not dto.isContactRemoved() and
           not dto.isBlocked():
          contacts.add(dto)
      of ContactsGroup.IncomingRejectedContactRequests:
        if dto.isContactRequestReceived() and
           dto.isReceivedContactRequestRejected() and
           not dto.isBlocked():
          contacts.add(dto)
      of ContactsGroup.OutgoingRejectedContactRequests:
        # if dto.isContactRequestSent() and
        #    dto.isSentContactRequestRejected() and
        #    not dto.isBlocked():
        #   contacts.add(dto)
        discard
      of ContactsGroup.BlockedContacts:
        if dto.isBlocked():
          contacts.add(dto)
      of ContactsGroup.MyMutualContacts:
        if dto.isContact():
          contacts.add(dto)

    return contacts

  proc generateAlias*(self: Service, publicKey: string): string =
    if(publicKey.len == 0):
      error "cannot generate an alias from the empty public key"
      return
    return status_accounts.generateAlias(publicKey).result.getStr

  proc getContactNameAndImageInternal(self: Service, contactDto: ContactsDto):
      tuple[name: string, optionalName: string, image: string, largeImage: string] =
    ## This proc should be used accross the app in order to have for the same contact
    ## same image and name displayed everywhere in the app.
    result.name = contactDto.userDefaultDisplayName()
    result.optionalName = contactDto.userOptionalName()
    if(contactDto.image.thumbnail.len > 0):
      result.image = contactDto.image.thumbnail
    if(contactDto.image.large.len > 0):
      result.largeImage = contactDto.image.large

  proc constructContactDetails(self: Service, contactDto: ContactsDto, isCurrentUser: bool = false): ContactDetails =
    result = ContactDetails()
    let (name, optionalName, icon, _) = self.getContactNameAndImageInternal(contactDto)
    result.defaultDisplayName = name
    result.optionalName = optionalName
    result.icon = icon
    result.colorId = procs_from_visual_identity_service.colorIdOf(contactDto.id)
    result.isCurrentUser = isCurrentUser
    result.dto = contactDto

  proc getContactDetails*(self: Service, id: string): ContactDetails =
    var pubkey = id

    if service_conversion.isCompressedPubKey(id):
      pubkey = status_accounts.decompressPk(id).result

    if len(pubkey) == 0:
      return

    ## Returns contact details based on passed id (public key)
    ## If we don't have stored contact localy or in the db then we create it based on public key.
    if self.contacts.hasKey(pubkey):
      return self.contacts[pubkey]

    if pubkey == singletonInstance.userProfile.getPubKey():
      # If we try to get the contact details of ourselves, just return our own info
      return self.constructContactDetails(
        ContactsDto(
          id: singletonInstance.userProfile.getPubKey(),
          displayName: singletonInstance.userProfile.getDisplayName(),
          name: singletonInstance.userProfile.getPreferredName(),
          alias: singletonInstance.userProfile.getUsername(),
          ensVerified: singletonInstance.userProfile.getPreferredName().len > 0,
          added: true,
          image: Images(
            thumbnail: singletonInstance.userProfile.getThumbnailImage(),
            large: singletonInstance.userProfile.getLargeImage()
          ),
          trustStatus: TrustStatus.Trusted,
          bio: self.settingsService.getBio(),
        ),
        isCurrentUser = true,
      )

    if not pubkey.startsWith("0x"):
      debug "id is not in a hex format"
      return

    var num64: int64
    let parsedChars = parseHex(pubkey, num64)
    if parsedChars != PK_LENGTH_0X_INCLUDED:
      debug "id doesn't have expected length"
      return

    let contact = self.constructContactDetails(
      ContactsDto(
        id: pubkey,
        alias: self.generateAlias(pubkey),
        ensVerified: false,
        added: false,
        blocked: false,
        hasAddedUs: false,
        trustStatus: TrustStatus.Unknown,
      ),
      isCurrentUser = false,
    )
    self.addContact(contact)
    return contact

  proc getContactById*(self: Service, id: string): ContactsDto =
    return self.getContactDetails(id).dto

  proc getStatusForContactWithId*(self: Service, publicKey: string): StatusUpdateDto =
    if publicKey == singletonInstance.userProfile.getPubKey():
      let currentUserStatus = self.settingsService.getCurrentUserStatus()
      return StatusUpdateDto(publicKey: singletonInstance.userProfile.getPubKey(),
        statusType: currentUserStatus.statusType,
        clock: currentUserStatus.clock.uint64,
        text: currentUserStatus.text)

    if not self.contactsStatus.hasKey(publicKey):
      return StatusUpdateDto(publicKey: publicKey,
        statusType: StatusType.Unknown,
        clock: 0,
        text: "")

    return self.contactsStatus[publicKey]

  proc getContactNameAndImage*(self: Service, publicKey: string):
      tuple[name: string, image: string, largeImage: string] =
    let contactDto = self.getContactById(publicKey)
    let tempRes = self.getContactNameAndImageInternal(contactDto)
    return (tempRes.name, tempRes.image, tempRes.largeImage)

  proc saveContact(self: Service, contact: ContactsDto) =
    # we must keep local contacts updated
    self.contacts[contact.id] = self.constructContactDetails(
      contact,
      isCurrentUser = contact.id == singletonInstance.userProfile.getPubKey()
    )

  # fromBackup is used to indicate that the contact was loaded from a backup
  proc updateContact(self: Service, contact: ContactsDto, fromBackup: bool = false) =
    var signal = SIGNAL_CONTACT_ADDED
    let publicKey = contact.id
    if self.contacts.hasKey(publicKey):
      if self.contacts[publicKey].dto.added and not self.contacts[publicKey].dto.removed and contact.added and not contact.removed:
        signal = SIGNAL_CONTACT_UPDATED
      if contact.removed and not self.contacts[publicKey].dto.removed:
        singletonInstance.globalEvents.showContactRemoved("Contact removed", fmt "You removed {contact.displayName} as a contact", contact.id)
        signal = SIGNAL_CONTACT_REMOVED
    self.contacts[publicKey] = self.constructContactDetails(
      contact,
      isCurrentUser = contact.id == singletonInstance.userProfile.getPubKey()
    )
    self.events.emit(signal, ContactArgs(contactId: publicKey, fromBackup: fromBackup))

  proc parseContactsResponse*(self: Service, contacts: JsonNode, fromBackup: bool = false) =
    for contactJson in contacts:
      let contact = contactJson.toContactsDto()
      self.updateContact(contact, fromBackup)

  proc parseContactsResponse*(self: Service, response: RpcResponse[JsonNode], fromBackup: bool = false) =
    let contacts = response.result{"contacts"}
    if contacts == nil:
      return
    self.parseContactsResponse(contacts, fromBackup)
    

  proc sendContactRequest*(self: Service, publicKey: string, message: string) =
    # Prefetch contact to avoid race condition with AC notification
    discard self.getContactById(publicKey)

    try:
      let response = status_contacts.sendContactRequest(publicKey, message)
      if not response.error.isNil:
        error "error sending contact request", msg = response.error.message
        return

      self.parseContactsResponse(response)
      self.events.emit(SIGNAL_APPEND_CHAT_MESSAGES, AppendChatMessagesArgs(
        chatId: publicKey,
        messages: response.result{"messages"}
      ))
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})

    except Exception as e:
      error "an error occurred while sending the contact request", msg = e.msg

  proc acceptContactRequest*(self: Service, publicKey: string, contactRequestId: string) =
    try:
      # NOTE: publicKey used for accepting last request
      let response =
        if contactRequestId.len > 0:
          status_contacts.acceptContactRequest(contactRequestId, publicKey)
        else:
          status_contacts.acceptLatestContactRequestForContact(publicKey)

      if not response.error.isNil:
        error "error accepting contact request", msg = response.error.message
        return

      self.parseContactsResponse(response)
      self.events.emit(SIGNAL_APPEND_CHAT_MESSAGES, AppendChatMessagesArgs(
        chatId: publicKey,
        messages: response.result{"messages"}
      ))
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})

    except Exception as e:
      error "an error occurred while accepting the contact request", msg=e.msg

  proc dismissContactRequest*(self: Service, publicKey: string, contactRequestId: string) =
    try:
      # NOTE: publicKey used for dismissing last request
      let response =
        if contactRequestId.len > 0:
          status_contacts.declineContactRequest(contactRequestId, publicKey)
        else:
          status_contacts.dismissLatestContactRequestForContact(publicKey)

      if not response.error.isNil:
        error "error dismissing contact ", msg = response.error.message
        return

      self.parseContactsResponse(response)
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})

    except Exception as e:
      error "an error occurred while dismissing the contact request", msg=e.msg

  proc getLatestContactRequestForContact*(self: Service, publicKey: string): message_dto.MessageDto =
    try:
      let response = status_contacts.getLatestContactRequestForContact(publicKey)

      if not response.error.isNil:
        error "error getting incoming contact request ", msg = response.error.message
        return

      let messages = response.result{"messages"}
      if messages == nil or len(messages) < 1:
        error "can't find incoming contact request for", publicKey
        return

      return messages[0].toMessageDto()

    except Exception as e:
      error "an error occurred while getting incoming contact request", msg=e.msg

  proc changeContactNickname*(self: Service, publicKey: string, nickname: string) =
    var contact = self.getContactById(publicKey)
    contact.localNickname = nickname

    let response = status_contacts.setContactLocalNickname(contact.id, contact.localNickname)
    if not response.error.isNil:
      error "error setting local name ", msg = response.error.message
      return
    self.saveContact(contact)
    let data = ContactArgs(contactId: contact.id)
    self.events.emit(SIGNAL_CONTACT_NICKNAME_CHANGED, data)

  proc unblockContact*(self: Service, publicKey: string) =
    var contact = self.getContactById(publicKey)

    let response = status_contacts.unblockContact(contact.id)
    # TODO there are chat updates too. We need to send them to the chat service
    if not response.error.isNil:
      error "error unblocking contact ", msg = response.error.message
      return

    self.parseContactsResponse(response)
    self.events.emit(SIGNAL_CONTACT_UNBLOCKED, ContactArgs(contactId: contact.id))

  proc blockContact*(self: Service, publicKey: string) =
    var contact = self.getContactById(publicKey)

    let response = status_contacts.blockContact(contact.id)
    if not response.error.isNil:
      error "error blocking contact ", msg = response.error.message
      return

    self.parseContactsResponse(response)
    self.events.emit(SIGNAL_CONTACT_BLOCKED, ContactArgs(contactId: contact.id))

  proc removeContact*(self: Service, publicKey: string) =
    let response = status_contacts.retractContactRequest(publicKey)
    if not response.error.isNil:
      error "error removing contact ", msg = response.error.message
      return

    self.events.emit(SIGNAL_APPEND_CHAT_MESSAGES, AppendChatMessagesArgs(
      chatId: publicKey,
      messages: response.result{"messages"}
    ))
    self.parseContactsResponse(response)
    checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})

  proc ensResolved*(self: Service, jsonObj: string) {.slot.} =
    try:
      let jsonObj = jsonObj.parseJson()
      let data = ResolvedContactArgs(
          pubkey: jsonObj["id"].getStr,
          address: jsonObj["address"].getStr,
          uuid: jsonObj["uuid"].getStr,
          reason: jsonObj["reason"].getStr)
      self.events.emit(SIGNAL_ENS_RESOLVED, data)
    except Exception as e:
      error "error resolving ENS ", msg=e.msg

  proc resolveENS*(self: Service, value: string, uuid: string = "", reason = "") =
    let arg = LookupContactTaskArg(
      tptr: lookupContactTask,
      vptr: cast[uint](self.vptr),
      slot: "ensResolved",
      value: value,
      chainId: self.networkService.getAppNetwork().chainId,
      uuid: uuid,
      reason: reason
    )
    self.threadpool.start(arg)

  proc emitCurrentUserStatusChanged*(self: Service, currentStatusUser: CurrentUserStatus) =
    let currentUserStatusUpdate = StatusUpdateDto(publicKey: singletonInstance.userProfile.getPubKey(),
                                                  statusType: currentStatusUser.statusType,
                                                  clock: currentStatusUser.clock.uint64,
                                                  text: currentStatusUser.text)
    let data = ContactsStatusUpdatedArgs(statusUpdates: @[currentUserStatusUpdate])
    self.events.emit(SIGNAL_CONTACTS_STATUS_UPDATED, data)


  proc markAsTrusted*(self: Service, publicKey: string) =
    let response = status_contacts.markAsTrusted(publicKey)
    if not response.error.isNil:
      error "error marking as trusted ", msg = response.error.message
      return

    if self.contacts.hasKey(publicKey):
      self.contacts[publicKey].dto.trustStatus = TrustStatus.Trusted

    self.events.emit(SIGNAL_CONTACT_TRUSTED,
      TrustArgs(publicKey: publicKey, trustStatus: self.contacts[publicKey].dto.trustStatus))

  proc markUntrustworthy*(self: Service, publicKey: string) =
    let response = status_contacts.markUntrustworthy(publicKey)
    if not response.error.isNil:
      error "error marking as untrustworthy ", msg = response.error.message
      return

    if self.contacts.hasKey(publicKey):
      self.contacts[publicKey].dto.trustStatus = TrustStatus.Untrustworthy

    self.events.emit(SIGNAL_CONTACT_UNTRUSTWORTHY,
      TrustArgs(publicKey: publicKey, trustStatus: self.contacts[publicKey].dto.trustStatus))

  proc removeTrustStatus*(self: Service, publicKey: string) =
    try:
      let response = status_contacts.removeTrustStatus(publicKey)
      if not response.error.isNil:
        error "error removing trust status", msg = response.error.message
        return

      self.parseContactsResponse(response)

      if self.contacts.hasKey(publicKey):
        self.contacts[publicKey].dto.trustStatus = TrustStatus.Unknown
        
      self.events.emit(SIGNAL_REMOVED_TRUST_STATUS,
        TrustArgs(publicKey: publicKey, trustStatus: self.contacts[publicKey].dto.trustStatus))
    except Exception as e:
      error "error in removeTrustStatus request", msg = e.msg

  proc asyncContactInfoLoaded*(self: Service, pubkeyAndRpcResponse: string) {.slot.} =
    try:
      let rpcResponseObj = pubkeyAndRpcResponse.parseJson
      let publicKey = rpcResponseObj{"publicKey"}.getStr
      let requestError = rpcResponseObj{"error"}
      var error : string

      if requestError.kind != JNull:
        error = requestError.getStr
      else:
        let responseError = rpcResponseObj{"response"}{"error"}
        if responseError.kind != JNull:
          error = Json.decode($responseError, RpcError).message

      if len(error) != 0:
        error "error requesting contact info", msg = error, publicKey
        self.events.emit(SIGNAL_CONTACT_INFO_REQUEST_FINISHED, ContactInfoRequestArgs(publicKey: publicKey, ok: false))
        return

      let contact = rpcResponseObj{"response"}{"result"}.toContactsDto()
      self.saveContact(contact)
      self.events.emit(SIGNAL_CONTACT_INFO_REQUEST_FINISHED, ContactInfoRequestArgs(publicKey: publicKey, ok: true))
    except Exception as e:
      error "error in contact info loaded", msg = e.msg

  proc requestContactInfo*(self: Service, pubkey: string) =
    try:
      let arg = AsyncRequestContactInfoTaskArg(
        tptr: asyncRequestContactInfoTask,
        vptr: cast[uint](self.vptr),
        slot: "asyncContactInfoLoaded",
        pubkey: pubkey,
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error requesting contact info", msg = e.msg, pubkey

  proc shareUserUrlWithData*(self: Service, pubkey: string): string =
    try:
      let response = status_shared_urls.shareUserUrlWithData(pubkey)
      return response.result.getStr
    except Exception as e:
      error "Error getting user url with data", msg = e.msg, pubkey

  proc shareUserUrlWithChatKey*(self: Service, pubkey: string): string =
    try:
      let response = status_shared_urls.shareUserUrlWithChatKey(pubkey)
      return response.result.getStr
    except Exception as e:
      error "Error getting user url with chat key", msg = e.msg, pubkey

  proc shareUserUrlWithENS*(self: Service, pubkey: string): string =
    try:
      let response = status_shared_urls.shareUserUrlWithENS(pubkey)
      return response.result.getStr
    except Exception as e:
      error "Error getting user url with ens name", msg = e.msg, pubkey

  proc requestProfileShowcaseForContact*(self: Service, contactId: string, validate: bool) =
    let arg = AsyncGetProfileShowcaseForContactTaskArg(
      pubkey: contactId,
      validate: validate,
      tptr: asyncGetProfileShowcaseForContactTask,
      vptr: cast[uint](self.vptr),
      slot: "asyncProfileShowcaseForContactLoaded",
    )
    self.threadpool.start(arg)

  proc asyncProfileShowcaseForContactLoaded*(self: Service, rpcResponse: string) {.slot.} =
    try:
      let rpcResponseObj = rpcResponse.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        error "Error requesting profile showcase for a contact", msg = rpcResponseObj{"error"}
        return

      let profileShowcase = rpcResponseObj["response"]["result"].toProfileShowcaseDto()
      let validated = rpcResponseObj["validated"].getBool

      self.events.emit(SIGNAL_CONTACT_PROFILE_SHOWCASE_LOADED,
        ProfileShowcaseForContactArgs(
          profileShowcase: profileShowcase,
          validated: validated
      ))
    except Exception as e:
      error "Error requesting profile showcase for a contact", msg = e.msg

  proc fetchProfileShowcaseAccountsByAddress*(self: Service, address: string) =
    let arg = FetchProfileShowcaseAccountsTaskArg(
      address: address,
      tptr: fetchProfileShowcaseAccountsTask,
      vptr: cast[uint](self.vptr),
      slot: "onProfileShowcaseAccountsByAddressFetched",
    )
    self.threadpool.start(arg)

  proc onProfileShowcaseAccountsByAddressFetched*(self: Service, rpcResponse: string) {.slot.} =
    var data = ProfileShowcaseForContactArgs(
      profileShowcase: ProfileShowcaseDto(
        accounts: @[],
      ),
    )
    try:
      let rpcResponseObj = rpcResponse.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)
      if rpcResponseObj{"response"}.kind != JArray:
        raise newException(CatchableError, "invalid response")

      data.profileShowcase.accounts = map(rpcResponseObj{"response"}.getElems(), proc(x: JsonNode): ProfileShowcaseAccount = toProfileShowcaseAccount(x))
    except Exception as e:
      error "onProfileShowcaseAccountsByAddressFetched", msg = e.msg
    self.events.emit(SIGNAL_CONTACT_SHOWCASE_ACCOUNTS_BY_ADDRESS_FETCHED, data)

  proc delete*(self: Service) =
    self.QObject.delete

