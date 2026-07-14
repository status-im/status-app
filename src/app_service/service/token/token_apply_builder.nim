## Pure worker-side token-apply builder.
##
## Given the raw RPC response JSON, produce the COMPLETE finished structures the
## GUI slot currently builds inline in `applyRefreshTokensData` /
## `applyAllTokenListsData` (service_main.nim). Running this on the threadpool and
## handing the result to the GUI slot via the typed-completion primitive
## (finishTyped/takeTyped) removes the multi-MB JSON decode + token-model build
## from the GUI thread.
##
## Byte-identical contract: this replicates the current GUI-thread build exactly
## on the same inputs, so a token-model dump is identical pre/post migration. The
## swap-vs-keep decision (shouldReplaceTokensCache) stays on the GUI slot because
## it depends on the live prior-cache size; the builder therefore builds
## unconditionally and carries `tokensOfInterestCount` / `allTokensCount` so the
## slot can run that cheap gate before swapping.
##
## Pure: no Service, no threadpool, no backend — unit-testable against fixture JSON.

import json, tables, sequtils, sugar
import json_serialization

import items/token, items/token_group, items/token_list, items/preferences
import dto/token, dto/token_list, dto/token_preferences
import token_lookup_cache

type
  RefreshTokensApplyResult* = ref object of RootObj
    generation*: int                                     ## generation stamp, echoed to the slot's onCompletion
    error*: string                                       ## non-empty -> slot skips apply (after onCompletion)
    tokensOfInterestCount*: int                          ## gate input for the slot
    tokensOfInterestByKey*: Table[string, TokenItem]
    groupsOfInterestByKey*: Table[string, TokenGroupItem]
    groupsOfInterest*: seq[TokenGroupItem]
    tokenPreferencesJson*: string                        ## backend array verbatim, for QML
    tokenPreferences*: seq[TokenPreferencesItem]         ## decoded rows, slot merges into its table
    allTokensCount*: int                                 ## gate input for the slot
    allTokensByGroupKey*: Table[string, seq[TokenItem]]

  AllTokenListsApplyResult* = ref object of RootObj
    generation*: int
    error*: string
    allTokenLists*: seq[TokenListItem]

proc createTokenGroupsFromTokens(tokens: seq[TokenItem], groupsByKey: var Table[string, TokenGroupItem]) =
  # Byte-identical replica of the private helper in service_main.nim (grouping by
  # token.groupKey; the group inherits the first token's name/symbol/decimals/logo).
  for token in tokens:
    let groupKey = token.groupKey
    if not groupsByKey.hasKey(groupKey):
      groupsByKey[groupKey] = TokenGroupItem(
        key: groupKey,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
        logoUri: token.logoUri
      )
    groupsByKey[groupKey].addToken(token)

proc decodeTokens(node: JsonNode): seq[TokenDtoSafe] =
  if node.isNil or node.kind != JArray or node.len == 0:
    return @[]
  Json.decode($node, seq[TokenDtoSafe], allowUnknownFields = true)

proc buildRefreshTokensApply*(tokensOfInterestNode, allTokensNode, tokenPrefsNode: JsonNode): RefreshTokensApplyResult =
  ## Build the finished tokens-of-interest / groups / preferences / all-tokens
  ## structures from the three raw RPC response nodes.
  result = RefreshTokensApplyResult()

  let tokens = decodeTokens(tokensOfInterestNode).map(t => createTokenItem(t))
  result.tokensOfInterestCount = tokens.len
  result.tokensOfInterestByKey = buildTokensByKey(tokens)
  var groupsByKey = initTable[string, TokenGroupItem]()
  createTokenGroupsFromTokens(tokens, groupsByKey)
  result.groupsOfInterestByKey = groupsByKey
  result.groupsOfInterest = toSeq(groupsByKey.values)
  sortTokenGroupsByKey(result.groupsOfInterest)  # deterministic order

  # Preferences: keep the backend array string for QML; decode rows for the table.
  # Matches applyRefreshTokensData exactly (including the "[]" default).
  result.tokenPreferencesJson = "[]"
  if not tokenPrefsNode.isNil and tokenPrefsNode.kind == JArray:
    result.tokenPreferencesJson = $tokenPrefsNode
    for preferences in tokenPrefsNode:
      let dto = Json.decode($preferences, TokenPreferencesDto, allowUnknownFields = true)
      result.tokenPreferences.add TokenPreferencesItem(
        key: dto.key,
        position: dto.position,
        groupPosition: dto.groupPosition,
        visible: dto.visible,
        communityId: dto.communityId)

  let allTokens = decodeTokens(allTokensNode).map(t => createTokenItem(t))
  result.allTokensCount = allTokens.len
  var newAllByGroup = initTable[string, seq[TokenItem]]()
  for item in allTokens:
    newAllByGroup.mgetOrPut(item.groupKey, @[]).add(item)
  result.allTokensByGroupKey = newAllByGroup

proc buildAllTokenListsApply*(allTokenListsNode: JsonNode): AllTokenListsApplyResult =
  ## Build the finished token-list items from the raw all-token-lists RPC node.
  result = AllTokenListsApplyResult()
  if allTokenListsNode.isNil or allTokenListsNode.kind != JArray or allTokenListsNode.len == 0:
    return
  let dtos = Json.decode($allTokenListsNode, seq[TokenListDto], allowUnknownFields = true)
  result.allTokenLists = dtos.map(tl => createTokenListItem(tl))

# --- Worker-side assembly: what the threadpool task hands to finishTyped ----------
# These wrap the pure builders with the transport concerns (generation stamp,
# error passthrough) and — critically — GUARANTEE a non-nil result even on an RPC
# error or a build exception. The worker always calls finishTyped(result), so the
# GUI slot always runs and the generation coordinator never wedges its
# in-flight gate (deadlock-safety). Building here also keeps the heavy decode +
# token-model construction off the GUI thread.

# The build catches `Exception`, NOT `CatchableError`: a Defect (e.g. OutOfMemDefect
# building the multi-MB token model on a memory-pressured wake — exactly this
# path) is not a CatchableError. With --panics:off it is catchable as Exception, so
# catching Exception keeps the result non-nil there too. If a Defect escaped
# assemble*, the worker would skip finishTyped and the in-flight gate would
# wedge permanently (no more token refreshes until app restart). The worker adds a
# structural finally as a second guarantee (see async_tasks.nim).

proc assembleRefreshResult*(tokensOfInterestNode, allTokensNode, tokenPrefsNode: JsonNode,
                            generation: int, rpcError: string): RefreshTokensApplyResult =
  if rpcError.len > 0:
    result = RefreshTokensApplyResult(error: rpcError)
  else:
    try:
      result = buildRefreshTokensApply(tokensOfInterestNode, allTokensNode, tokenPrefsNode)
    except Exception as e:
      result = RefreshTokensApplyResult(error: "Error building refresh tokens result: " & e.msg)
  result.generation = generation

proc assembleAllTokenListsResult*(allTokenListsNode: JsonNode,
                                  generation: int, rpcError: string): AllTokenListsApplyResult =
  if rpcError.len > 0:
    result = AllTokenListsApplyResult(error: rpcError)
  else:
    try:
      result = buildAllTokenListsApply(allTokenListsNode)
    except Exception as e:
      result = AllTokenListsApplyResult(error: "Error building token lists result: " & e.msg)
  result.generation = generation
