import nimqml, sets
import dotherside_ext
import app/global/html_utils
import ./io_interface
import ./preserved_properties
import ./urls_model
import app/modules/shared_models/link_preview_model as link_preview_model
import app/modules/shared_models/payment_request_model as payment_request_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      preservedProperties: PreservedProperties
      preservedPropertiesVariant: QVariant
      linkPreviewModel: link_preview_model.Model
      linkPreviewModelVariant: QVariant
      paymentRequestModel: payment_request_model.Model
      paymentRequestModelVariant: QVariant
      urlsModel: urls_model.Model
      urlsModelVariant: QVariant
      sendingInProgress: bool
      askToEnableLinkPreview: bool

  proc setSendingInProgress*(self: View, value: bool)

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.preservedProperties = newPreservedProperties()
    result.preservedPropertiesVariant = newQVariant(result.preservedProperties)
    result.linkPreviewModel = newLinkPreviewModel()
    result.linkPreviewModelVariant = newQVariant(result.linkPreviewModel)
    result.paymentRequestModel = newPaymentRequestModel()
    result.paymentRequestModelVariant = newQVariant(result.paymentRequestModel)
    result.urlsModel = newUrlsModel()
    result.urlsModelVariant = newQVariant(result.urlsModel)
    result.askToEnableLinkPreview = false

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc sendMessage*(
      self: View,
      msg: string,
      replyTo: string,
      contentType: int) {.slot.} =
    # FIXME: Update this when `setText` is async.
    self.setSendingInProgress(true)
    self.delegate.setText(msg, false)
    self.delegate.sendChatMessage(msg, replyTo, contentType, self.linkPreviewModel.getUnfuledLinkPreviews(), self.payment_request_model.getPaymentRequests())

  proc sendImages*(self: View, imagePathsJson: string, msg: string, replyTo: string) {.slot.} =
    # FIXME: Update this when `setText` is async.
    self.setSendingInProgress(true)
    self.delegate.setText(msg, false)
    self.delegate.sendImages(imagePathsJson, msg, replyTo, self.linkPreviewModel.getUnfuledLinkPreviews(), self.payment_request_model.getPaymentRequests())

  proc getPreservedProperties(self: View): QVariant {.slot.} =
    return self.preservedPropertiesVariant

  QtProperty[QVariant] preservedProperties:
    read = getPreservedProperties

  proc getPaymentRequestModel*(self: View): QVariant {.slot.} =
    return self.paymentRequestModelVariant

  QtProperty[QVariant] paymentRequestModel:
    read = getPaymentRequestModel

  proc getLinkPreviewModel*(self: View): QVariant {.slot.} =
    return self.linkPreviewModelVariant

  QtProperty[QVariant] linkPreviewModel:
    read = getLinkPreviewModel

  proc askToEnableLinkPreviewChanged(self: View) {.signal.}
  proc getAskToEnableLinkPreview(self: View): bool {.slot.} =
    return self.askToEnableLinkPreview
  proc setAskToEnableLinkPreview*(self: View, value: bool) {.slot.} =
    self.askToEnableLinkPreview = value
    self.askToEnableLinkPreviewChanged()

  QtProperty[bool] askToEnableLinkPreview:
    read = getAskToEnableLinkPreview
    notify = askToEnableLinkPreviewChanged

  # Currently used to fetch link previews, but could be used elsewhere
  proc setText*(self: View, text: string) {.slot.} =
    self.delegate.setText(text, true)

  proc getPlainText*(self: View): string {.slot.} =
    return html_utils.plain_text(self.preservedProperties.getText())

  proc updateLinkPreviewsFromCache*(self: View, urls: seq[string]) =
    let linkPreviews = self.delegate.linkPreviewsFromCache(urls)
    self.linkPreviewModel.updateLinkPreviews(linkPreviews)

    for contactId in self.linkPreviewModel.getContactIds().items:
      let contact = self.delegate.getContactDetails(contactId)
      if contact.dto.displayName != "":
        self.linkPreviewModel.setContactInfo(contact)

  proc setLinkPreviewUrls*(self: View, urls: seq[string]) =
    self.linkPreviewModel.setUrls(urls)
    self.updateLinkPreviewsFromCache(urls)

  proc clearLinkPreviewCache*(self: View) {.slot.} =
    self.delegate.clearLinkPreviewCache()

  proc reloadLinkPreview(self: View, link: string) {.slot.} =
    self.delegate.loadLinkPreviews(@[link])

  proc loadLinkPreviews(self: View, links: seq[string]) =
    self.delegate.loadLinkPreviews(links)

  proc enableLinkPreview(self: View) {.slot.} =
    self.delegate.setLinkPreviewEnabled(true)

  proc disableLinkPreview(self: View) {.slot.} =
    self.delegate.setLinkPreviewEnabled(false)

  proc setLinkPreviewEnabledForCurrentMessage(self: View, enabled: bool) {.slot.} =
    self.delegate.setLinkPreviewEnabledForThisMessage(enabled)
    self.delegate.reloadUnfurlingPlan()

  proc removeLinkPreviewData*(self: View, index: int) {.slot.} =
    self.linkPreviewModel.removePreviewData(index)

  proc addPaymentRequest*(self: View, receiver: string, amount: string, tokenKey: string, symbol: string, logoUri: string) {.slot.} =
    self.paymentRequestModel.addPaymentRequest(receiver, amount, tokenKey, symbol, logoUri)

  proc removePaymentRequestPreviewData*(self: View, index: int) {.slot.} =
    self.paymentRequestModel.removeItemWithIndex(index)

  proc removeAllPaymentRequestPreviewData(self: View) {.slot.} =
    self.paymentRequestModel.clearItems()

  proc urlsModelChanged(self: View) {.signal.}
  proc getUrlsModel*(self: View): QVariant {.slot.} =
    return self.urlsModelVariant

  proc setUrls*(self: View, urls: seq[string]) =
    self.urlsModel.setUrls(urls)

  QtProperty[QVariant] urlsModel:
    read = getUrlsModel
    notify = urlsModelChanged

  proc sendingInProgressChanged(self: View) {.signal.}
  proc getSendingInProgress*(self: View): bool {.slot.} =
    return self.sendingInProgress

  QtProperty[bool] sendingInProgress:
    read = getSendingInProgress
    notify = sendingInProgressChanged

  proc setSendingInProgress*(self: View, value: bool) =
    self.sendingInProgress = value
    self.sendingInProgressChanged()

  proc emitSendingMessageSuccess*(self: View) =
    self.setSendingInProgress(false)

  proc emitSendingMessageFailure*(self: View) =
    self.setSendingInProgress(false)

  proc delete*(self: View) =
    self.QObject.delete

