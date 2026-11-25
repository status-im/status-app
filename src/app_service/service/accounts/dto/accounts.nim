{.used.}

import json
import app_service/service/contacts/dto/contacts

include app_service/common/json_utils

type AccountDto* = object
  name*: string
  timestamp*: int64
  keycardPairing*: string
  keyUid*: string
  images*: Images
  colorId*: int
  kdfIterations*: int
  zeroOnboarded*: bool

type WakuBackedUpProfileDto* = object
  displayName*: string
  images*: Images

proc isValid*(self: AccountDto): bool =
  result = self.name.len > 0 and self.keyUid.len > 0

proc toAccountDto*(jsonObj: JsonNode): AccountDto =
  result = AccountDto()
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("timestamp", result.timestamp)
  discard jsonObj.getProp("keycard-pairing", result.keycardPairing)
  discard jsonObj.getProp("key-uid", result.keyUid)
  discard jsonObj.getProp("colorId", result.colorId)
  discard jsonObj.getProp("kdfIterations", result.kdfIterations)
  discard jsonObj.getProp("zeroOnboarded", result.zeroOnboarded)

  var imagesObj: JsonNode
  if jsonObj.getProp("images", imagesObj) and imagesObj.kind == JArray:
    result.images = imagesObj.toImagesFromArray()

proc contains*(accounts: seq[AccountDto], keyUid: string): bool =
  for account in accounts:
    if (account.keyUid == keyUid):
      return true
  return false

proc toWakuBackedUpProfileDto*(jsonObj: JsonNode): WakuBackedUpProfileDto =
  result = WakuBackedUpProfileDto()
  discard jsonObj.getProp("displayName", result.displayName)

  var imagesObj: JsonNode
  if jsonObj.getProp("images", imagesObj) and imagesObj.kind == JArray:
    result.images = imagesObj.toImagesFromArray()
