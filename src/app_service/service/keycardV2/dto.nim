import json, strutils
include ../../common/json_utils

type StateString* = enum
  UnknownReaderState = "unknown-reader-state"
  NoPCSC = "no-pcsc"
  InternalError = "internal-error"
  NoReadersFound = "no-readers-found"
  ReaderConnectionError = "reader-connection-error"
  WaitingForReader = "waiting-for-reader"
  WaitingForCard = "waiting-for-card"
  ConnectingCard = "connecting-card"
  ConnectionError = "connection-error"
  NotKeycard = "not-keycard"
  PairingError = "pairing-error"
  EmptyKeycard = "empty-keycard"
  NoAvailablePairingSlots = "no-available-pairing-slots"
  BlockedPIN = "blocked-pin" # PIN remaining attempts == 0
  BlockedPUK = "blocked-puk" # PUK remaining attempts == 0
  FactoryResetting = "factory-resetting"
  Ready = "ready"
  Authorized = "authorized"
  Cancelled = "cancelled" #user cancelled the operation


# NOTE: Keep in sync with KeycardState in ui/StatusQ/src/onboarding/enums.h
type KeycardState* = enum
  UnknownReaderState,
  NoPCSCService,
  PluginReader,
  InsertKeycard,
  ReadingKeycard,
  NotKeycard,
  MaxPairingSlotsReached,
  BlockedPIN,
  BlockedPUK,
  FactoryResetting,
  NotEmpty,
  Empty,
  Authorized,
  Cancelled

type KeycardInfoDto* = object
  initialized*: bool
  instanceUID*: string
  version*: string
  availableSlots*: int
  keyUID*: string

type KeycardStatusDto* = object
  remainingAttemptsPIN*: int
  remainingAttemptsPUK*: int
  keyInitialized*: bool
  path*: string

type
  WalletAccountDto* = object
    path*: string
    address*: string
    publicKey*: string

  CardMetadataDto* = object
    name*: string
    walletAccounts*: seq[WalletAccountDto]

type KeycardEventDto* = object
  stateString*: StateString
  state*: KeycardState
  keycardInfo*: KeycardInfoDto
  keycardStatus*: KeycardStatusDto
  metadata*: CardMetadataDto

type
  KeyDetailsV2* = object
    address*: string
    publicKey*: string
    privateKey*: string

type KeycardExportedExtendedPublicKeyDto* = object
  address*: string
  publicKey*: string
  chainCode*: string
  xpub*: string

type KeycardExportExtendedPublicKeyResultDto* = object
  extendedPublicKey*: KeycardExportedExtendedPublicKeyDto
  masterKeyAddress*: string

type KeycardExportedKeysDto* = object
  eip1581Key*: KeyDetailsV2
  encryptionKey*: KeyDetailsV2
  masterKey*: KeyDetailsV2
  walletKey*: KeyDetailsV2
  walletRootKey*: KeyDetailsV2
  whisperKey*: KeyDetailsV2
  masterKeyAddress*: string
  extendedPublicKey*: KeycardExportedExtendedPublicKeyDto

type KeycardExportedPublicKeysDto* = object
  masterKeyAddress*: string
  keys*: seq[KeyDetailsV2]

type KeycardSignatureDto* = object
  r*: string
  s*: string
  v*: int

proc fromStringStateToInt*(state: StateString): KeycardState =
  case state
  of StateString.UnknownReaderState:
    result = KeycardState.UnknownReaderState
  of StateString.NoPCSC:
    result = KeycardState.NoPCSCService
  of StateString.InternalError:
    result = KeycardState.UnknownReaderState
  of StateString.WaitingForReader:
    result = KeycardState.PluginReader
  of StateString.WaitingForCard:
    result = KeycardState.InsertKeycard
  of StateString.ConnectingCard:
    result = KeycardState.ReadingKeycard
  of StateString.ConnectionError:
    result = KeycardState.NoPCSCService # TODO Change the UI states to have a connection error state
  of StateString.NotKeycard:
    result = KeycardState.NotKeycard
  of StateString.PairingError:
    result = KeycardState.NoPCSCService # TODO Change the UI states to have a pairing error state
  of StateString.EmptyKeycard:
    result = KeycardState.Empty
  of StateString.NoAvailablePairingSlots:
    result = KeycardState.MaxPairingSlotsReached
  of StateString.BlockedPIN:
    result = KeycardState.BlockedPIN
  of StateString.BlockedPUK:
    result = KeycardState.BlockedPUK # TODO do we need a new state for the PUK lock or we don't use PUK anymore?
  of StateString.FactoryResetting:
    result = KeycardState.FactoryResetting
  of StateString.Ready:
    result = KeycardState.NotEmpty
  of StateString.Authorized:
    result = KeycardState.Authorized
  of StateString.Cancelled:
    result = KeycardState.Cancelled
  else:
    result = KeycardState.UnknownReaderState

proc toKeycardInfoDto*(jsonObj: JsonNode): KeycardInfoDto =
  result = KeycardInfoDto()
  discard jsonObj.getProp("initialized", result.initialized)
  discard jsonObj.getProp("instanceUID", result.instanceUID)
  discard jsonObj.getProp("version", result.version)
  discard jsonObj.getProp("availableSlots", result.availableSlots)
  if jsonObj.getProp("keyUID", result.keyUID) and
    result.keyUID.len > 0 and
    not result.keyUID.startsWith("0x"):
      result.keyUID = "0x" & result.keyUID

proc toKeycardStatusDto*(jsonObj: JsonNode): KeycardStatusDto =
  result = KeycardStatusDto()
  discard jsonObj.getProp("remainingAttemptsPIN", result.remainingAttemptsPIN)
  discard jsonObj.getProp("remainingAttemptsPUK", result.remainingAttemptsPUK)
  discard jsonObj.getProp("keyInitialized", result.keyInitialized)
  discard jsonObj.getProp("path", result.path)

proc toWalletAccountDto(jsonObj: JsonNode): WalletAccountDto =
  discard jsonObj.getProp("path", result.path)
  discard jsonObj.getProp("address", result.address)
  if jsonObj.getProp("publicKey", result.publicKey):
    result.publicKey = "0x" & result.publicKey

proc toCardMetadataDto*(jsonObj: JsonNode): CardMetadataDto =
  discard jsonObj.getProp("name", result.name)
  var accountsArr: JsonNode
  if jsonObj.getProp("wallets", accountsArr) and accountsArr.kind == JArray:
    for acc in accountsArr:
      result.walletAccounts.add(acc.toWalletAccountDto())

proc toKeycardEventDto*(jsonObj: JsonNode): KeycardEventDto =
  result = KeycardEventDto()

  try:
    result.stateString = parseEnum[StateString](jsonObj["state"].getStr)
    result.state = result.stateString.fromStringStateToInt
  except:
    result.state = KeycardState.UnknownReaderState

  var obj: JsonNode
  if jsonObj.getProp("keycardInfo", obj):
    result.keycardInfo = obj.toKeycardInfoDto

  if jsonObj.getProp("keycardStatus", obj):
    result.keycardStatus = obj.toKeycardStatusDto

  if jsonObj.getProp("metadata", obj):
    result.metadata = obj.toCardMetadataDto

proc toKeyDetails(jsonObj: JsonNode): KeyDetailsV2 =
  discard jsonObj.getProp("address", result.address)
  discard jsonObj.getProp("privateKey", result.privateKey)
  if jsonObj.getProp("publicKey", result.publicKey):
    if not result.publicKey.startsWith("0x"):
      result.publicKey = "0x" & result.publicKey

proc toKeycardExportedExtendedPublicKeyDto*(jsonObj: JsonNode): KeycardExportedExtendedPublicKeyDto =
  result = KeycardExportedExtendedPublicKeyDto()
  discard jsonObj.getProp("address", result.address)
  discard jsonObj.getProp("publicKey", result.publicKey)
  discard jsonObj.getProp("chainCode", result.chainCode)
  discard jsonObj.getProp("xpub", result.xpub)

proc toKeycardExportExtendedPublicKeyResultDto*(jsonObj: JsonNode): KeycardExportExtendedPublicKeyResultDto =
  result = KeycardExportExtendedPublicKeyResultDto()
  var obj: JsonNode
  if jsonObj.getProp("extendedPublicKey", obj):
    result.extendedPublicKey = toKeycardExportedExtendedPublicKeyDto(obj)
  discard jsonObj.getProp("masterKeyAddress", result.masterKeyAddress)

proc toKeycardExportedKeysDto*(jsonObj: JsonNode): KeycardExportedKeysDto =
  result = KeycardExportedKeysDto()

  var obj: JsonNode

  if jsonObj.getProp("eip1581", obj) or jsonObj.getProp("eip1581Key", obj):
    result.eip1581Key = toKeyDetails(obj)
  if jsonObj.getProp("encryptionPrivateKey", obj) or jsonObj.getProp("encryptionKey", obj):
    result.encryptionKey = toKeyDetails(obj)
  if jsonObj.getProp("masterKey", obj):
    result.masterKey = toKeyDetails(obj)
  if jsonObj.getProp("walletKey", obj):
    result.walletKey = toKeyDetails(obj)
  if jsonObj.getProp("walletRootKey", obj):
    result.walletRootKey = toKeyDetails(obj)
  if jsonObj.getProp("whisperPrivateKey", obj) or jsonObj.getProp("whisperKey", obj):
    result.whisperKey = toKeyDetails(obj)

  if jsonObj.getProp("extendedPublicKey", obj):
    result.extendedPublicKey = toKeycardExportedExtendedPublicKeyDto(obj)

proc toKeycardExportedPublicKeysDto*(jsonObj: JsonNode): KeycardExportedPublicKeysDto =
  result = KeycardExportedPublicKeysDto()
  discard jsonObj.getProp("masterKeyAddress", result.masterKeyAddress)
  var obj: JsonNode
  if jsonObj.getProp("exportedKeys", obj) and obj.kind == JArray:
    for key in obj:
      result.keys.add(toKeyDetails(key))

proc toKeycardSignatureDto*(jsonObj: JsonNode): KeycardSignatureDto =
  result = KeycardSignatureDto()
  discard jsonObj.getProp("r", result.r)
  discard jsonObj.getProp("s", result.s)
  discard jsonObj.getProp("v", result.v)