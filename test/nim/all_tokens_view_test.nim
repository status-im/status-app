## The all-tokens View against a fake module: the loading flags, and the keys
## pinned in the all-chains model while it is held. Compile with -d:QT_MODEL_SPY (needs the seaqt/nimqml toolchain).

import unittest, tables, sequtils
import nimqml

import app/modules/main/wallet_section/all_tokens/view
import app/modules/main/wallet_section/all_tokens/token_groups_model
import app/modules/main/wallet_section/all_tokens/io_interface
import app_service/service/token/items/token_group

type
  FakeModule = ref object of AccessInterface
    allChainsGroups: seq[TokenGroupItem]
    chainGroups: Table[int, seq[TokenGroupItem]]
    chainLoading: Table[int, bool]
    tokenListsLoading: bool
    defaultMandatoryKeys: seq[string]
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

method getTokenGroupsForChainModelDataSource(self: FakeModule): TokenGroupsModelDataSource =
  groupsSource(self.chainGroupsOf(self.view.getGroupsForChainId()))

method getTokenGroupsForChainToModelDataSource(self: FakeModule): TokenGroupsModelDataSource =
  groupsSource(self.chainGroupsOf(self.view.getGroupsForChainToId()))

method getTokenGroupsAllChainsModelDataSource(self: FakeModule): TokenGroupsModelDataSource =
  groupsSource(self.allChainsGroups)

method getTokenMarketValuesDataSource(self: FakeModule): TokenMarketValuesDataSource =
  (
    getMarketValuesForToken: proc(tokenKey: string): TokenMarketValuesItem = default(TokenMarketValuesItem),
    getPriceForToken: proc(tokenKey: string): float64 = 0.0,
    getCurrentCurrencyFormat: proc(): CurrencyFormatDto = default(CurrencyFormatDto),
    getTokensMarketValuesLoading: proc(): bool = false,
  )

method getMandatoryTokenGroupKeys(self: FakeModule): seq[string] = self.defaultMandatoryKeys
method getChainTokenGroupsLoading(self: FakeModule, chainId: int): bool = self.chainLoading.getOrDefault(chainId)
method getTokenListsLoading(self: FakeModule): bool = self.tokenListsLoading
method acquireChainTokenGroups(self: FakeModule, chainId: int) = discard
method releaseChainTokenGroups(self: FakeModule, chainId: int) = discard
method acquireAllTokenGroups(self: FakeModule) = inc self.allGroupsHolders
method releaseAllTokenGroups(self: FakeModule) = dec self.allGroupsHolders
method acquireTokenLists(self: FakeModule) = discard
method releaseTokenLists(self: FakeModule) = discard

proc mkGroup(key: string): TokenGroupItem =
  let tok = createTokenItem(TokenDto(chainId: 1, address: "0x" & key, crossChainId: key,
    name: key, symbol: key, decimals: 18))
  TokenGroupItem(key: key, name: key, symbol: key, decimals: 18, tokens: @[tok])

proc mkGroups(prefix: string, count: int): seq[TokenGroupItem] =
  for i in 0 ..< count:
    result.add(mkGroup(prefix & $i))

proc loadedKeys(model: TokenGroupsModel): seq[string] =
  model.getLoadedGroups().mapIt(it.key)

proc newFake(): FakeModule =
  result = FakeModule()
  result.view = newView(result)

suite "all tokens View":

  test "loading flags follow the module when its loading changes":
    let fake = newFake()
    fake.view.showGroupsForChain(1, "")
    fake.view.showGroupsForChainTo(10, "")
    fake.chainLoading[1] = true
    fake.chainLoading[10] = true
    fake.tokenListsLoading = true
    fake.view.onCatalogueLoadingChanged()
    check fake.view.getGroupsForChainLoading()
    check fake.view.getGroupsForChainToLoading()
    check fake.view.getTokenListsLoading()
    fake.chainLoading[10] = false
    fake.tokenListsLoading = false
    fake.view.onCatalogueLoadingChanged()
    check fake.view.getGroupsForChainLoading()
    check not fake.view.getGroupsForChainToLoading()
    check not fake.view.getTokenListsLoading()

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
