import std/[unittest, json, tables, sequtils]

import app_service/common/types
import app_service/service/community/dto/community
import app_service/service/community/permission_chains

const communityId = "0x02aaaa"
const modes = ModeChains(current: @[1, 10], other: @[11155111])

const tokens = @[
  CatalogueToken(key: "1-0xsnt", groupKey: "status", chainId: 1, address: "0xsnt", name: "Status", symbol: "SNT", decimals: 18),
  CatalogueToken(key: "10-0xsnt10", groupKey: "status", chainId: 10, address: "0xsnt10", name: "Status", symbol: "SNT", decimals: 18),
]

type Backend = ref object
  catalogueCalls: int
  saved: seq[CommunityTokenPermissionDto]
  catalogueFails: bool
  saveFails: bool
  saveResult: JsonNode

proc catalogue(b: Backend): TokenCatalogue =
  TokenCatalogue(
    byKeys: proc(keys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} =
      inc b.catalogueCalls
      if b.catalogueFails: raise newException(IOError, "offline")
      tokens.filterIt(it.key in keys),
    byGroupKeys: proc(groupKeys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} =
      inc b.catalogueCalls
      if b.catalogueFails: raise newException(IOError, "offline")
      tokens.filterIt(it.groupKey in groupKeys),
  )

proc save(b: Backend): SavePermissionRpc =
  return proc(id: string, permission: CommunityTokenPermissionDto): JsonNode {.closure, gcsafe.} =
    check id == communityId
    b.saved.add(permission)
    if b.saveFails: raise newException(IOError, "rpc failed")
    b.saveResult

proc newBackend(): Backend =
  Backend(saveResult: %*{"communityChanges": [
    {"communityId": communityId, "clock": 5, "tokenPermissionsAdded": {"p1": {"id": "p1"}}},
  ]})

proc permission(id = ""): CommunityTokenPermissionDto =
  CommunityTokenPermissionDto(id: id, `type`: TokenPermissionType.BecomeMember, chatIds: @["c1"], isPrivate: true)

let snt = SaveCriterion(key: "status", criterion: TokenCriteriaDto(`type`: TokenType.ERC20, amountInWei: "1", decimals: 18))

suite "token permission save":
  test "saves the permission with its resolved chains and returns the roster deltas":
    let b = newBackend()
    let res = saveTokenPermission(communityId, permission(), @[snt], @[], modes, b.catalogue, b.save)
    check res.error == ""
    check res.communityId == communityId
    check b.saved.len == 1
    check b.saved[0].tokenCriteria.len == 1
    check b.saved[0].tokenCriteria[0].contractAddresses == {1: "0xsnt", 10: "0xsnt10"}.toTable
    check b.saved[0].chatIds == @["c1"]
    check b.saved[0].isPrivate
    check res.permission.tokenCriteria == b.saved[0].tokenCriteria
    check res.rosterDeltas.len == 1
    check res.rosterDeltas[0].permissionsChanged

  test "an edit keeps the stored chains":
    let b = newBackend()
    let stored = @[TokenCriteriaDto(`type`: TokenType.ERC20, contractAddresses: {1: "0xsnt", 8453: "0xsntbase"}.toTable)]
    var edit = snt
    edit.key = "1-0xsnt"
    let res = saveTokenPermission(communityId, permission("p1"), @[edit], stored, modes, b.catalogue, b.save)
    check res.error == ""
    check b.saved[0].id == "p1"
    check b.saved[0].tokenCriteria[0].contractAddresses == {1: "0xsnt", 10: "0xsnt10", 8453: "0xsntbase"}.toTable

  test "a resolution failure fails without saving":
    let b = newBackend()
    b.catalogueFails = true
    let res = saveTokenPermission(communityId, permission("p1"), @[snt], @[], modes, b.catalogue, b.save)
    check res.error != ""
    check res.permission.id == "p1"
    check b.saved.len == 0

  test "a save failure is reported":
    let b = newBackend()
    b.saveFails = true
    let res = saveTokenPermission(communityId, permission(), @[snt], @[], modes, b.catalogue, b.save)
    check res.error == "rpc failed"
    check res.rosterDeltas.len == 0

  test "an empty save result is a failure":
    let b = newBackend()
    b.saveResult = newJNull()
    let res = saveTokenPermission(communityId, permission(), @[snt], @[], modes, b.catalogue, b.save)
    check res.error != ""

  test "an ENS-only permission saves without a catalogue lookup":
    let b = newBackend()
    let ens = SaveCriterion(key: "*.eth", criterion: TokenCriteriaDto(`type`: TokenType.ENS, ensPattern: "*.eth"))
    let res = saveTokenPermission(communityId, permission(), @[ens], @[], modes, b.catalogue, b.save)
    check res.error == ""
    check b.catalogueCalls == 0
    check b.saved[0].tokenCriteria == @[ens.criterion]

suite "catalogue token":
  test "reads a wallet token":
    let t = toCatalogueToken(%*{"crossChainId": "status", "chainId": 10, "address": "0xABC",
      "name": "Status", "symbol": "SNT", "decimals": 18, "communityData": {"id": ""}})
    check t == CatalogueToken(key: "10-0xabc", groupKey: "status", chainId: 10, address: "0xABC",
      name: "Status", symbol: "SNT", decimals: 18)

  test "a token without a cross-chain id is its own group":
    let t = toCatalogueToken(%*{"crossChainId": "", "chainId": 1, "address": "0xdef", "symbol": "LONE", "decimals": 6})
    check t.groupKey == "1-0xdef"
    check t.key == "1-0xdef"

  test "a community token carries its community":
    let t = toCatalogueToken(%*{"chainId": 1, "address": "0xm", "communityData": {"id": "0xcommunity"}})
    check t.communityId == "0xcommunity"

suite "save task arg":
  test "criteria survive the worker hand-off encoding":
    let criteria = @[
      TokenCriteriaDto(`type`: TokenType.ERC20, contractAddresses: {1: "0xsnt", 8453: "0xsntbase"}.toTable,
        symbol: "SNT", name: "Status", decimals: 18, amount: "5", amountInWei: "5000"),
      TokenCriteriaDto(`type`: TokenType.ERC721, contractAddresses: {1: "0xnft"}.toTable, tokenIds: @["7"], amountInWei: "1"),
      TokenCriteriaDto(`type`: TokenType.ENS, ensPattern: "*.eth"),
    ]
    check criteriaFromJson(criteriaToJson(criteria)) == criteria
