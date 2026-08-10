import nimqml, tables

import ../../../../../../app_service/service/gif/dto
import ../../../../../../app_service/service/message/dto/link_preview
import ../../../../../../app_service/service/message/dto/payment_request
import ../../../../../../app_service/service/contacts/dto/contact_details

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method sendChatMessage*(self: AccessInterface, msg: string, replyTo: string, contentType: int,
  linkPreviews: seq[LinkPreview], paymentRequests: seq[PaymentRequest]) {.base.} =
  raise newException(ValueError, "No implementation available")

method sendImages*(self: AccessInterface, imagePathsJson: string, msg: string, replyTo: string,
  linkPreviews: seq[LinkPreview], paymentRequests: seq[PaymentRequest]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getThreadId*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifs*(self: AccessInterface, query: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getTrendingsGifs*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getRecentsGifs*(self: AccessInterface): seq[GifDto] {.base.} =
  raise newException(ValueError, "No implementation available")

method loadRecentGifs*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadRecentGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadTrendingGifsStarted*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadTrendingGifsError*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadTrendingGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifsStarted*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifsError*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getFavoritesGifs*(self: AccessInterface): seq[GifDto] {.base.} =
  raise newException(ValueError, "No implementation available")

method loadFavoriteGifs*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadFavoriteGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleFavoriteGif*(self: AccessInterface, item: GifDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method addToRecentsGif*(self: AccessInterface, item: GifDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method isFavorite*(self: AccessInterface, item: GifDto): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method setText*(self: AccessInterface, text: string, unfurlUrls: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method getPlainText*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method setLinkPreviewUrls*(self: AccessInterface, urls: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateLinkPreviewsFromCache*(self: AccessInterface, urls: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method clearLinkPreviewCache*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method linkPreviewsFromCache*(self: AccessInterface, urls: seq[string]): Table[string, LinkPreview] {.base.} =
  raise newException(ValueError, "No implementation available")

method reloadUnfurlingPlan*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadLinkPreviews*(self: AccessInterface, urls: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getLinkPreviewEnabled*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method setLinkPreviewEnabled*(self: AccessInterface, enabled: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method setAskToEnableLinkPreview*(self: AccessInterface, value: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method setLinkPreviewEnabledForThisMessage*(self: AccessInterface, enabled: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method setUrls*(self: AccessInterface, urls: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getContactDetails*(self: AccessInterface, contactId: string): ContactDetails {.base.} =
  raise newException(ValueError, "No implementation available")

method onSendingMessageSuccess*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onSendingMessageFailure*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")
