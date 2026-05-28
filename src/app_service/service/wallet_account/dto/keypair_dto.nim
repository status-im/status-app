import tables, json, std/strformat, strutils, sequtils, sugar, chronicles

import account_dto
import keycard_dto

include  app_service/common/json_utils

export account_dto
export keycard_dto

const KeypairTypeProfile* = "profile"
const KeypairTypeSeed* = "seed"
const KeypairTypeKey* = "key"

const SyncedFromBackup* = "backup" # means a keypair is coming from backed up data

const
  ColdWalletTypeNoNone* = ""
  ColdWalletTypeStatusKeycard* = "status-keycard"
  ColdWalletTypeLedger* = "ledger"
  ColdWalletTypeTrezor* = "trezor"

type
  KeypairDto* = ref object of RootObj
    keyUid*: string
    name*: string
    keypairType*: string
    derivedFrom*: string
    lastUsedDerivationIndex*: int
    syncedFrom*: string
    accounts*: seq[WalletAccountDto]
    removed*: bool
    extendedPublicKey*: string
    coldWalletType*: string

proc migratedToColdWallet*(self: KeypairDto): bool =
  return self.coldWalletType != ColdWalletTypeNoNone

proc toKeypairDto*(jsonObj: JsonNode): KeypairDto =
  result = KeypairDto()
  discard jsonObj.getProp("key-uid", result.keyUid)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("type", result.keypairType)
  discard jsonObj.getProp("derived-from", result.derivedFrom)
  discard jsonObj.getProp("last-used-derivation-index", result.lastUsedDerivationIndex)
  discard jsonObj.getProp("synced-from", result.syncedFrom)
  discard jsonObj.getProp("removed", result.removed)
  discard jsonObj.getProp("xpub", result.extendedPublicKey)
  discard jsonObj.getProp("cold-wallet", result.coldWalletType)

  if not result.removed:
    if result.keypairType != KeypairTypeProfile and
      result.keypairType != KeypairTypeSeed and
      result.keypairType != KeypairTypeKey:
        error "unknown keypair type", kpType=result.keypairType

  var accountsObj: JsonNode
  if jsonObj.getProp("accounts", accountsObj) and accountsObj.kind != JNull:
    for accObj in accountsObj:
      result.accounts.add(toWalletAccountDto(accObj))

proc `$`*(self: KeypairDto): string =
  result = fmt"""KeypairDto[
    keyUid: {self.keyUid},
    name: {self.name},
    type: {self.keypairType},
    derivedFrom: {self.derivedFrom},
    lastUsedDerivationIndex: {self.lastUsedDerivationIndex},
    syncedFrom: {self.syncedFrom},
    extendedPublicKey: {self.extendedPublicKey},
    coldWalletType: {self.coldWalletType},
    accounts:
  """
  for i in 0 ..< self.accounts.len:
    result &= fmt"""
    [{i}]:({$self.accounts[i]})
    """
  result &= """
    ]"""

proc getOperability*(self: KeypairDto): string =
  if self.accounts.any(x => x.operable == AccountNonOperable):
    return AccountNonOperable
  if self.accounts.any(x => x.operable == AccountPartiallyOperable):
    return AccountPartiallyOperable
  return AccountFullyOperable