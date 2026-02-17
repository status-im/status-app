import strutils

type
  KeyDetails* = object
    address*: string
    publicKey*: string
    privateKey*: string

  ApplicationInfo* = object
    initialized*: bool
    instanceUID*: string
    version*: int
    availableSlots*: int
    keyUID*: string

  WalletAccount* = object
    path*: string
    address*: string
    publicKey*: string

  GeneratedWalletAccount* = object
    address*: string
    publicKey*: string
    privateKey*: string

  CardMetadata* = object
    name*: string
    walletAccounts*: seq[WalletAccount]

  TransactionSignature* = object
    r*: string
    s*: string
    v*: string

  KeycardEvent* = object
    error*: string
    cancelled*: bool
    instanceUID*: string
    applicationInfo*: ApplicationInfo
    seedPhraseIndexes*: seq[int]
    freePairingSlots*: int
    keyUid*: string
    pinRetries*: int
    pukRetries*: int
    cardMetadata*: CardMetadata
    generatedWalletAccount*: GeneratedWalletAccount
    generatedWalletAccounts*: seq[GeneratedWalletAccount]
    txSignature*: TransactionSignature
    eip1581Key*: KeyDetails
    encryptionKey*: KeyDetails
    masterKey*: KeyDetails
    walletKey*: KeyDetails
    walletRootKey*: KeyDetails
    whisperKey*: KeyDetails
    masterKeyAddress*: string

proc toKeyDetails(jsonObj: JsonNode): KeyDetails =
  discard jsonObj.getProp(ResponseParamAddress, result.address)
  discard jsonObj.getProp(ResponseParamPrivateKey, result.privateKey)
  if jsonObj.getProp(ResponseParamPublicKey, result.publicKey):
    result.publicKey = "0x" & result.publicKey

proc toApplicationInfo(jsonObj: JsonNode): ApplicationInfo =
  discard jsonObj.getProp(ResponseParamInitialized, result.initialized)
  discard jsonObj.getProp(ResponseParamAppInfoInstanceUID, result.instanceUID)
  discard jsonObj.getProp(ResponseParamVersion, result.version)
  discard jsonObj.getProp(ResponseParamAvailableSlots, result.availableSlots)
  discard jsonObj.getProp(ResponseParamAppInfoKeyUID, result.keyUID)

proc toWalletAccount(jsonObj: JsonNode): WalletAccount =
  discard jsonObj.getProp(ResponseParamPath, result.path)
  discard jsonObj.getProp(ResponseParamAddress, result.address)
  if jsonObj.getProp(ResponseParamPublicKey, result.publicKey):
    result.publicKey = "0x" & result.publicKey

proc toGeneratedWalletAccount(jsonObj: JsonNode): GeneratedWalletAccount =
  discard jsonObj.getProp(ResponseParamAddress, result.address)
  if jsonObj.getProp(ResponseParamPublicKey, result.publicKey) and not result.publicKey.startsWith("0x"):
    result.publicKey = "0x" & result.publicKey
  if jsonObj.getProp(ResponseParamPrivateKey, result.privateKey) and not result.privateKey.startsWith("0x"):
    result.privateKey = "0x" & result.privateKey

proc toCardMetadata(jsonObj: JsonNode): CardMetadata =
  discard jsonObj.getProp(ResponseParamName, result.name)
  var accountsArr: JsonNode
  if jsonObj.getProp(ResponseParamWallets, accountsArr) and accountsArr.kind == JArray:
    for acc in accountsArr:
      result.walletAccounts.add(acc.toWalletAccount())

proc toTransactionSignature(jsonObj: JsonNode): TransactionSignature =
  discard jsonObj.getProp(ResponseParamTxSignatureR, result.r)
  discard jsonObj.getProp(ResponseParamTxSignatureS, result.s)
  var v: int
  discard jsonObj.getProp(ResponseParamTxSignatureV, v)
  result.v = "00"
  if v == 1:
    result.v = "01"

proc toKeycardEvent*(jsonObj: JsonNode): KeycardEvent =
  discard jsonObj.getProp(ResponseParamErrorKey, result.error)
  discard jsonObj.getProp(ResponseParamCancelled, result.cancelled)
  discard jsonObj.getProp(ResponseParamInstanceUID, result.instanceUID)
  discard jsonObj.getProp(ResponseParamFreeSlots, result.freePairingSlots)
  discard jsonObj.getProp(ResponseParamPINRetries, result.pinRetries)
  discard jsonObj.getProp(ResponseParamPUKRetries, result.pukRetries)
  discard jsonObj.getProp(ResponseParamMasterKeyAddress, result.masterKeyAddress)
  if jsonObj.getProp(ResponseParamKeyUID, result.keyUid) and
    result.keyUid.len > 0 and
    not result.keyUid.startsWith("0x"):
      result.keyUid = "0x" & result.keyUid

  var obj: JsonNode
  if(jsonObj.getProp(ResponseParamAppInfo, obj)):
    result.applicationInfo = toApplicationInfo(obj)

  if(jsonObj.getProp(ResponseParamEIP1581Key, obj)):
    result.eip1581Key = toKeyDetails(obj)

  if(jsonObj.getProp(ResponseParamEncKey, obj)):
    result.encryptionKey = toKeyDetails(obj)

  if(jsonObj.getProp(ResponseParamMasterKey, obj)):
    result.masterKey = toKeyDetails(obj)

  if(jsonObj.getProp(ResponseParamWalletKey, obj)):
    result.walletKey = toKeyDetails(obj)

  if(jsonObj.getProp(ResponseParamWalletRootKey, obj)):
    result.walletRootKey = toKeyDetails(obj)

  if(jsonObj.getProp(ResponseParamWhisperKey, obj)):
    result.whisperKey = toKeyDetails(obj)

  var indexesArr: JsonNode
  if jsonObj.getProp(ResponseParamMnemonicIdxs, indexesArr) and indexesArr.kind == JArray:
    for ind in indexesArr:
      result.seedPhraseIndexes.add(ind.getInt)

  if(jsonObj.getProp(ResponseParamCardMeta, obj)):
    result.cardMetadata = toCardMetadata(obj)

  if jsonObj.getProp(ResponseParamExportedKey, obj):
    if obj.kind == JArray:
      for o in obj:
        result.generatedWalletAccounts.add(toGeneratedWalletAccount(o))
    else:
      result.generatedWalletAccount = toGeneratedWalletAccount(obj)

  if(jsonObj.getProp(ResponseParamTXSignature, obj)):
    result.txSignature = toTransactionSignature(obj)