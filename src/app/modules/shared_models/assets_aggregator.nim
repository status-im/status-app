# buildAssetItems — pure aggregation core for AssetsView.
#
# Turns the raw Nim token data (token groups + per-(account, chain) balances +
# community info) plus the dynamic filters (selected accounts, enabled chains,
# marketValueThreshold) into the flat seq[AssetItem] consumed by
# AssetsAdaptorModel. This is the Nim counterpart of what AssetsViewAdaptor's
# ObjectProxyModel + FunctionAggregators computed in QML:
#   - filter each group's balances by (accounts, chains)
#   - sum the filtered balances as UInt256, convert to logical units by decimals
#   - join market details (already on the group) and community info
#   - derive visible / canBeHidden
#
# balanceText and error stay in QML (currency + network context); this fills the
# raw values and the contributing chainIds the delegate needs for chainsError.
#
# Qt-free on purpose — unit-testable with a plain `nim c -r`.

import std/[tables, math, sets, strutils]
import stint

import ./assets_adaptor_item
export assets_adaptor_item

type
  AggBalance* = object
    account*: string
    chainId*: int
    balance*: UInt256
    loading*: bool

  AggTokenGroup* = object
    key*: string
    name*: string
    symbol*: string
    logoUri*: string
    decimals*: int
    communityId*: string
    marketPrice*: float
    marketChangePct24hour*: float
    marketDetailsLoading*: bool
    visible*: bool
    position*: int
    balances*: seq[AggBalance]
    tokens*: seq[tuple[key: string, chainId: int]]  ## per-chain token identity (unused by AssetsView)

  AggCommunity* = object
    name*: string
    image*: string

  AggFilters* = object
    accounts*: seq[string]        ## selected wallet addresses; a balance matches only if its account is here
    chains*: seq[int]             ## enabled chain ids; a balance matches only if its chainId is here
    marketValueThreshold*: float
    nativeSymbols*: seq[string]   ## native token symbols of the enabled chains (canBeHidden == false for these)

proc toFloatUnits(v: UInt256, decimals: int): float =
  ## wei -> logical units as float64, matching QML AmountsArithmetic.toNumber
  ## (JS Number is also float64). Precision loss beyond 2^53 is acceptable for a
  ## display/sort value.
  if v.isZero:
    return 0.0
  parseFloat($v) / pow(10.0, decimals.float)

proc buildAssetItems*(groups: seq[AggTokenGroup],
    communities: Table[string, AggCommunity], filters: AggFilters): seq[AssetItem] =
  let accountSet = filters.accounts.toHashSet
  let chainSet = filters.chains.toHashSet
  let nativeSet = filters.nativeSymbols.toHashSet

  result = newSeqOfCap[AssetItem](groups.len)
  for g in groups:
    var total = 0.u256
    var anyLoading = false
    var matched = 0
    var chainIds: seq[int] = @[]
    var seenChains = initHashSet[int]()
    for b in g.balances:
      if b.account notin accountSet or b.chainId notin chainSet:
        continue
      inc matched
      total = total + b.balance
      if b.loading:
        anyLoading = true
      if b.chainId notin seenChains:
        seenChains.incl(b.chainId)
        chainIds.add(b.chainId)

    let balance = toFloatUnits(total, g.decimals)
    let hasCommunity = g.communityId.len > 0

    let visible =
      if not g.visible: false
      elif matched == 0: false
      elif hasCommunity: true
      elif anyLoading: true
      else: balance * g.marketPrice >= filters.marketValueThreshold

    var item = AssetItem(
      key: g.key,
      name: g.name,
      symbol: g.symbol,
      logoUri: g.logoUri,
      balance: balance,
      balanceLoading: anyLoading,
      marketPrice: g.marketPrice,
      marketChangePct24hour: g.marketChangePct24hour,
      marketDetailsAvailable: not hasCommunity,
      marketDetailsLoading: g.marketDetailsLoading,
      communityId: g.communityId,
      canBeHidden: g.symbol notin nativeSet,
      position: g.position,
      visible: visible,
      chainIds: chainIds)

    if hasCommunity and communities.hasKey(g.communityId):
      let c = communities[g.communityId]
      item.communityName = c.name
      item.communityImage = c.image

    result.add(item)
