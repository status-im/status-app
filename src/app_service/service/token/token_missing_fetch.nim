## Pure decode-and-release step for the async missing-tokens batch fetch.
##
## The GUI slot (onAsyncFetchMissingTokensDone) receives the worker's finished
## batch as a string envelope; this module decodes it and releases the batch's
## keys from the in-flight set. Split out of the slot so the release contract is
## unit-testable without a live Service or backend — same pattern as
## token_pending_fetch / token_apply_builder.

import std/[sets, strutils, tables]
import json_serialization

import app_service/common/utils as common_utils
import dto/token
import items/token_group
import token_pending_fetch

type FetchMissingTokensResponse* = object
  requestedKeys*: seq[string] # echoed back so the slot knows which keys were asked for
  tokens*: seq[TokenDtoSafe]  # the subset the backend actually resolved
  error*: string

proc decodeAndCompleteBatch*(fetch: var PendingTokenFetch, response: string):
    tuple[env: FetchMissingTokensResponse, decodeError: string] =
  ## Decode a finished batch's envelope and release its keys from the in-flight
  ## set. Returns the decoded envelope, or a non-empty decodeError when the
  ## envelope itself was undecodable. The keys are released on EVERY outcome:
  ## a key left in flight can never re-enqueue, so it would wedge (stop
  ## resolving) for the rest of the session.
  var decoded: tuple[env: FetchMissingTokensResponse, decodeError: string]
  try:
    decoded.env = Json.decode(response, FetchMissingTokensResponse, allowUnknownFields = true)
    fetch.completeBatch(decoded.env.requestedKeys)
  except Exception as e:
    # The batch's own key list is unknown when its envelope is undecodable, so
    # drain the whole in-flight set (see drainInFlight for why that is safe);
    # the drained keys stand in for the batch's so the caller can retry them.
    decoded.env.requestedKeys = fetch.drainInFlight()
    decoded.decodeError = e.msg
  return decoded

type MissingFetchNotice* {.pure.} = enum
  None
  TokensListUpdated ## tokens were found: the token list changed
  KeysSettled       ## keys only settled as missing: just the lookups' consumers re-read

proc batchNotice*(foundCount: int, settledMissingCount: int): MissingFetchNotice =
  if foundCount > 0:
    return MissingFetchNotice.TokensListUpdated
  if settledMissingCount > 0:
    return MissingFetchNotice.KeysSettled
  return MissingFetchNotice.None

type TokenItemFactory* = proc(dto: TokenDto): TokenItem {.closure.}

proc newTokenItem(dto: TokenDto): TokenItem =
  createTokenItem(dto)

proc applyMissingTokensBatch*(fetch: var PendingTokenFetch, env: FetchMissingTokensResponse,
    tokensByKey: var Table[string, TokenItem],
    groupsByKey: var Table[string, TokenGroupItem],
    knownMissingKeys: var HashSet[string],
    makeToken: TokenItemFactory = newTokenItem): MissingFetchNotice =
  ## Cache a decoded batch: each found token under the exact key requested (a
  ## checksummed request must Hit on its next lookup), the rest as known missing.
  ## All-or-nothing: on a raise no cache is touched, so a retry still sees the
  ## keys as unsettled.
  var dtoByLowerKey = initTable[string, TokenDto]()
  for dto in env.tokens:
    dtoByLowerKey[createTokenKey(dto.chainId, dto.address).toLowerAscii] = dto
  var tokenByLowerKey = initTable[string, TokenItem]()
  var found: seq[tuple[key: string, token: TokenItem]]
  var foundKeys = initHashSet[string]()
  # Groups are refs shared with the cache: stage copies, never mutate in place.
  var stagedGroups = initTable[string, TokenGroupItem]()
  for requestedKey in env.requestedKeys:
    let lowerKey = requestedKey.toLowerAscii
    if not dtoByLowerKey.hasKey(lowerKey):
      continue
    if not tokenByLowerKey.hasKey(lowerKey):
      tokenByLowerKey[lowerKey] = makeToken(dtoByLowerKey[lowerKey])
    let token = tokenByLowerKey[lowerKey]
    if not stagedGroups.hasKey(token.groupKey):
      let existing = groupsByKey.getOrDefault(token.groupKey)
      if existing.isNil:
        stagedGroups[token.groupKey] = TokenGroupItem(key: token.groupKey, name: token.name,
          symbol: token.symbol, decimals: token.decimals, logoUri: token.logoUri)
      else:
        stagedGroups[token.groupKey] = existing.copyGroup()
    stagedGroups[token.groupKey].addToken(token)
    found.add((requestedKey, token))
    foundKeys.incl(requestedKey)
  let missingKeys = missingFromBatch(env.requestedKeys, foundKeys)

  for (key, token) in found:
    tokensByKey[key] = token
  for groupKey, group in stagedGroups:
    groupsByKey[groupKey] = group
  for key in missingKeys:
    knownMissingKeys.incl(key)
  fetch.settleKeys(env.requestedKeys)
  return batchNotice(foundKeys.len, missingKeys.len)

proc failMissingTokensBatch*(fetch: var PendingTokenFetch, keys: seq[string],
    knownMissingKeys: var HashSet[string]): tuple[retryTiers: seq[int], gaveUp: seq[string], notice: MissingFetchNotice] =
  ## Park a failed batch's keys for a retry; those out of tries settle as missing
  ## until the next refresh.
  let (retryTiers, gaveUp) = fetch.failBatch(keys)
  for key in gaveUp:
    knownMissingKeys.incl(key)
  return (retryTiers, gaveUp, batchNotice(foundCount = 0, settledMissingCount = gaveUp.len))

proc isMissingKeySettled*(key: string, tokensByKey: Table[string, TokenItem],
    knownMissingKeys: HashSet[string]): bool =
  tokensByKey.hasKey(key) or key in knownMissingKeys
