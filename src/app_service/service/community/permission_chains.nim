import std/[json, tables, sets, sequtils, strutils]
import json_serialization, json_serialization/std/tables as ser_tables

import ./dto/community
import ./dto/roster
import ../../common/types
import ../../common/utils as common_utils

type
  CatalogueToken* = object
    key*: string
    groupKey*: string # cross-chain id, or `key` for a token without one
    chainId*: int
    address*: string
    name*: string
    symbol*: string
    decimals*: int
    communityId*: string

  # Both lookups raise when the backend can't answer.
  TokenCatalogue* = object
    byKeys*: proc(keys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.}
    byGroupKeys*: proc(groupKeys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.}

  SaveCriterion* = object
    key*: string
    criterion*: TokenCriteriaDto

  # Chains of the admin's current network mode (test or main), and of the other one.
  ModeChains* = object
    current*: seq[int]
    other*: seq[int]

  CriteriaChainsResult* = object
    criteria*: seq[TokenCriteriaDto]
    error*: string

  # Creates or edits the permission, returning the RPC result; raises on failure.
  SavePermissionRpc* = proc(communityId: string, permission: CommunityTokenPermissionDto): JsonNode {.closure, gcsafe.}

  PermissionSaveResult* {.acyclic.} = ref object of RootObj
    communityId*: string
    permission*: CommunityTokenPermissionDto
    rosterDeltas*: seq[RosterDelta]
    error*: string

proc tokenKeyOf(key: string): string =
  if not common_utils.isTokenKey(key):
    return ""
  try:
    return common_utils.communityKeyToTokenKey(key)
  except ValueError:
    return ""

proc storedTokenKeys(criterion: TokenCriteriaDto): seq[string] =
  if criterion.`type` != TokenType.ERC20:
    return
  for chainId, address in criterion.contractAddresses:
    result.add(common_utils.createTokenKey(chainId, address))

proc resolveCriteriaChains*(toSave: seq[SaveCriterion], stored: seq[TokenCriteriaDto],
    modes: ModeChains, catalogue: TokenCatalogue): CriteriaChainsResult =
  ## An ERC20 criterion keeps every chain a stored criterion of the same group lists
  ## (a save never narrows a permission) and gets the group's chains of the stored
  ## chains' network modes; a token not stored yet gets those of the current mode.
  ## Other criteria pass through untouched.
  if not toSave.anyIt(it.criterion.`type` == TokenType.ERC20):
    return CriteriaChainsResult(criteria: toSave.mapIt(it.criterion))

  let currentChains = modes.current.toHashSet
  let otherChains = modes.other.toHashSet
  let storedKeys = stored.map(storedTokenKeys)
  var tokensByKey = initTable[string, CatalogueToken]()
  var groupTokens = initTable[string, seq[CatalogueToken]]()
  var groups = newSeq[string](toSave.len)

  proc groupOf(tokenKey: string): string =
    if tokensByKey.hasKey(tokenKey): tokensByKey[tokenKey].groupKey else: tokenKey

  try:
    var keys: seq[string]
    for c in toSave:
      if c.criterion.`type` == TokenType.ERC20:
        let tokenKey = tokenKeyOf(c.key)
        if tokenKey.len > 0:
          keys.add(tokenKey)
    # GetTokensByKeys applies no network-mode filter, so stored keys of the other
    # mode still resolve to their group.
    for sk in storedKeys:
      keys.add(sk)
    if keys.len > 0:
      for token in catalogue.byKeys(keys.deduplicate):
        tokensByKey[common_utils.createTokenKey(token.chainId, token.address)] = token

    for i, c in toSave:
      if c.criterion.`type` != TokenType.ERC20:
        continue
      let tokenKey = tokenKeyOf(c.key)
      if tokenKey.len == 0:
        groups[i] = c.key
      elif tokensByKey.getOrDefault(tokenKey).communityId.len == 0:
        groups[i] = groupOf(tokenKey)
    let groupKeys = groups.filterIt(it.len > 0).deduplicate
    if groupKeys.len > 0:
      for token in catalogue.byGroupKeys(groupKeys):
        groupTokens.mgetOrPut(token.groupKey, @[]).add(token)
  except CatchableError as e:
    return CriteriaChainsResult(error: e.msg)

  var criteria: seq[TokenCriteriaDto]
  for i, c in toSave:
    var criterion = c.criterion
    if criterion.`type` != TokenType.ERC20:
      criteria.add(criterion)
      continue

    let tokenKey = tokenKeyOf(c.key)
    let group = groups[i]
    var addresses = initTable[int, string]()
    for s, sk in storedKeys:
      if sk.anyIt(it == tokenKey or (group.len > 0 and groupOf(it) == group)):
        for chainId, address in stored[s].contractAddresses:
          addresses[chainId] = address

    # Chains in neither mode (dropped networks) leave the mode to the admin's.
    let storedOther = toSeq(addresses.keys).anyIt(it in otherChains)
    var modeChains: HashSet[int]
    if not storedOther or toSeq(addresses.keys).anyIt(it in currentChains):
      modeChains.incl(currentChains)
    if storedOther:
      modeChains.incl(otherChains)

    var data: CatalogueToken
    var hasData = false
    for token in groupTokens.getOrDefault(group):
      if token.chainId in modeChains:
        discard addresses.hasKeyOrPut(token.chainId, token.address)
        data = token
        hasData = true

    if tokenKey.len > 0:
      if tokensByKey.hasKey(tokenKey):
        let own = tokensByKey[tokenKey]
        # Kept outside the mode only when it's the criterion's sole chain.
        if own.chainId in modeChains or addresses.len == 0:
          discard addresses.hasKeyOrPut(own.chainId, own.address)
        if not hasData:
          data = own
          hasData = true
      else:
        var unresolved = criterion
        if not unresolved.applyUnresolvedTokenKey(c.key):
          return CriteriaChainsResult(error: "invalid token key: " & c.key)
        for chainId, address in unresolved.contractAddresses:
          discard addresses.hasKeyOrPut(chainId, address)

    if addresses.len == 0:
      return CriteriaChainsResult(error: "no chains for token: " & c.key)
    if hasData:
      criterion.applyResolvedTokenData(data.name, data.symbol, data.decimals)
    criterion.contractAddresses = addresses
    criteria.add(criterion)
  return CriteriaChainsResult(criteria: criteria)

# The worker hand-off can't use json_serialization for criteria: it doesn't read
# back the numeric TokenType it writes.
proc criteriaToJson*(criteria: seq[TokenCriteriaDto]): string =
  Json.encode(criteria)

proc criteriaFromJson*(json: string): seq[TokenCriteriaDto] =
  for criterion in parseJson(json):
    result.add(criterion.toTokenCriteriaDto)

proc toCatalogueToken*(json: JsonNode): CatalogueToken =
  result.chainId = json{"chainId"}.getInt
  result.address = json{"address"}.getStr
  result.name = json{"name"}.getStr
  result.symbol = json{"symbol"}.getStr
  result.decimals = json{"decimals"}.getInt
  result.communityId = json{"communityData"}{"id"}.getStr
  result.key = common_utils.createTokenKey(result.chainId, result.address)
  result.groupKey = json{"crossChainId"}.getStr
  if result.groupKey.isEmptyOrWhitespace:
    result.groupKey = result.key

proc saveTokenPermission*(communityId: string, permission: CommunityTokenPermissionDto,
    toSave: seq[SaveCriterion], stored: seq[TokenCriteriaDto], modes: ModeChains,
    catalogue: TokenCatalogue, save: SavePermissionRpc): PermissionSaveResult =
  result = PermissionSaveResult(communityId: communityId, permission: permission)
  let resolved = resolveCriteriaChains(toSave, stored, modes, catalogue)
  if resolved.error.len > 0:
    result.error = resolved.error
    return
  result.permission.tokenCriteria = resolved.criteria
  try:
    let response = save(communityId, result.permission)
    if response.isNil or response.kind == JNull:
      result.error = "no result returned from create/edit community token permission"
      return
    result.rosterDeltas = parseRosterDeltas(response{"communityChanges"})
  except CatchableError as e:
    result.error = e.msg
