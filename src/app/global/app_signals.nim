from  ../modules/shared_models/section_item import SectionType

import ../core/eventemitter

export SectionType

type
  ToggleSectionArgs* = ref object of Args
    sectionType*: SectionType

const TOGGLE_SECTION* = "toggleSection"
## Emmiting this signal will turn on section/s with passed `sectionType` if that section type is
## turned off, or turn it off in case that section type is turned on.

type
  ActiveSectionChatArgs* = ref object of Args
    sectionId*: string
    chatId*: string
    messageId*: string

const SIGNAL_MAKE_SECTION_CHAT_ACTIVE* = "makeSectionChatActive"
## Emmiting this signal will switch the app to passed `sectionId`, after that if `chatId` is set
## it will make that chat an active one and at the end if `messageId` is set it will point to
## that message.


type
  StatusUrlAction* {.pure.} = enum
    OpenLinkInBrowser = 0
    DisplayUserProfile,
    OpenCommunity,
    OpenCommunityChannel

type
  StatusUrlArgs* = ref object of Args
    action*: StatusUrlAction
    communityId*:string
    chatId*: string
    url*: string
    userId*: string # can be public key or ens name

const SIGNAL_STATUS_URL_ACTIVATED* = "statusUrlActivated"

type
  ExternalUrlIntakeArgs* = ref object of Args
    url*: string

const SIGNAL_EXTERNAL_URL_INTAKE_BROWSER_TAB* = "externalUrlIntakeBrowserTab"
## Emitted for an externally received web URL that is not a Status link
## (browser candidacy): it must open as a new tab in the in-app browser with
## the browser section foregrounded.

type
  ExternalShareIntakeArgs* = ref object of Args
    text*: string

const SIGNAL_EXTERNAL_SHARE_INTAKE* = "externalShareIntake"
## Emitted for content shared to Status from another app (share target):
## it must launch the share flow (destination picker -> preview -> send).
## Text and links both arrive as `text`.

const SIGNAL_MAIN_LOADED* = "signalMainLoaded"

type
  WalletAddressesArgs* = ref object of Args
    addresses*: seq[string]

const MARK_WALLET_ADDRESSES_AS_SHOWN* = "markWalletAddressesAsShown"
