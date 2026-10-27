import std/[json, sequtils, strutils, tables, unittest]

import app/core/eventemitter
import app/core/tasks/typed_handoff
import app_service/common/types
import app_service/service/community/service as community_service

const communityId = "0x02aaaa"

proc deliver(service: community_service.Service, res: PermissionSaveResult) =
  service.onAsyncCommunityTokenPermissionSaved($parkHandoff(res))

proc saved(id: string, error = ""): PermissionSaveResult =
  PermissionSaveResult(communityId: communityId, error: error, permission: CommunityTokenPermissionDto(id: id,
    tokenCriteria: @[TokenCriteriaDto(`type`: TokenType.ERC20, contractAddresses: {1: "0xsnt", 10: "0xsnt10"}.toTable)]))

let modes = ModeChains(current: @[1, 10], other: @[11155111])
const sntTokens = @[
  CatalogueToken(key: "1-0xsnt", groupKey: "status", chainId: 1, address: "0xsnt", symbol: "SNT", decimals: 18),
  CatalogueToken(key: "10-0xsnt10", groupKey: "status", chainId: 10, address: "0xsnt10", symbol: "SNT", decimals: 18),
]
let catalogue = TokenCatalogue(
  byKeys: proc(keys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} = sntTokens.filterIt(it.key in keys),
  byGroupKeys: proc(groupKeys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} =
    sntTokens.filterIt(it.groupKey in groupKeys),
)

type SaveLog = ref object
  saved: seq[CommunityTokenPermissionDto]

proc rpc(log: SaveLog): SavePermissionRpc =
  return proc(id: string, p: CommunityTokenPermissionDto): JsonNode {.closure, gcsafe.} =
    log.saved.add(p)
    %*{"communityChanges": []}

proc permission(id = "p1"): CommunityTokenPermissionDto =
  # Criteria as the module builds them, which the arg must not carry.
  CommunityTokenPermissionDto(id: id, `type`: TokenPermissionType.BecomeMember, chatIds: @["c1"], isPrivate: true,
    tokenCriteria: @[TokenCriteriaDto(`type`: TokenType.ERC20, contractAddresses: {1: "0xsnt"}.toTable)])

proc newArg(id = "p1"): AsyncSaveCommunityTokenPermissionTaskArg =
  let ens = TokenCriteriaDto(`type`: TokenType.ENS, ensPattern: "*.eth")
  result = newSaveCommunityTokenPermissionTaskArg(communityId, permission(id),
    @[SaveCriterion(key: "status", criterion: TokenCriteriaDto(`type`: TokenType.ERC20, amountInWei: "7", decimals: 18)),
      SaveCriterion(key: "*.eth", criterion: ens)],
    @[TokenCriteriaDto(`type`: TokenType.ERC20, contractAddresses: {1: "0xsnt", 8453: "0xsntbase"}.toTable)], modes)
  result.vptr = 42
  result.slot = "onSaved"

proc corrupt(encoded: string): string =
  encoded.replace("\"keys\":[", "\"keys\":{\"bad\":[").replace("],\"criteriaJson\"", "]},\"criteriaJson\"")

suite "token permission save completion":
  setup:
    let events = createEventEmitter()
    let service = community_service.newService(events, nil, nil, nil, nil)
    var succeeded: seq[CommunityTokenPermissionArgs]
    var creationFailed, updateFailed = 0
    events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATION_OR_UPDATE_SUCCEEDED,
      proc(e: Args) = succeeded.add(CommunityTokenPermissionArgs(e)))
    events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATION_FAILED, proc(e: Args) = inc creationFailed)
    events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_UPDATE_FAILED, proc(e: Args) = inc updateFailed)

  test "a saved permission is reported with its resolved criteria":
    service.deliver(saved("p1"))
    check succeeded.len == 1
    check succeeded[0].communityId == communityId
    check succeeded[0].tokenPermission.tokenCriteria[0].contractAddresses.len == 2
    check creationFailed == 0
    check updateFailed == 0

  test "a failed creation is reported":
    service.deliver(saved("", "offline"))
    check creationFailed == 1
    check updateFailed == 0
    check succeeded.len == 0

  test "a failed edit is reported":
    service.deliver(saved("p1", "offline"))
    check updateFailed == 1
    check creationFailed == 0
    check succeeded.len == 0

  test "a drained hand-off reports nothing":
    service.onAsyncCommunityTokenPermissionSaved("12345678")
    check succeeded.len == 0
    check creationFailed == 0
    check updateFailed == 0

  test "the whole arg survives the worker hand-off":
    let log = SaveLog()
    let (arg, res) = runSaveCommunityTokenPermissionTask(encode(newArg()), catalogue, log.rpc)
    let saved = log.saved
    check arg.vptr == 42
    check arg.slot == "onSaved"
    check res.error == ""
    check res.communityId == communityId
    check saved.len == 1
    check saved[0].id == "p1"
    check saved[0].`type` == TokenPermissionType.BecomeMember
    check saved[0].chatIds == @["c1"]
    check saved[0].isPrivate
    check saved[0].tokenCriteria.len == 2
    check saved[0].tokenCriteria[0].contractAddresses == {1: "0xsnt", 10: "0xsnt10", 8453: "0xsntbase"}.toTable
    check saved[0].tokenCriteria[0].amountInWei == "7"
    check saved[0].tokenCriteria[1].ensPattern == "*.eth"

  test "an arg that fails to decode finishes with a failed save":
    let log = SaveLog()
    let (arg, res) = runSaveCommunityTokenPermissionTask(corrupt(encode(newArg())), catalogue, log.rpc)
    check arg.slot == "onSaved"
    check res.error != ""
    check res.communityId == communityId
    check res.permission.id == "p1"
    check log.saved.len == 0
    service.deliver(res)
    check updateFailed == 1
    check succeeded.len == 0

  test "a create whose arg fails to decode finishes with a failed creation":
    let log = SaveLog()
    let (_, res) = runSaveCommunityTokenPermissionTask(corrupt(encode(newArg(""))), catalogue, log.rpc)
    check res.error != ""
    check res.permission.id == ""
    check log.saved.len == 0
    service.deliver(res)
    check creationFailed == 1
    check updateFailed == 0
    check succeeded.len == 0
