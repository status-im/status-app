## Balances can reach the wallet account service before the token service has
## applied its first refresh (login race). Balances whose token doesn't resolve
## yet must be held and re-applied once the token map is ready, not dropped.
## Once the map is ready, unknown tokens are still skipped.

import unittest, json, tables, stint

import app_service/service/token/items/token
import app_service/service/wallet_account/dto/asset_group_item
import app_service/service/wallet_account/balances_grouping

const
  account = "0xaaaa000000000000000000000000000000000001"
  snt = "0x744d70fdbe2ba4cf95131626614a1763df805b9e"
  usdc = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
  unknown = "0x1111111111111111111111111111111111111111"

proc balance(address: string, raw: string): JsonNode =
  %*{"tokenAddress": address, "tokenChainId": 1, "rawBalance": raw, "hasError": false}

proc response(balances: varargs[JsonNode]): JsonNode =
  result = newJObject()
  result[account] = %balances

proc lookupFor(addresses: seq[string]): TokenLookup =
  var byKey = initTable[string, TokenItem]()
  for address in addresses:
    let token = createTokenItem(TokenDto(address: address, chainId: 1))
    byKey[token.key] = token
  return proc(key: string): TokenItem = byKey.getOrDefault(key)

proc balancesByToken(assets: seq[AssetGroupItem]): Table[string, string] =
  for asset in assets:
    for b in asset.balancesPerAccount:
      result[b.tokenAddress] = $b.balance

suite "balances received before the token map is ready":
  test "unresolved balances are held and applied once the map is ready":
    var pending: PendingBalances
    let early = groupAccountBalances(@[], response(balance(snt, "100"), balance(usdc, "200")),
      lookupFor(@[snt]), tokensReady = false, pending)
    check balancesByToken(early.assets) == {snt: "100"}.toTable
    check pending.hasPending

    let replayed = groupAccountBalances(early.assets, pending.takeAll(),
      lookupFor(@[snt, usdc]), tokensReady = true, pending)
    check replayed.accounts == @[account]
    check balancesByToken(replayed.assets) == {snt: "100", usdc: "200"}.toTable
    check not pending.hasPending

  test "only the latest response per account is held":
    var pending: PendingBalances
    discard groupAccountBalances(@[], response(balance(usdc, "1")), lookupFor(@[]), tokensReady = false, pending)
    discard groupAccountBalances(@[], response(balance(usdc, "2")), lookupFor(@[]), tokensReady = false, pending)
    let held = pending.takeAll()
    require held.len == 1
    check held[account][0]["rawBalance"].getStr == "2"

  test "a newer fully resolved response drops the held one":
    var pending: PendingBalances
    discard groupAccountBalances(@[], response(balance(usdc, "1")), lookupFor(@[]), tokensReady = false, pending)
    discard groupAccountBalances(@[], response(balance(usdc, "2")), lookupFor(@[usdc]), tokensReady = true, pending)
    check not pending.hasPending

suite "balances received after the token map is ready":
  test "unknown tokens are skipped and not held":
    var pending: PendingBalances
    let grouped = groupAccountBalances(@[], response(balance(snt, "100"), balance(unknown, "5")),
      lookupFor(@[snt]), tokensReady = true, pending)
    check balancesByToken(grouped.assets) == {snt: "100"}.toTable
    check grouped.unknownTokenKeys == @["1-" & unknown]
    check not pending.hasPending
