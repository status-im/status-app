import nimqml
import ../../../../../app_service/service/contacts/dto/contacts as contacts
import ../../../../../app_service/service/contacts/dto/status_update
import app_service/common/types

import app_service/service/contacts/dto/profile_showcase

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onContactsLoaded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method switchToOrCreateOneToOneChat*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method sendContactRequest*(self: AccessInterface, publicKey: string, message: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method acceptContactRequest*(self: AccessInterface, publicKey: string, contactRequestId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method dismissContactRequest*(self: AccessInterface, publicKey: string, contactRequestId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method dismissContactRequests*(self: AccessInterface, publicKeysJSON: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getLatestContactRequestForContactAsJson*(self: AccessInterface, publicKey: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method changeContactNickname*(self: AccessInterface, publicKey: string, nickname: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method unblockContact*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method blockContact*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method removeContact*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

# Controller Delegate Interface

method addOrUpdateContactItem*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onContactRemoved*(self: AccessInterface, publicKey: string, displayName: string, theyRemovedUs: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method contactNicknameChanged*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method contactTrustStatusChanged*(self: AccessInterface, publicKey: string, trustStatus: TrustStatus) {.base.} =
  raise newException(ValueError, "No implementation available")

method onTrustStatusRemoved*(self: AccessInterface, publicKey: string): void {.base.} =
  raise newException(ValueError, "No implementation available")

method contactsStatusUpdated*(self: AccessInterface, statusUpdates: seq[StatusUpdateDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method markAsTrusted*(self: AccessInterface, publicKey: string): void {.base.} =
  raise newException(ValueError, "No implementation available")

method markUntrustworthy*(self: AccessInterface, publicKey: string): void {.base.} =
  raise newException(ValueError, "No implementation available")

method removeTrustStatus*(self: AccessInterface, publicKey: string): void {.base.} =
  raise newException(ValueError, "No implementation available")

method requestContactInfo*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onContactInfoRequestFinished*(self: AccessInterface, publicKey: string, ok: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method shareUserUrlWithData*(self: AccessInterface, pubkey: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method shareUserUrlWithChatKey*(self: AccessInterface, pubkey: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method shareUserUrlWithENS*(self: AccessInterface, pubkey: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method requestProfileShowcase*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onProfileShowcaseUpdated*(self: AccessInterface, publicKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadProfileShowcase*(self: AccessInterface, profileShowcase: ProfileShowcaseDto, validated: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method fetchProfileShowcaseAccountsByAddress*(self: AccessInterface, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onProfileShowcaseAccountsByAddressFetched*(self: AccessInterface, accounts: seq[ProfileShowcaseAccount]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getShowcaseCollectiblesModel*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method isShowcaseForAContactLoading*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")
