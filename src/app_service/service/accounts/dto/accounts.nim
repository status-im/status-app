{.used.}

import json, strutils, options
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

  var imagesObj: JsonNode
  if jsonObj.getProp("images", imagesObj) and imagesObj.kind == JArray:
    result.images = imagesObj.toImagesFromArray()

# The login state status-go reports (GetLoginState).
# NOTE: Keep in sync with LoginState in ui/StatusQ/src/onboarding/enums.h
type LoginState* {.pure.} = enum
  None = "none"
  InProgress = "inProgress"
  LoggedIn = "loggedIn"

# The errors status-go rejects a login request with while another login is in progress
# or a session is logged in. NOTE: Keep in sync with ErrLoginInProgress and
# ErrAlreadyLoggedIn in vendor/status-go/pkg/backend/login_state.go
const LOGIN_IN_PROGRESS_ERROR* = "a login is already in progress"
const ALREADY_LOGGED_IN_ERROR* = "already logged in"

# The login seq of a login response or node.login; none when status-go didn't send one.
proc toLoginSeq*(jsonObj: JsonNode): Option[uint64] =
  let seqObj = jsonObj{"seq"}
  if seqObj == nil or seqObj.kind != JInt:
    return none(uint64)
  return some(seqObj.getBiggestInt.uint64)

# seq: the login sequence number of the current or last login, also on its node.login
type LoginStateDto* = object
  state*: LoginState
  seq*: uint64
  account*: AccountDto

# Logged in without a usable account reads as none, as GetActiveAccount did.
proc toLoginStateDto*(jsonObj: JsonNode): LoginStateDto =
  result.state = parseEnum[LoginState](jsonObj{"state"}.getStr, LoginState.None)
  result.seq = jsonObj{"seq"}.getBiggestInt.uint64
  if result.state != LoginState.LoggedIn:
    return
  let accountObj = jsonObj{"account"}
  if accountObj != nil and accountObj.kind == JObject:
    result.account = toAccountDto(accountObj)
  if not result.account.isValid():
    result.state = LoginState.None

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
