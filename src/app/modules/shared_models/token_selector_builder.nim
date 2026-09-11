# buildTokenSelectorItems — pure aggregation core for the token pickers.
#
# The Nim counterpart of TokenSelectorViewAdaptor's per-group ObjectProxyModel
# subgraph: for each token group it filters the per-(account, chain) balances by
# the picker's account/chain/zero-balance params, sums them, joins each surviving
# balance with its network (icon + name) into a display chip, and derives the
# fiat balance and the owned/popular section flag. Groups with no surviving
# balance are dropped (the QML `balancesModelCount != 0` filter); community
# groups are dropped unless showCommunityAssets.
#
# Reuses AggTokenGroup / AggBalance from assets_aggregator (the same raw shape the
# AssetsView producer already assembles). Qt-free on purpose.

import std/[tables, math, sets, strutils, algorithm, sequtils]
import stint

import ./assets_aggregator
import ./token_selector_item
export token_selector_item

type
  NetworkInfo* = object
    chainId*: int
    chainName*: string
    iconUrl*: string

  TokenSelectorParams* = object
    accountAddress*: string               ## empty = any account
    enabledChainIds*: seq[int]            ## empty = any chain
    showZeroBalanceForDefaultTokens*: bool
    showCommunityAssets*: bool

  PopularGroup* = object
    key*: string
    name*: string
    symbol*: string
    logoUri*: string
    communityId*: string
    decimals*: int
    marketPrice*: float
    tokens*: seq[tuple[key: string, chainId: int]]

proc toFloatUnits(v: UInt256, decimals: int): float =
  ## wei -> logical units as float64, matching QML AmountsArithmetic.toNumber.
  if v.isZero:
    return 0.0
  parseFloat($v) / pow(10.0, decimals.float)

proc buildTokenSelectorItems*(groups: seq[AggTokenGroup],
    networks: seq[NetworkInfo], params: TokenSelectorParams): seq[TokenSelectorItem] =
  var netByChain = initTable[int, NetworkInfo]()
  for n in networks:
    netByChain[n.chainId] = n

  let accountLower = params.accountAddress.toLowerAscii
  let chainSet = params.enabledChainIds.toHashSet

  result = newSeqOfCap[TokenSelectorItem](groups.len)
  for g in groups:
    if g.communityId.len > 0 and not params.showCommunityAssets:
      continue

    # Balances are per (account, chain); chips are keyed per chain in the
    # balances submodel. With no account filter a chain held by several
    # accounts yields several rows for the same chain, so sum per chain first
    # or the submodel sync trips on the duplicate key.
    var perChain = initOrderedTable[int, UInt256]()
    var total = 0.u256
    for b in g.balances:
      if accountLower.len > 0 and b.account.toLowerAscii != accountLower:
        continue
      if chainSet.len > 0 and b.chainId notin chainSet:
        continue
      if b.balance.isZero and not params.showZeroBalanceForDefaultTokens:
        continue
      total = total + b.balance
      perChain[b.chainId] = perChain.getOrDefault(b.chainId, 0.u256) + b.balance

    var chips: seq[TokenSelectorChip] = @[]
    for chainId, balance in perChain:
      let net = netByChain.getOrDefault(chainId)
      chips.add(TokenSelectorChip(chainId: chainId, iconUrl: net.iconUrl,
        chainName: net.chainName, balance: toFloatUnits(balance, g.decimals),
        rawBalance: $balance))

    # Drop groups with no surviving balance (QML `balancesModelCount != 0`).
    if chips.len == 0:
      continue

    # Biggest sub-balance first, matching the per-group RoleSorter.
    chips.sort(proc(a, b: TokenSelectorChip): int = cmp(b.balance, a.balance))

    let currentBalance = toFloatUnits(total, g.decimals)
    result.add(TokenSelectorItem(
      key: g.key,
      name: g.name,
      symbol: g.symbol,
      logoUri: g.logoUri,
      communityId: g.communityId,
      decimals: g.decimals,
      marketPrice: g.marketPrice,
      currentBalance: currentBalance,
      currencyBalance: currentBalance * g.marketPrice,
      hasBalance: currentBalance != 0.0,
      chips: chips,
      tokens: g.tokens.mapIt(TokenSelectorTokenRef(key: it.key, chainId: it.chainId))))

type
  TokenSelectorMode* {.pure.} = enum
    Owned      ## send: base list = owned tokens; a search filters results to owned only
    AllTokens  ## swap/buy: base list = the popular list merged with owned balances

proc mergePopularWithOwned*(popular: seq[PopularGroup],
    owned: seq[TokenSelectorItem], showCommunityAssets: bool,
    widenTokenRefsFromOwned = true): seq[TokenSelectorItem] =
  ## The all-tokens / search path (showAllTokens): the row set follows the
  ## popular list (all-tokens page or backend search result); a popular token the
  ## user owns is enriched with its owned balance data (chips / currentBalance /
  ## currencyBalance), one they don't own becomes a zero-balance popular item.
  ## Mirrors TokenSelectorViewAdaptor's LeftJoin(allTokens ⋈ tokensWithBalance):
  ## metadata (name/symbol/logoUri) comes from the popular side, balances from the
  ## owned side.
  var ownedByKey = initTable[string, TokenSelectorItem]()
  for it in owned:
    ownedByKey[it.key] = it

  result = newSeqOfCap[TokenSelectorItem](popular.len)
  for p in popular:
    if p.communityId.len > 0 and not showCommunityAssets:
      continue
    var item = TokenSelectorItem(
      key: p.key, name: p.name, symbol: p.symbol, logoUri: p.logoUri,
      communityId: p.communityId, decimals: p.decimals, marketPrice: p.marketPrice,
      tokens: p.tokens.mapIt(TokenSelectorTokenRef(key: it.key, chainId: it.chainId)))
    if ownedByKey.hasKey(p.key):
      let o = ownedByKey[p.key]
      item.currentBalance = o.currentBalance
      item.currencyBalance = o.currencyBalance
      item.hasBalance = o.hasBalance
      item.chips = o.chips
      item.decimals = o.decimals
      item.marketPrice = o.marketPrice
      # The "All" filter splits a multi-chain holding into one row per chain, so we need to merge the owned refs in
      if widenTokenRefsFromOwned:
        var chains = item.tokens.mapIt(it.chainId).toHashSet
        for t in o.tokens:
          if t.chainId notin chains:
            item.tokens.add(TokenSelectorTokenRef(key: t.key, chainId: t.chainId))
            chains.incl(t.chainId)
      elif item.tokens.len > 0:
        let refChains = item.tokens.mapIt(it.chainId).toHashSet
        if item.chips.anyIt(it.chainId notin refChains):
          item.chips = item.chips.filterIt(it.chainId in refChains)
          var total = 0.0
          for chip in item.chips:
            total += chip.balance
          item.currentBalance = total
          item.currencyBalance = total * item.marketPrice
          item.hasBalance = total != 0.0
    result.add(item)

proc filterToEnabledChains(items: seq[TokenSelectorItem],
    enabledChainIds: seq[int]): seq[TokenSelectorItem] =
  if enabledChainIds.len == 0:
    return items
  let chainSet = enabledChainIds.toHashSet
  items.filter(proc(item: TokenSelectorItem): bool =
    for t in item.tokens:
      if t.chainId in chainSet:
        return true
    false)

proc buildDisplayItems*(
    ownedGroups: seq[AggTokenGroup], networks: seq[NetworkInfo],
    params: TokenSelectorParams, mode: TokenSelectorMode, searchActive: bool,
    popularGroups: seq[PopularGroup], searchGroups: seq[PopularGroup]): seq[TokenSelectorItem] =
  ## Single entry point the terminal model calls to (re)derive its display rows.
  ## Selects the path the retired TokenSelectorViewAdaptor branched on:
  ##   - a search is active  -> merge the backend search rows with the owned balances;
  ##     Owned mode (send) then narrows to the rows already in the owned list
  ##     (the adaptor's `UndefinedFilter currentBalance` when !showAllTokens —
  ##     membership, not a non-zero balance, so showZeroBalanceForDefaultTokens
  ##     rows stay searchable).
  ##   - AllTokens (swap/buy) -> merge the lazily-loaded popular list with owned.
  ##   - Owned (send), no search -> just the owned tokens.
  let owned = buildTokenSelectorItems(ownedGroups, networks, params)
  if searchActive:
    let merged = filterToEnabledChains(
      mergePopularWithOwned(searchGroups, owned, params.showCommunityAssets, widenTokenRefsFromOwned = false),
      params.enabledChainIds
    )
    if mode == TokenSelectorMode.Owned:
      let ownedKeys = owned.mapIt(it.key).toHashSet
      return merged.filterIt(it.key in ownedKeys and it.chips.len > 0)
    return merged
  if mode == TokenSelectorMode.AllTokens:
    return filterToEnabledChains(
      mergePopularWithOwned(popularGroups, owned, params.showCommunityAssets),
      params.enabledChainIds)
  return owned
