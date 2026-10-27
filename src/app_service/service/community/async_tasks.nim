include ../../common/json_utils
include ../../../app/core/tasks/common

type
  AsyncLoadCommunitiesDataTaskArg = ref object of QObjectTaskArg

proc asyncLoadCommunitiesDataTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncLoadCommunitiesDataTaskArg](argEncoded)
  try:
    let responseTags = status_go.getCommunityTags()
    let responseCommunities = status_go.getAllCommunities()
    let responseSettings = status_go.getCommunitiesSettings()
    let responseNonApprovedRequestsToJoin = status_go.allNonApprovedCommunitiesRequestsToJoin()
    let responseCollapsedCommunityCategories = status_go.collapsedCommunityCategories()

    arg.finish(%* {
      "tags": responseTags,
      "communities": responseCommunities,
      "settings": responseSettings,
      "nonAprrovedRequestsToJoin": responseNonApprovedRequestsToJoin,
      "collapsedCommunityCategories": responseCollapsedCommunityCategories,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

type
  AsyncCollectCommunityMetricsTaskArg = ref object of QObjectTaskArg
    communityId: string
    metricsType: CommunityMetricsType
    intervals: JsonNode

proc asyncCollectCommunityMetricsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCollectCommunityMetricsTaskArg](argEncoded)
  try:
    let response = status_go.collectCommunityMetrics(arg.communityId, arg.metricsType.int, arg.intervals)
    arg.finish(%* {
      "communityId": arg.communityId,
      "metricsType": arg.metricsType,
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "metricsType": arg.metricsType,
      "error": e.msg,
    })

type
  AsyncRequestCommunityInfoTaskArg = ref object of QObjectTaskArg
    communityId: string
    importing: bool
    tryDatabase: bool

proc asyncRequestCommunityInfoTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncRequestCommunityInfoTaskArg](argEncoded)
  try:
    let response = status_go.requestCommunityInfo(arg.communityId, arg.tryDatabase)
    arg.finish(%* {
      "communityId": arg.communityId,
      "importing": arg.importing,
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "importing": arg.importing,
      "error": e.msg,
    })

type
  AsyncLoadCuratedCommunitiesTaskArg = ref object of QObjectTaskArg

proc asyncLoadCuratedCommunitiesTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncLoadCuratedCommunitiesTaskArg](argEncoded)
  try:
    let response = status_go.getCuratedCommunities()
    arg.finish(%* {
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

type
  AsyncAcceptRequestToJoinCommunityTaskArg = ref object of QObjectTaskArg
    communityId: string
    requestId: string

proc asyncAcceptRequestToJoinCommunityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncAcceptRequestToJoinCommunityTaskArg](argEncoded)
  try:
    let response = status_go.acceptRequestToJoinCommunity(arg.requestId)
    let tpl: tuple[communityId: string, requestId: string, response: RpcResponse[JsonNode], error: string] = (arg.communityId, arg.requestId, response, "")
    arg.finish(tpl)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "communityId": arg.communityId,
      "requestId": arg.requestId
    })

type
  AsyncDeclineRequestToJoinCommunityTaskArg = ref object of QObjectTaskArg
    communityId: string
    requestId: string

proc asyncDeclineRequestToJoinCommunityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncDeclineRequestToJoinCommunityTaskArg](argEncoded)
  try:
    let response = status_go.declineRequestToJoinCommunity(arg.requestId)
    let tpl: tuple[communityId: string, requestId: string, response: RpcResponse[JsonNode], error: string] = (arg.communityId, arg.requestId, response, "")
    arg.finish(tpl)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "communityId": arg.communityId,
      "requestId": arg.requestId
    })

type
  AsyncMarkAllReadInCommunityTaskArg = ref object of QObjectTaskArg
    communityId: string

proc asyncMarkAllReadInCommunityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncMarkAllReadInCommunityTaskArg](argEncoded)
  try:
    let response = status_go.markAllReadInCommunity(arg.communityId)
    let tpl: tuple[communityId: string, response: RpcResponse[JsonNode], error: string] = (arg.communityId, response, "")
    arg.finish(tpl)
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "error": e.msg,
    })

type
  AsyncCommunityMemberActionTaskArg = ref object of QObjectTaskArg
    communityId: string
    pubKey: string
    deleteAllMessages: bool

proc asyncRemoveUserFromCommunityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCommunityMemberActionTaskArg](argEncoded)
  try:
    let response = status_go.removeUserFromCommunity(arg.communityId, arg.pubKey)
    arg.finish(%* {
      "communityId": arg.communityId,
      "pubKey": arg.pubKey,
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "pubKey": arg.pubKey,
      "error": e.msg,
    })

proc asyncBanUserFromCommunityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCommunityMemberActionTaskArg](argEncoded)
  try:
    let response = status_go.banUserFromCommunity(arg.communityId, arg.pubKey, arg.deleteAllMessages)
    let tpl: tuple[communityId: string, pubKey: string, response: RpcResponse[JsonNode], error: string] = (arg.communityId, arg.pubKey, response, "")
    arg.finish(tpl)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "communityId": arg.communityId,
      "pubKey": arg.pubKey,
      "deleteAllMessages": arg.deleteAllMessages
    })

proc asyncUnbanUserFromCommunityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCommunityMemberActionTaskArg](argEncoded)
  try:
    let response = status_go.unbanUserFromCommunity(arg.communityId, arg.pubKey)
    let tpl: tuple[communityId: string, pubKey: string, response: RpcResponse[JsonNode], error: string] = (arg.communityId, arg.pubKey, response, "")
    arg.finish(tpl)
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "communityId": arg.communityId,
      "pubKey": arg.pubKey
    })

type
  AsyncRequestToJoinCommunityTaskArg = ref object of QObjectTaskArg
    communityId: string
    ensName: string
    addressesToShare: seq[string]
    signatures: seq[string]
    airdropAddress: string

proc asyncRequestToJoinCommunityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncRequestToJoinCommunityTaskArg](argEncoded)
  try:
    let response = status_go.requestToJoinCommunity(arg.communityId, arg.ensName, arg.addressesToShare,
      arg.signatures, arg.airdropAddress)
    arg.finish(%* {
      "response": response,
      "communityId": arg.communityId,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "communityId": arg.communityId,
    })

type
  AsyncEditSharedAddressesTaskArg = ref object of QObjectTaskArg
    communityId: string
    addressesToShare: seq[string]
    signatures: seq[string]
    airdropAddress: string

proc asyncEditSharedAddressesTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncEditSharedAddressesTaskArg](argEncoded)
  try:
    let response = status_go.editSharedAddresses(arg.communityId, arg.addressesToShare, arg.signatures,
      arg.airdropAddress)
    arg.finish(%* {
      "response": response,
      "communityId": arg.communityId,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
      "communityId": arg.communityId,
    })

type
  AsyncCheckPermissionsToJoinTaskArg = ref object of QObjectTaskArg
    communityId: string
    addresses: seq[string]

proc asyncCheckPermissionsToJoinTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCheckPermissionsToJoinTaskArg](argEncoded)
  try:
    let response = status_go.checkPermissionsToJoinCommunity(arg.communityId, arg.addresses).result

    arg.finish(%* {
      "response": response,
      "communityId": arg.communityId,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "error": e.msg,
    })

type
  AsyncGetRevealedAccountsArg = ref object of QObjectTaskArg
    communityId: string
    memberPubkey: string

proc asyncGetRevealedAccountsForMemberTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncGetRevealedAccountsArg](argEncoded)
  try:
    let response = status_go.getRevealedAccountsForMember(arg.communityId, arg.memberPubkey)
    arg.finish(%* {
      "communityId": arg.communityId,
      "memberPubkey": arg.memberPubkey,
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "memberPubkey": arg.memberPubkey,
      "error": e.msg,
    })

proc asyncGetRevealedAccountsForAllMembersTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncGetRevealedAccountsArg](argEncoded)
  try:
    let response = status_go.getRevealedAccountsForAllMembers(arg.communityId)
    arg.finish(%* {
      "communityId": arg.communityId,
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "error": e.msg,
    })

type
  AsyncReevaluateCommunityMembersPermissionsArg = ref object of QObjectTaskArg
    communityId: string

proc asyncReevaluateCommunityMembersPermissionsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncReevaluateCommunityMembersPermissionsArg](argEncoded)
  try:
    let response = status_go.reevaluateCommunityMembersPermissions(arg.communityId)
    arg.finish(%* {
      "communityId": arg.communityId,
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "communityId": arg.communityId,
      "error": e.msg,
    })

type
  AsyncCollapseCategory = ref object of QObjectTaskArg
    communityId: string
    categoryId: string
    collapsed: bool

proc asyncCollapseCategoryTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncCollapseCategory](argEncoded)
  try:
    let response = status_go.toggleCollapsedCommunityCategory(
      arg.communityId,
      arg.categoryId,
      arg.collapsed,
    )
    arg.finish(%* {
      "response": response,
      "error": "",
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

type
  AsyncLoadCommunityRosterTaskArg = ref object of QObjectTaskArg
    communityId: string
    generation: int
    orderInputs: RosterOrderInputs

  CommunityRosterLoadResult {.acyclic.} = ref object of RootObj
    communityId: string
    generation: int
    snapshot: RosterSnapshot
    error: string

proc asyncLoadCommunityRosterTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncLoadCommunityRosterTaskArg](argEncoded)
  var res = CommunityRosterLoadResult(communityId: arg.communityId, generation: arg.generation)
  try:
    let response = status_go.getCommunityMembers(arg.communityId)
    if not response.error.isNil:
      res.error = response.error.message
    else:
      res.snapshot = parseRosterSnapshot(response.result)
      sortRoster(res.snapshot, arg.orderInputs)
  except Exception as e:
    res.error = e.msg
  arg.finishTyped(res)

type
  AsyncSaveCommunityTokenPermissionTaskArg* = ref object of QObjectTaskArg
    communityId*: string
    permission*: CommunityTokenPermissionDto
    keys*: seq[string]
    criteriaJson*: string
    storedCriteriaJson*: string
    modes*: ModeChains

  SavePermissionId = object
    id: string

  # Whatever a save arg that fails to decode still reports its failure with.
  SaveCommunityTokenPermissionTaskHeader = ref object of QObjectTaskArg
    communityId: string
    permission: SavePermissionId

proc newSaveCommunityTokenPermissionTaskArg*(communityId: string, permission: CommunityTokenPermissionDto,
    toSave: seq[SaveCriterion], storedCriteria: seq[TokenCriteriaDto], modes: ModeChains): AsyncSaveCommunityTokenPermissionTaskArg =
  result = AsyncSaveCommunityTokenPermissionTaskArg(
    communityId: communityId,
    permission: permission,
    keys: toSave.mapIt(it.key),
    criteriaJson: criteriaToJson(toSave.mapIt(it.criterion)),
    storedCriteriaJson: criteriaToJson(storedCriteria),
    modes: modes,
  )
  # Criteria only travel as criteriaJson: the task arg decoder rejects their TokenType.
  result.permission.tokenCriteria = @[]

proc toCatalogueTokens(response: JsonNode, err: string): seq[CatalogueToken] =
  if err.len > 0:
    raise newException(CatchableError, err)
  if response.isNil or response.kind != JArray:
    raise newException(CatchableError, "unexpected tokens response")
  for token in response:
    result.add(toCatalogueToken(token))

proc backendTokenCatalogue(): TokenCatalogue =
  TokenCatalogue(
    byKeys: proc(keys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} =
      var response: JsonNode
      let err = wallet_tokens_backend.getTokensByKeys(response, keys)
      toCatalogueTokens(response, err),
    byGroupKeys: proc(groupKeys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} =
      var response: JsonNode
      let err = wallet_tokens_backend.getTokensByGroupKeys(response, groupKeys)
      toCatalogueTokens(response, err),
  )

proc saveTokenPermissionRpc(communityId: string, permission: CommunityTokenPermissionDto): JsonNode {.gcsafe.} =
  let criteria = Json.encode(permission.tokenCriteria)
  if permission.id != "":
    return status_go.editCommunityTokenPermission(communityId, permission.id, int(permission.`type`), criteria,
      permission.chatIDs, permission.isPrivate).result
  return status_go.createCommunityTokenPermission(communityId, int(permission.`type`), criteria,
    permission.chatIDs, permission.isPrivate).result

proc runSaveCommunityTokenPermissionTask*(argEncoded: string, catalogue: TokenCatalogue,
    save: SavePermissionRpc): (QObjectTaskArg, PermissionSaveResult) =
  let header = decode[SaveCommunityTokenPermissionTaskHeader](argEncoded)
  try:
    let arg = decode[AsyncSaveCommunityTokenPermissionTaskArg](argEncoded)
    var toSave: seq[SaveCriterion]
    for i, criterion in criteriaFromJson(arg.criteriaJson):
      toSave.add(SaveCriterion(key: arg.keys[i], criterion: criterion))
    return (header.QObjectTaskArg, saveTokenPermission(arg.communityId, arg.permission, toSave,
      criteriaFromJson(arg.storedCriteriaJson), arg.modes, catalogue, save))
  except Exception as e:
    return (header.QObjectTaskArg, PermissionSaveResult(communityId: header.communityId,
      permission: CommunityTokenPermissionDto(id: header.permission.id), error: e.msg))

proc asyncSaveCommunityTokenPermissionTask(argEncoded: string) {.gcsafe, nimcall.} =
  var (arg, res) = runSaveCommunityTokenPermissionTask(argEncoded, backendTokenCatalogue(), saveTokenPermissionRpc)
  arg.finishTyped(move res)
