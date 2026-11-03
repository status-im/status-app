## The all-tokens View against a fake module: one shared model per held chain,
## the loading flags and the keys pinned while held (the swap receive picker
## reading a chain's shared model is in token_selector_module_test).
## Compile with -d:QT_MODEL_SPY (needs the seaqt/nimqml toolchain).

import unittest, tables, sequtils
import nimqml

import app/modules/main/wallet_section/all_tokens/view
import app/modules/main/wallet_section/all_tokens/token_groups_model
import app/modules/main/wallet_section/all_tokens/io_interface
import app_service/service/token/items/token_group
import app/modules/shared/qt_model_spy

type
  FakeModule = ref object of AccessInterface
    allChainsGroups: seq[TokenGroupItem]
    chainGroups: Table[int, seq[TokenGroupItem]]
    chainLoading: Table[int, bool]
    chainActive: Table[int, bool]
    chainHolders: Table[int, int]
    tokenListsLoading: bool
    defaultMandatoryKeys: seq[string]
    mandatoryKeysCalls: int
    view: View
    allGroupsHolders: int

template groupsSource(groups: untyped) =
  result = (
    getAllTokenGroups: proc(): var seq[TokenGroupItem] = groups,
    getTokenDetails: proc(tokenKey: string): TokenDetailsItem = default(TokenDetailsItem),
    getTokenPreferences: proc(groupKey: string): TokenPreferencesItem = default(TokenPreferencesItem),
    getCommunityTokenDescription: proc(chainId: int, address: string): string = "",
    getTokensDetailsLoading: proc(): bool = false,
    getTokensMarketValuesLoading: proc(): bool = false,
  )

proc chainGroupsOf(fake: FakeModule, chainId: int): var seq[TokenGroupItem] =
  fake.chainGroups.mgetOrPut(chainId, @[])

method getTokenListsModelDataSource(self: FakeModule): TokenListsModelDataSource =
  var lists: seq[TokenListItem]
  (getAllTokenLists: proc(): var seq[TokenListItem] = lists,)

method getTokenGroupsModelDataSource(self: FakeModule): TokenGroupsModelDataSource =
  var groups: seq[TokenGroupItem]
  groupsSource(groups)

method getTokenGroupsForChainModelDataSource(self: FakeModule, chainId: int): TokenGroupsModelDataSource =
  groupsSource(self.chainGroupsOf(chainId))

method getTokenGroupsAllChainsModelDataSource(self: FakeModule): TokenGroupsModelDataSource =
  groupsSource(self.allChainsGroups)

method getTokenMarketValuesDataSource(self: FakeModule): TokenMarketValuesDataSource =
  (
    getMarketValuesForToken: proc(tokenKey: string): TokenMarketValuesItem = default(TokenMarketValuesItem),
    getPriceForToken: proc(tokenKey: string): float64 = 0.0,
    getCurrentCurrencyFormat: proc(): CurrencyFormatDto = default(CurrencyFormatDto),
    getTokensMarketValuesLoading: proc(): bool = false,
  )

method getMandatoryTokenGroupKeys(self: FakeModule): seq[string] =
  inc self.mandatoryKeysCalls
  self.defaultMandatoryKeys
method getChainTokenGroupsLoading(self: FakeModule, chainId: int): bool = self.chainLoading.getOrDefault(chainId)
method getTokenListsLoading(self: FakeModule): bool = self.tokenListsLoading
method isChainTokenGroupsActive(self: FakeModule, chainId: int): bool = self.chainActive.getOrDefault(chainId)
method acquireChainTokenGroups(self: FakeModule, chainId: int) =
  self.chainHolders.mgetOrPut(chainId, 0).inc
  self.chainActive[chainId] = true
method releaseChainTokenGroups(self: FakeModule, chainId: int) =
  self.chainHolders[chainId].dec
method acquireAllTokenGroups(self: FakeModule) = inc self.allGroupsHolders
method releaseAllTokenGroups(self: FakeModule) = dec self.allGroupsHolders
method acquireTokenLists(self: FakeModule) = discard
method releaseTokenLists(self: FakeModule) = discard

proc mkGroup(key: string, chainId = 1): TokenGroupItem =
  let tok = createTokenItem(TokenDto(chainId: chainId, address: "0x" & key, crossChainId: key,
    name: key, symbol: key, decimals: 18))
  TokenGroupItem(key: key, name: key, symbol: key, decimals: 18, tokens: @[tok])

proc mkGroups(prefix: string, count: int, chainId = 1): seq[TokenGroupItem] =
  for i in 0 ..< count:
    result.add(mkGroup(prefix & $i, chainId))

proc loadedKeys(model: TokenGroupsModel): seq[string] =
  model.getLoadedGroups().mapIt(it.key)

proc newFake(): FakeModule =
  result = FakeModule()
  result.view = newView(result)

proc load(fake: FakeModule, chainId: int, groups: seq[TokenGroupItem]) =
  ## The service finishing a load of the chain.
  fake.chainGroups[chainId] = groups
  fake.view.onChainGroupsChanged(chainId, dropped = false)

proc drop(fake: FakeModule, chainId: int) =
  ## The service dropping the chain's entry.
  fake.chainGroups.del(chainId)
  fake.chainActive[chainId] = false
  fake.view.onChainGroupsChanged(chainId, dropped = true)

proc chainModel(fake: FakeModule, chainId: int): TokenGroupsModel =
  fake.view.getChainTokenGroupsModelObj(chainId)

suite "all tokens View":

  test "two holders of a chain share one model":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "")
    fake.view.acquireChainTokenGroups(1, "")
    check not fake.chainModel(1).isNil
    check fake.chainModel(1) == fake.view.getChainTokenGroupsModelObj(1)
    check fake.chainHolders[1] == 2
    fake.load(1, mkGroups("a", 3))
    check fake.chainModel(1).loadedKeys == @["a0", "a1", "a2"]

  test "an unheld chain has no model":
    let fake = newFake()
    check fake.chainModel(1).isNil
    check fake.view.chainTokenGroupsModel(1).isNull
    fake.view.acquireChainTokenGroups(1, "")
    check not fake.view.chainTokenGroupsModel(1).isNull
    check fake.chainModel(10).isNil

  test "a new holder of a loaded chain reads its rows at once":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "")
    fake.load(1, mkGroups("a", 2))
    fake.view.releaseChainTokenGroups(1, "")
    # idle, still loaded: no load event follows the next holder
    fake.view.acquireChainTokenGroups(1, "")
    check fake.chainModel(1).loadedKeys == @["a0", "a1"]

  test "a chain released and held again within the idle delay keeps its model":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "")
    fake.load(1, mkGroups("a", 2))
    let model = fake.chainModel(1)
    fake.view.releaseChainTokenGroups(1, "")
    fake.view.acquireChainTokenGroups(10, "")
    fake.view.releaseChainTokenGroups(10, "")
    fake.view.acquireChainTokenGroups(1, "")
    check fake.chainModel(1) == model
    check model.loadedKeys == @["a0", "a1"]

  test "the drop after the last holder deletes the model":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "")
    fake.load(1, mkGroups("a", 2))
    fake.view.releaseChainTokenGroups(1, "")
    check not fake.chainModel(1).isNil
    fake.drop(1)
    check fake.chainModel(1).isNil
    check fake.view.chainTokenGroupsModel(1).isNull

  test "a drop while held empties the model and keeps it":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "")
    fake.load(1, mkGroups("a", 2))
    let model = fake.chainModel(1)
    # as on background
    fake.drop(1)
    check fake.chainModel(1) == model
    check model.loadedKeys.len == 0
    fake.load(1, mkGroups("a", 2))
    check model.loadedKeys == @["a0", "a1"]

  test "the last holder going after a drop deletes the model at once":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "")
    fake.load(1, mkGroups("a", 2))
    fake.drop(1)
    fake.view.releaseChainTokenGroups(1, "")
    check fake.chainModel(1).isNil

  test "a chain's model pins the keys of each of its holders":
    let fake = newFake()
    fake.defaultMandatoryKeys = @["a250"]
    fake.view.acquireChainTokenGroups(1, "a200")
    fake.load(1, mkGroups("a", 300))
    let model = fake.chainModel(1)
    check "a200" in model.loadedKeys
    check "a250" notin model.loadedKeys
    # a second holder of the loaded chain: no load event follows
    fake.view.acquireChainTokenGroups(1, "")
    check "a200" in model.loadedKeys
    check "a250" in model.loadedKeys
    fake.view.releaseChainTokenGroups(1, "a200")
    check "a200" notin model.loadedKeys
    check "a250" in model.loadedKeys

  test "the last holder going leaves a still active chain's model as it is":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "a200")
    fake.load(1, mkGroups("a", 300))
    let model = fake.chainModel(1)
    var updates = 0
    fake.view.onChainTokenGroupsModelUpdated(proc(chainId: int) = inc updates)
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    fake.view.releaseChainTokenGroups(1, "a200")
    check spy.countResets() == 0
    check updates == 0
    check fake.chainModel(1) == model
    # the next holder pins its own keys
    fake.view.acquireChainTokenGroups(1, "a250")
    check "a250" in model.loadedKeys
    check "a200" notin model.loadedKeys
    check spy.countResets() == 1

  test "a wallet tokens rebuild re-pins the default keys":
    let fake = newFake()
    fake.defaultMandatoryKeys = @["a250"]
    fake.view.acquireChainTokenGroups(1, "")
    fake.view.acquireChainTokenGroups(1, "a200")
    fake.load(1, mkGroups("a", 300))
    let model = fake.chainModel(1)
    check "a250" in model.loadedKeys
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    fake.defaultMandatoryKeys = @["a260"]
    fake.view.onWalletTokensRebuilt()
    check "a260" in model.loadedKeys
    check "a250" notin model.loadedKeys
    check "a200" in model.loadedKeys
    check spy.countResets() == 1
    # unchanged defaults: no reset
    fake.view.onWalletTokensRebuilt()
    check spy.countResets() == 1

  test "default keys resolved in another order keep a chain's model":
    let fake = newFake()
    fake.defaultMandatoryKeys = @["a250", "a260"]
    fake.view.acquireChainTokenGroups(1, "")
    fake.load(1, mkGroups("a", 300))
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    fake.defaultMandatoryKeys = @["a260", "a250"]
    fake.view.onWalletTokensRebuilt()
    check spy.countResets() == 0

  test "a wallet tokens rebuild leaves chains held with their own keys alone":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "a200")
    fake.view.acquireChainTokenGroups(10, "a200")
    fake.load(1, mkGroups("a", 300))
    fake.load(10, mkGroups("a", 300, 10))
    let calls = fake.mandatoryKeysCalls
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    fake.view.onWalletTokensRebuilt()
    check spy.countResets() == 0
    check fake.mandatoryKeysCalls == calls

  test "a wallet tokens rebuild resolves the default keys once":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "")
    fake.view.acquireChainTokenGroups(10, "")
    let calls = fake.mandatoryKeysCalls
    fake.view.onWalletTokensRebuilt()
    check fake.mandatoryKeysCalls == calls + 1

  test "a release matching no hold changes nothing":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "a1")
    fake.view.acquireChainTokenGroups(1, "a1")
    fake.view.releaseChainTokenGroups(1, "a2")
    fake.view.releaseChainTokenGroups(10, "a1")
    check fake.chainHolders[1] == 2
    fake.view.releaseChainTokenGroups(1, "a1")
    fake.view.releaseChainTokenGroups(1, "a1")
    fake.view.releaseChainTokenGroups(1, "a1")
    check fake.chainHolders[1] == 0

  test "the keys pinned on one chain stay off another":
    let fake = newFake()
    fake.view.acquireChainTokenGroups(1, "a200$$a210")
    fake.view.acquireChainTokenGroups(10, "")
    fake.load(1, mkGroups("a", 300))
    fake.load(10, mkGroups("a", 300))
    check "a210" in fake.chainModel(1).loadedKeys
    check "a210" notin fake.chainModel(10).loadedKeys

  test "each chain's model reports its own loading":
    let fake = newFake()
    fake.chainLoading[1] = true
    fake.view.acquireChainTokenGroups(1, "")
    fake.view.acquireChainTokenGroups(10, "")
    check fake.chainModel(1).getLoading()
    check not fake.chainModel(10).getLoading()
    fake.chainLoading[1] = false
    fake.chainLoading[10] = true
    fake.tokenListsLoading = true
    fake.view.onCatalogueLoadingChanged()
    check not fake.chainModel(1).getLoading()
    check fake.chainModel(10).getLoading()
    check fake.view.getTokenListsLoading()

  test "all-chains pins the keys of every holder while the groups stay loaded":
    let fake = newFake()
    # past the first lazy page, so only a pinned key is loaded
    fake.allChainsGroups = mkGroups("k", 300)
    fake.defaultMandatoryKeys = @["k250"]
    let model = fake.view.getTokenGroupsAllChainsModelObj()
    fake.view.acquireAllChainsTokenGroupsForKeys(1, @["k200"])
    fake.view.onAllChainsGroupsChanged()
    check "k200" in model.loadedKeys
    check "k250" notin model.loadedKeys
    # a second holder while loaded: no load event follows
    fake.view.acquireAllTokenGroups()
    check "k200" in model.loadedKeys
    check "k250" in model.loadedKeys
    fake.view.releaseAllChainsTokenGroups(1)
    check "k200" notin model.loadedKeys
    check "k250" in model.loadedKeys
    check fake.allGroupsHolders == 1

  test "holders with keys keep them apart; a later load pins the union":
    let fake = newFake()
    fake.allChainsGroups = mkGroups("k", 300)
    let model = fake.view.getTokenGroupsAllChainsModelObj()
    fake.view.acquireAllChainsTokenGroupsForKeys(1, @["k200"])
    fake.view.acquireAllChainsTokenGroupsForKeys(2, @["k210", "k200"])
    fake.view.onAllChainsGroupsChanged()
    check "k200" in model.loadedKeys
    check "k210" in model.loadedKeys
    fake.view.releaseAllChainsTokenGroups(2)
    check "k200" in model.loadedKeys
    check "k210" notin model.loadedKeys
    fake.view.releaseAllChainsTokenGroups(1)
    fake.view.releaseAllChainsTokenGroups(1)
    check fake.allGroupsHolders == 0

  test "default keys resolved in another order keep the all-chains model":
    let fake = newFake()
    fake.allChainsGroups = mkGroups("k", 300)
    fake.defaultMandatoryKeys = @["k250", "k260"]
    fake.view.acquireAllTokenGroups()
    fake.view.onAllChainsGroupsChanged()
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    fake.defaultMandatoryKeys = @["k260", "k250"]
    fake.view.acquireAllTokenGroups()
    check spy.countResets() == 0
