import io_interface, tables, sets
import std/strutils


import ../../../../../../app_service/service/settings/service as settings_service
import ../../../../../../app_service/service/message/service as message_service
import ../../../../../../app_service/service/contacts/service as contact_service
import ../../../../../../app_service/service/community/service as community_service
import ../../../../../../app_service/service/chat/service as chat_service
import ../../../../../../app_service/service/message/dto/link_preview
import ../../../../../../app_service/service/message/dto/payment_request
import ../../../../../../app_service/service/message/dto/urls_unfurling_plan
import ../../../../../../app_service/service/settings/dto/settings
import ../../../../../core/eventemitter
import ../../../../../core/unique_event_emitter
import ./link_preview_cache

const MESSAGE_LINK_PREVIEWS_LIMIT = 5

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    sectionId: string
    events: UniqueUUIDEventEmitter
    chatId: string
    belongsToCommunity: bool
    communityService: community_service.Service
    contactService: contact_service.Service
    chatService: chat_service.Service
    messageService: message_service.Service
    settingsService: settings_service.Service
    linkPreviewCache: LinkPreviewCache
    linkPreviewPersistentSetting: UrlUnfurlingMode
    linkPreviewCurrentMessageSetting: UrlUnfurlingMode
    unfurlRequests: HashSet[string]
    unfurlingPlanActiveRequest: string
    unfurlingPlanActiveRequestUnfurlAfter: bool
    unfurlingPlan: UrlsUnfurlingPlan

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    sectionId: string,
    chatId: string,
    belongsToCommunity: bool,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    contactService: contact_service.Service,
    messageService: message_service.Service,
    settingsService: settings_service.Service
    ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = initUniqueUUIDEventEmitter(events)
  result.sectionId = chatId
  result.chatId = chatId
  result.belongsToCommunity = belongsToCommunity
  result.chatService = chatService
  result.communityService = communityService
  result.contactService = contactService
  result.messageService = messageService
  result.settingsService = settingsService
  result.linkPreviewCache = newLinkPreiewCache()
  result.linkPreviewPersistentSetting = settingsService.urlUnfurlingMode()
  result.linkPreviewCurrentMessageSetting = result.linkPreviewPersistentSetting
  result.unfurlRequests = initHashSet[string]()
  result.unfurlingPlanActiveRequest = ""
  result.unfurlingPlan = initUrlsUnfurlingPlan()

proc onUnfurlingModeChanged(self: Controller, value: UrlUnfurlingMode)
proc onUrlsUnfurled(self: Controller, args: LinkPreviewDataArgs)
proc clearLinkPreviewCache*(self: Controller)
proc asyncUnfurlUrls(self: Controller, urls: seq[string])
proc asyncUnfurlUnknownUrls(self: Controller, urls: seq[string])
proc handleUnfurlingPlan*(self: Controller, unfurlNewUrls: bool)

proc delete*(self: Controller) =
  self.events.disconnect()

proc init*(self: Controller) =
  self.events.on(SIGNAL_URLS_UNFURLED) do(e:Args):
    let args = LinkPreviewDataArgs(e)
    if not self.unfurlRequests.contains(args.requestUuid):
      return
    self.unfurlRequests.excl(args.requestUuid)
    self.onUrlsUnfurled(args)

  self.events.on(SIGNAL_URL_UNFURLING_MODE_UPDATED) do(e:Args):
    let args = UrlUnfurlingModeArgs(e)
    self.onUnfurlingModeChanged(args.value)

  self.events.on(SIGNAL_URLS_UNFURLING_PLAN_READY) do(e: Args):
    let args = UrlsUnfurlingPlanDataArgs(e)
    if self.unfurlingPlanActiveRequest != args.requestUuid:
      return
    self.unfurlingPlan = args.plan
    self.unfurlingPlanActiveRequest = ""
    self.handleUnfurlingPlan(self.unfurlingPlanActiveRequestUnfurlAfter)

  self.events.on(SIGNAL_SENDING_SUCCESS) do(e:Args):
    let args = MessageSendingSuccess(e)
    if self.chatId != args.chat.id:
      return
    self.delegate.onSendingMessageSuccess()

  self.events.on(SIGNAL_SENDING_FAILED) do(e:Args):
    let args = MessageSendingFailure(e)
    if self.chatId != args.chatId:
      return
    self.delegate.onSendingMessageFailure()

proc getChatId*(self: Controller): string =
  return self.chatId

proc belongsToCommunity*(self: Controller): bool =
  return self.belongsToCommunity

proc setLinkPreviewEnabledForThisMessage*(self: Controller, enabled: bool) =
  self.linkPreviewCurrentMessageSetting = if enabled: UrlUnfurlingMode.Enabled else: UrlUnfurlingMode.Disabled
  self.delegate.setAskToEnableLinkPreview(false)

proc resetLinkPreviews(self: Controller) =
  self.delegate.setLinkPreviewUrls(@[])
  self.linkPreviewCache.clear()
  self.linkPreviewCurrentMessageSetting = self.linkPreviewPersistentSetting
  self.delegate.setAskToEnableLinkPreview(false)

proc sendImages*(self: Controller,
                 imagePathsJson: string,
                 msg: string,
                 replyTo: string,
                 preferredUsername: string = "",
                 linkPreviews: seq[LinkPreview],
                 paymentRequests: seq[PaymentRequest]) =
  self.resetLinkPreviews()
  self.chatService.asyncSendImages(
    self.chatId,
    imagePathsJson,
    msg,
    replyTo,
    preferredUsername,
    linkPreviews,
    paymentRequests
  )

proc sendChatMessage*(self: Controller,
                      msg: string,
                      replyTo: string,
                      contentType: int,
                      preferredUsername: string = "",
                      linkPreviews: seq[LinkPreview],
                      paymentRequests: seq[PaymentRequest]) =
  self.resetLinkPreviews()
  self.chatService.asyncSendChatMessage(self.chatId,
    msg,
    replyTo,
    contentType,
    preferredUsername,
    linkPreviews,
    paymentRequests
  )

proc getLinkPreviewEnabled*(self: Controller): bool =
  return self.linkPreviewPersistentSetting == UrlUnfurlingMode.Enabled or self.linkPreviewCurrentMessageSetting == UrlUnfurlingMode.Enabled

proc shouldAskToEnableLinkPreview(self: Controller): bool =
  return self.linkPreviewPersistentSetting == UrlUnfurlingMode.AlwaysAsk and self.linkPreviewCurrentMessageSetting == UrlUnfurlingMode.AlwaysAsk

proc setText*(self: Controller, text: string, unfurlNewUrls: bool) =
  if text == "":
    self.resetLinkPreviews()
    self.delegate.setUrls(@[])
    return

  self.unfurlingPlanActiveRequestUnfurlAfter = unfurlNewUrls
  self.unfurlingPlanActiveRequest = self.messageService.asyncGetTextURLsToUnfurl(text)

proc handleUnfurlingPlan*(self: Controller, unfurlNewUrls: bool) =
  proc isStatusMessageUrl(url: string): bool =
      return startsWith(url, "https://status.app/m/") or
        startsWith(url, "http://status.app/m/") or
        startsWith(url, "status-app://m/")

  var allUrls = newSeq[string]() # Used for URLs syntax highlighting only
  var allAllowedUrls = newSeq[string]() # Used for LinkPreviewsModel to keep the urls order
  var statusAllowedUrls = newSeq[string]()
  var otherAllowedUrls = newSeq[string]()
  var askToEnableLinkPreview = false

  for metadata in self.unfurlingPlan.urls:
    allUrls.add(metadata.url)

    # Message deep links are navigational links for now and intentionally have no
    # preview payload, so keep them clickable/highlighted but don't unfurl.
    if isStatusMessageUrl(metadata.url):
      continue

    if metadata.permission == UrlUnfurlingForbiddenBySettings or
       metadata.permission == UrlUnfurlingNotSupported:
        continue

    if metadata.permission == UrlUnfurlingAskUser:
      if self.linkPreviewCurrentMessageSetting == UrlUnfurlingMode.AlwaysAsk:
        askToEnableLinkPreview = true
      else:
        otherAllowedUrls.add(metadata.url)
        allAllowedUrls.add(metadata.url)
      continue

    if allAllowedUrls.len == MESSAGE_LINK_PREVIEWS_LIMIT:
      continue

    # Split unfurling into 2 packs, which will be different RPCs.
    # In most cases we expect status links to ufurl immediately.
    # In future we could unfurl each link in a separate RPC,
    # this would give better UX, but might result in worse performance.
    if metadata.isStatusSharedUrl:
      statusAllowedUrls.add(metadata.url)
    else:
      otherAllowedUrls.add(metadata.url)

    allAllowedUrls.add(metadata.url)

  # Update UI
  self.delegate.setUrls(allUrls)
  self.delegate.setLinkPreviewUrls(allAllowedUrls)
  self.delegate.setAskToEnableLinkPreview(askToEnableLinkPreview)

  if not unfurlNewUrls:
    return

  self.asyncUnfurlUnknownUrls(statusAllowedUrls)
  self.asyncUnfurlUnknownUrls(otherAllowedUrls)

proc reloadUnfurlingPlan*(self: Controller) =
  self.setText(self.delegate.getPlainText(), true)

proc asyncUnfurlUrls(self: Controller, urls: seq[string]) =
  let requestUuid = self.messageService.asyncUnfurlUrls(urls)
  self.unfurlRequests.incl(requestUuid)
  self.linkPreviewCache.markAsRequested(urls)

proc asyncUnfurlUnknownUrls(self: Controller, urls: seq[string]) =
  let newUrls = self.linkPreviewCache.unknownUrls(urls)
  self.asyncUnfurlUrls(newUrls)

proc linkPreviewsFromCache*(self: Controller, urls: seq[string]): Table[string, LinkPreview] =
  return self.linkPreviewCache.linkPreviews(urls)

proc clearLinkPreviewCache*(self: Controller) =
  self.linkPreviewCache.clear()

proc onUrlsUnfurled(self: Controller, args: LinkPreviewDataArgs) =
  let urls = self.linkPreviewCache.add(args.linkPreviews)
  self.delegate.updateLinkPreviewsFromCache(urls)

proc loadLinkPreviews*(self: Controller, urls: seq[string]) =
  if self.getLinkPreviewEnabled():
    self.asyncUnfurlUrls(urls)

proc setLinkPreviewEnabled*(self: Controller, enabled: bool) =
  let mode = if enabled: UrlUnfurlingMode.Enabled else: UrlUnfurlingMode.Disabled
  discard self.settingsService.saveUrlUnfurlingMode(mode)

proc onUnfurlingModeChanged(self: Controller, value: UrlUnfurlingMode) =
  self.linkPreviewPersistentSetting = value
  self.reloadUnfurlingPlan()

proc getContactDetails*(self: Controller, contactId: string): ContactDetails =
  return self.contactService.getContactDetails(contactId)
