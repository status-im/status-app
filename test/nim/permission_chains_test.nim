import std/[unittest, tables, sequtils, sets]

import app_service/common/types
import app_service/service/community/dto/community
import app_service/service/community/permission_chains

const
  mainnetChains = @[1, 10, 42161]
  testnetChains = @[11155111, 11155420, 84532]
  mainnet = ModeChains(current: mainnetChains, other: testnetChains)
  testnet = ModeChains(current: testnetChains, other: mainnetChains)

proc tok(chainId: int, address, groupKey: string, symbol = "SNT", decimals = 18, communityId = ""): CatalogueToken =
  let key = $chainId & "-" & address
  CatalogueToken(key: key, groupKey: if groupKey.len > 0: groupKey else: key, chainId: chainId,
    address: address, name: symbol & " token", symbol: symbol, decimals: decimals, communityId: communityId)

# Testnet first: the catalogue order the old single-chain fallback picked from.
let catalogueTokens = @[
  tok(11155111, "0xsntsepolia", "status"),
  tok(1, "0xsntmainnet", "status"),
  tok(10, "0xsntoptimism", "status"),
  tok(42161, "0xsntarbitrum", "status"),
  tok(1, "0xusdcmainnet", "usd-coin", "USDC", 6),
  tok(10, "0xusdcoptimism", "usd-coin", "USDC", 6),
  tok(11155420, "0xusdcopsepolia", "usd-coin", "USDC", 6),
  tok(84532, "0xusdcbasesepolia", "usd-coin", "USDC", 6),
  tok(10, "0xlonely", "", "LONE"),
  tok(1, "0xdaimainnet", "dai", "DAI"),
  tok(1, "0xminted", "", "MINT", 0, "0xcommunity"),
]

type FakeCatalogue = ref object
  tokens: seq[CatalogueToken]
  byKeysCalls: seq[seq[string]]
  byGroupKeysCalls: seq[seq[string]]
  fail: bool

proc catalogue(fake: FakeCatalogue): TokenCatalogue =
  TokenCatalogue(
    byKeys: proc(keys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} =
      fake.byKeysCalls.add(keys)
      if fake.fail: raise newException(IOError, "offline")
      fake.tokens.filterIt(it.key in keys),
    byGroupKeys: proc(groupKeys: seq[string]): seq[CatalogueToken] {.closure, gcsafe.} =
      fake.byGroupKeysCalls.add(groupKeys)
      if fake.fail: raise newException(IOError, "offline")
      fake.tokens.filterIt(it.groupKey in groupKeys),
  )

proc newFake(): FakeCatalogue = FakeCatalogue(tokens: catalogueTokens)

proc erc20(key: string, amountInWei = "1000"): SaveCriterion =
  SaveCriterion(key: key, criterion: TokenCriteriaDto(`type`: TokenType.ERC20, amountInWei: amountInWei, decimals: 18))

proc storedErc20(addresses: openArray[(int, string)], symbol = "SNT", amountInWei = ""): TokenCriteriaDto =
  TokenCriteriaDto(`type`: TokenType.ERC20, contractAddresses: addresses.toTable, symbol: symbol, decimals: 18,
    amountInWei: amountInWei)

proc chains(c: TokenCriteriaDto): HashSet[int] =
  for chainId in c.contractAddresses.keys:
    result.incl(chainId)

suite "permission criteria chain set":
  test "create keeps every current-mode chain of the group":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("status")], @[], mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria.len == 1
    check res.criteria[0].contractAddresses == {1: "0xsntmainnet", 10: "0xsntoptimism", 42161: "0xsntarbitrum"}.toTable

  test "create for a token the admin doesn't hold resolves the full group, not one chain":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("usd-coin")], @[], mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].chains == [1, 10].toHashSet
    check res.criteria[0].symbol == "USDC"

  test "testnet mode keeps only testnet chains":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("status")], @[], testnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {11155111: "0xsntsepolia"}.toTable

  test "a per-chain key resolves to its token's group":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("10-0xsntoptimism")], @[], mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].chains == [1, 10, 42161].toHashSet

  test "edit keeps stored chains and adds the group's current-mode chains":
    let fake = newFake()
    # Re-save sends the chip's per-chain key; the stored criterion also lists a testnet chain.
    let stored = @[storedErc20({1: "0xsntmainnet", 11155111: "0xsntsepolia"})]
    let res = resolveCriteriaChains(@[erc20("1-0xsntmainnet")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].chains == [1, 10, 42161, 11155111].toHashSet

  test "edit never shrinks a criterion whose chains left the catalogue":
    let fake = newFake()
    let stored = @[storedErc20({1: "0xsntmainnet", 8453: "0xsntbase"})]
    let res = resolveCriteriaChains(@[erc20("1-0xsntmainnet")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses[8453] == "0xsntbase"
    check res.criteria[0].chains == [1, 10, 42161, 8453].toHashSet

  test "edit doesn't carry the chains of a token the criterion no longer uses":
    let fake = newFake()
    let stored = @[storedErc20({1: "0xsntmainnet", 10: "0xsntoptimism"})]
    let res = resolveCriteriaChains(@[erc20("usd-coin")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {1: "0xusdcmainnet", 10: "0xusdcoptimism"}.toTable

  test "a token without a cross-chain id keeps exactly its chain":
    let fake = newFake()
    for mode in [mainnet, testnet]:
      let res = resolveCriteriaChains(@[erc20("10-0xlonely")], @[], mode, fake.catalogue)
      check res.error == ""
      check res.criteria[0].contractAddresses == {10: "0xlonely"}.toTable

  test "a community-minted token keeps its single chain":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("1-0xminted")], @[], testnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {1: "0xminted"}.toTable

  test "a token key the catalogue doesn't know keeps its own chain and stored chains":
    let fake = newFake()
    let stored = @[storedErc20({5: "0xlegacy", 7: "0xlegacy7"})]
    let res = resolveCriteriaChains(@[erc20("5-0xlegacy")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].chains == [5, 7].toHashSet

  test "collectibles and ENS criteria pass through unchanged":
    let fake = newFake()
    let collectible = SaveCriterion(key: "1-0xnft", criterion: TokenCriteriaDto(`type`: TokenType.ERC721,
      contractAddresses: {1: "0xnft"}.toTable, tokenIds: @["1"]))
    let ens = SaveCriterion(key: "*.eth", criterion: TokenCriteriaDto(`type`: TokenType.ENS, ensPattern: "*.eth"))
    let res = resolveCriteriaChains(@[collectible, ens], @[], mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria == @[collectible.criterion, ens.criterion]
    check fake.byKeysCalls.len == 0
    check fake.byGroupKeysCalls.len == 0

  test "name and symbol come from the group; set decimals stay":
    let fake = newFake()
    var c = erc20("usd-coin")
    c.criterion.decimals = 18
    let res = resolveCriteriaChains(@[c], @[], mainnet, fake.catalogue)
    check res.criteria[0].name == "USDC token"
    check res.criteria[0].symbol == "USDC"
    check res.criteria[0].decimals == 18
    check res.criteria[0].amountInWei == "1000"

  test "a catalogue failure fails the save with no criteria":
    let fake = newFake()
    fake.fail = true
    let res = resolveCriteriaChains(@[erc20("status")], @[storedErc20({1: "0xsntmainnet"})], mainnet, fake.catalogue)
    check res.error != ""
    check res.criteria.len == 0

  test "an unknown group fails the save":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("no-such-token")], @[], mainnet, fake.catalogue)
    check res.error != ""
    check res.criteria.len == 0

  test "a group with no chain in the current mode fails the save":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("dai")], @[], testnet, fake.catalogue)
    check res.error != ""
    check res.criteria.len == 0

  test "several criteria resolve in one batch, in order":
    let fake = newFake()
    let collectible = SaveCriterion(key: "1-0xnft", criterion: TokenCriteriaDto(`type`: TokenType.ERC721,
      contractAddresses: {1: "0xnft"}.toTable))
    let stored = @[storedErc20({42161: "0xsntarbitrum"})]
    let res = resolveCriteriaChains(@[erc20("42161-0xsntarbitrum"), collectible, erc20("usd-coin")],
      stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria.len == 3
    check res.criteria[0].chains == [1, 10, 42161].toHashSet
    check res.criteria[1] == collectible.criterion
    check res.criteria[2].chains == [1, 10].toHashSet
    check fake.byKeysCalls.len == 1
    check fake.byGroupKeysCalls.len == 1
    check fake.byGroupKeysCalls[0].toHashSet == ["status", "usd-coin"].toHashSet

suite "permission criteria network mode":
  test "an edit in mainnet mode keeps a testnet criterion on testnet":
    let fake = newFake()
    let stored = @[storedErc20({11155111: "0xsntsepolia"})]
    for key in ["11155111-0xsntsepolia", "status"]:
      let res = resolveCriteriaChains(@[erc20(key)], stored, mainnet, fake.catalogue)
      check res.error == ""
      check res.criteria[0].contractAddresses == {11155111: "0xsntsepolia"}.toTable

  test "an edit in testnet mode keeps a mainnet criterion on mainnet":
    let fake = newFake()
    let stored = @[storedErc20({1: "0xsntmainnet"})]
    let res = resolveCriteriaChains(@[erc20("1-0xsntmainnet")], stored, testnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {1: "0xsntmainnet", 10: "0xsntoptimism", 42161: "0xsntarbitrum"}.toTable

  test "a stored criterion spanning both modes adds the group chains of each":
    let fake = newFake()
    let stored = @[storedErc20({1: "0xusdcmainnet", 11155420: "0xusdcopsepolia"}, "USDC")]
    for modes in [mainnet, testnet]:
      let res = resolveCriteriaChains(@[erc20("1-0xusdcmainnet")], stored, modes, fake.catalogue)
      check res.error == ""
      check res.criteria[0].chains == [1, 10, 11155420, 84532].toHashSet

  test "a new criterion uses the current mode next to a stored one of the other mode":
    let fake = newFake()
    let stored = @[storedErc20({11155111: "0xsntsepolia"})]
    let res = resolveCriteriaChains(@[erc20("11155111-0xsntsepolia"), erc20("usd-coin")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {11155111: "0xsntsepolia"}.toTable
    check res.criteria[1].contractAddresses == {1: "0xusdcmainnet", 10: "0xusdcoptimism"}.toTable

  test "a criterion switched to another token uses the current mode":
    let fake = newFake()
    let stored = @[storedErc20({11155111: "0xsntsepolia"})]
    let res = resolveCriteriaChains(@[erc20("usd-coin")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {1: "0xusdcmainnet", 10: "0xusdcoptimism"}.toTable

suite "permission criteria combined edit":
  # Stored on mainnet, edited by an admin in testnet mode.
  let stored = @[
    storedErc20({1: "0xsntmainnet"}, amountInWei = "100"),
    storedErc20({1: "0xsntmainnet", 8453: "0xsntbase"}, amountInWei = "200"),
    storedErc20({1: "0xusdcmainnet", 10: "0xusdcoptimism"}, amountInWei = "5"),
  ]
  let sntChains = [1, 10, 42161, 8453].toHashSet

  test "reordered criteria of one token with different amounts keep their chains and amounts":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("1-0xusdcmainnet", "6"), erc20("1-0xsntmainnet", "200"),
      erc20("1-0xsntmainnet", "100")], stored, testnet, fake.catalogue)
    check res.error == ""
    check res.criteria.mapIt(it.amountInWei) == @["6", "200", "100"]
    check res.criteria[0].contractAddresses == {1: "0xusdcmainnet", 10: "0xusdcoptimism"}.toTable
    check res.criteria[1].chains == sntChains
    check res.criteria[2].chains == sntChains

  test "removing one criterion of a token another still uses keeps that token's chains":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("1-0xsntmainnet", "200")], stored, testnet, fake.catalogue)
    check res.error == ""
    check res.criteria.len == 1
    check res.criteria[0].amountInWei == "200"
    check res.criteria[0].chains == sntChains

  test "a new criterion of an already-stored token joins that token's chains":
    let fake = newFake()
    let res = resolveCriteriaChains(@[erc20("1-0xsntmainnet", "100"), erc20("status", "300"),
      erc20("1-0xusdcmainnet", "5")], stored, testnet, fake.catalogue)
    check res.error == ""
    check res.criteria.mapIt(it.amountInWei) == @["100", "300", "5"]
    check res.criteria[0].chains == sntChains
    check res.criteria[1].chains == sntChains
    check res.criteria[2].chains == [1, 10].toHashSet

  test "an other-mode per-chain key doesn't add its chain to a stored single-mode criterion":
    let fake = newFake()
    let stored = @[storedErc20({11155111: "0xsntsepolia"})]
    let res = resolveCriteriaChains(@[erc20("1-0xsntmainnet")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {11155111: "0xsntsepolia"}.toTable

  test "a lone token outside the resolved mode keeps its own chain":
    let fake = newFake()
    let stored = @[storedErc20({11155111: "0xsntsepolia"})]
    let res = resolveCriteriaChains(@[erc20("11155111-0xsntsepolia"), erc20("10-0xlonely")], stored, testnet,
      fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {11155111: "0xsntsepolia"}.toTable
    check res.criteria[1].contractAddresses == {10: "0xlonely"}.toTable

  test "a stored other-mode key the catalogue lacks keeps its stored chains":
    let fake = newFake()
    let stored = @[storedErc20({84532: "0xgone", 11155420: "0xgone2"})]
    let res = resolveCriteriaChains(@[erc20("84532-0xgone")], stored, mainnet, fake.catalogue)
    check res.error == ""
    check res.criteria[0].contractAddresses == {84532: "0xgone", 11155420: "0xgone2"}.toTable
