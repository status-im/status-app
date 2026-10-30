## The swap receive picker through the real token-selector module over the
## all-tokens View: it reads its destination chain's shared model, follows that
## model's loads and drops, and forgets the chain once released.
## Compile with -d:QT_MODEL_SPY; links libstatus and libStatusQ.

import unittest, tables, os, sequtils
import nimqml

import app/core/eventemitter
import app/modules/main/wallet_section/all_tokens/module as all_tokens_module
import app/modules/main/wallet_section/all_tokens/view as all_tokens_view
import app/modules/main/wallet_section/token_selector/module as token_selector_module
import app/modules/shared_models/token_selector_model
import app_service/service/token/service as token_service
import app_service/service/settings/service as settings_service
import app_service/service/network/service as network_service
import app_service/service/wallet_account/service as wallet_account_service

# token_selector/module.nim's swap receive kind
const KIND_SWAP_TO = 3

type
  FakeAllTokens = ref object of all_tokens_module.Module
    chainGroups: Table[int, seq[TokenGroupItem]]
    chainActive: Table[int, bool]
    chainHolders: Table[int, int]
    allChainsGroups: seq[TokenGroupItem]
    mandatoryKeys: seq[string]

  Fixture = object
    events: EventEmitter
    atm: FakeAllTokens
    selector: token_selector_module.Module

template groupsSource(groups: untyped) {.dirty.} =
  result = (
    getAllTokenGroups: proc(): var seq[TokenGroupItem] = groups,
    getTokenDetails: proc(tokenKey: string): TokenDetailsItem = default(TokenDetailsItem),
    getTokenPreferences: proc(groupKey: string): TokenPreferencesItem = default(TokenPreferencesItem),
    getCommunityTokenDescription: proc(chainId: int, address: string): string = "",
    getTokensDetailsLoading: proc(): bool = false,
    getTokensMarketValuesLoading: proc(): bool = false,
  )

proc chainGroupsOf(fake: FakeAllTokens, chainId: int): var seq[TokenGroupItem] =
  fake.chainGroups.mgetOrPut(chainId, @[])

method getTokenListsModelDataSource(self: FakeAllTokens): TokenListsModelDataSource =
  var lists: seq[TokenListItem]
  (getAllTokenLists: proc(): var seq[TokenListItem] = lists,)

method getTokenGroupsModelDataSource(self: FakeAllTokens): TokenGroupsModelDataSource =
  var groups: seq[TokenGroupItem]
  groupsSource(groups)

method getTokenGroupsForChainModelDataSource(self: FakeAllTokens, chainId: int): TokenGroupsModelDataSource =
  groupsSource(self.chainGroupsOf(chainId))

method getTokenGroupsAllChainsModelDataSource(self: FakeAllTokens): TokenGroupsModelDataSource =
  groupsSource(self.allChainsGroups)

method getTokenMarketValuesDataSource(self: FakeAllTokens): TokenMarketValuesDataSource =
  (
    getMarketValuesForToken: proc(tokenKey: string): TokenMarketValuesItem = default(TokenMarketValuesItem),
    getPriceForToken: proc(tokenKey: string): float64 = 0.0,
    getCurrentCurrencyFormat: proc(): CurrencyFormatDto = default(CurrencyFormatDto),
    getTokensMarketValuesLoading: proc(): bool = false,
  )

method getMandatoryTokenGroupKeys(self: FakeAllTokens): seq[string] = self.mandatoryKeys
method getChainTokenGroupsLoading(self: FakeAllTokens, chainId: int): bool = false
method getTokenListsLoading(self: FakeAllTokens): bool = false
method isChainTokenGroupsActive(self: FakeAllTokens, chainId: int): bool = self.chainActive.getOrDefault(chainId)
method acquireChainTokenGroups(self: FakeAllTokens, chainId: int) =
  self.chainHolders.mgetOrPut(chainId, 0).inc
  self.chainActive[chainId] = true
method releaseChainTokenGroups(self: FakeAllTokens, chainId: int) =
  self.chainHolders[chainId].dec
method acquireAllTokenGroups(self: FakeAllTokens) = discard
method releaseAllTokenGroups(self: FakeAllTokens) = discard
method acquireTokenLists(self: FakeAllTokens) = discard
method releaseTokenLists(self: FakeAllTokens) = discard
method viewDidLoad(self: FakeAllTokens) = discard

proc mkGroups(prefix: string, count: int, chainId = 1): seq[TokenGroupItem] =
  for i in 0 ..< count:
    let key = prefix & $i
    let tok = createTokenItem(TokenDto(chainId: chainId, address: "0x" & key, crossChainId: key,
      name: key, symbol: key, decimals: 18))
    result.add(TokenGroupItem(key: key, name: key, symbol: key, decimals: 18, tokens: @[tok]))

proc newFixture(): Fixture =
  let events = createEventEmitter()
  let settings = settings_service.newService(events)
  let network = network_service.newService(events, settings)
  let tokens = token_service.newService(events, nil, network, settings)
  let wallet = wallet_account_service.newService(events, nil, settings, nil, tokens, network, nil)
  let atm = FakeAllTokens()
  atm.init(nil, events, tokens, wallet, settings, nil)
  atm.load()
  let selector = token_selector_module.newModule(events, tokens, wallet, network, atm)
  selector.load()
  Fixture(events: events, atm: atm, selector: selector)

proc view(f: Fixture): all_tokens_view.View =
  f.atm.getViewForTest()

proc load(f: Fixture, chainId: int, groups: seq[TokenGroupItem]) =
  ## The service finishing a load of the chain.
  f.atm.chainGroups[chainId] = groups
  f.events.emit(SIGNAL_TOKEN_CATALOGUE_CHANGED,
    TokenCatalogueChangedArgs(kind: tckChainTokenGroups, chainId: chainId, dropped: false))

proc drop(f: Fixture, chainId: int) =
  ## The service dropping the chain's entry.
  f.atm.chainGroups.del(chainId)
  f.atm.chainActive[chainId] = false
  f.events.emit(SIGNAL_TOKEN_CATALOGUE_CHANGED,
    TokenCatalogueChangedArgs(kind: tckChainTokenGroups, chainId: chainId, dropped: true))

proc newReceivePicker(f: Fixture): tuple[id: int, model: TokenSelectorModel] =
  f.selector.createModelForKind(KIND_SWAP_TO)

proc showChain(f: Fixture, id: int, picker: TokenSelectorModel, chainId: int) =
  ## As SwapModal points its receive picker at a chain.
  picker.setEnabledChainId(chainId)
  f.selector.setCatalogChainId(id, chainId)

putEnv("QT_QPA_PLATFORM", "offscreen")
let app = newQGuiApplication()
# the singleton engine is destroyed after this module's globals, and needs the app
GC_ref(app)

suite "token selector module: swap receive picker":

  test "the receive picker shows a chain the pay side already loaded":
    let f = newFixture()
    let (id, picker) = f.newReceivePicker()
    # the pay side holds and loads chain 1
    f.view.acquireChainTokenGroups(1, "")
    f.load(1, mkGroups("a", 2))
    f.view.acquireChainTokenGroups(10, "")
    f.load(10, mkGroups("b", 2, 10))
    f.showChain(id, picker, 10)
    check picker.keysInOrder == @["b0", "b1"]
    # the receive side moves to the pay side's chain: no load event follows
    f.showChain(id, picker, 1)
    check picker.keysInOrder == @["a0", "a1"]
    check f.atm.chainHolders[1] == 1

  test "the receive picker follows a chain switch and back":
    let f = newFixture()
    let (id, picker) = f.newReceivePicker()
    f.view.acquireChainTokenGroups(1, "")
    f.showChain(id, picker, 1)
    f.load(1, mkGroups("a", 2))
    check picker.keysInOrder == @["a0", "a1"]
    f.view.releaseChainTokenGroups(1, "")
    f.view.acquireChainTokenGroups(10, "")
    f.showChain(id, picker, 10)
    check picker.keysInOrder.len == 0
    f.load(10, mkGroups("b", 2, 10))
    check picker.keysInOrder == @["b0", "b1"]
    f.view.releaseChainTokenGroups(10, "")
    f.view.acquireChainTokenGroups(1, "")
    f.showChain(id, picker, 1)
    check picker.keysInOrder == @["a0", "a1"]

  test "the receive picker picks up a chain held after it was pointed there":
    let f = newFixture()
    f.view.acquireChainTokenGroups(1, "")
    f.load(1, mkGroups("a", 2))
    f.view.releaseChainTokenGroups(1, "")
    let (id, picker) = f.newReceivePicker()
    f.drop(1)
    f.showChain(id, picker, 1)
    check picker.keysInOrder.len == 0
    f.atm.chainGroups[1] = mkGroups("a", 2)
    f.view.acquireChainTokenGroups(1, "")
    check picker.keysInOrder == @["a0", "a1"]

  test "the receive picker empties when its chain's model goes":
    let f = newFixture()
    let (id, picker) = f.newReceivePicker()
    f.view.acquireChainTokenGroups(1, "")
    f.load(1, mkGroups("a", 2))
    f.showChain(id, picker, 1)
    f.view.releaseChainTokenGroups(1, "")
    f.drop(1)
    check picker.keysInOrder.len == 0

  test "a released receive picker no longer follows its chain":
    let f = newFixture()
    let (id, picker) = f.newReceivePicker()
    f.view.acquireChainTokenGroups(1, "")
    f.showChain(id, picker, 1)
    f.load(1, mkGroups("a", 2))
    check picker.keysInOrder == @["a0", "a1"]
    f.selector.releaseModel(id)
    check not f.selector.hasCatalogForTest(id)
    f.load(1, mkGroups("b", 3))
    check picker.keysInOrder == @["a0", "a1"]

suite "all tokens module: wallet tokens rebuild":

  test "a wallet tokens rebuild re-pins a chain's default keys":
    let f = newFixture()
    f.view.acquireChainTokenGroups(1, "")
    # past the first lazy page, so only a pinned key is loaded
    f.load(1, mkGroups("a", 300))
    let model = f.atm.getChainTokenGroupsModelObj(1)
    check "a250" notin model.getLoadedGroups().mapIt(it.key)
    f.atm.mandatoryKeys = @["a250"]
    f.events.emit(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT, TokensPerAccountArgs())
    check "a250" in model.getLoadedGroups().mapIt(it.key)
