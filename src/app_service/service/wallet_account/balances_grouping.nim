## Pure grouping of per-account token balances (the `result` object of a
## build-tokens response) into AssetGroupItems, keyed by token group.
##
## Balances can arrive before the token service has applied its first refresh,
## when most token keys don't resolve yet. Those accounts' balances are held in
## PendingBalances (latest response per account) and re-applied once the token
## map is ready, instead of being dropped.

import json, tables, sequtils, sugar, strutils, stint

import app_service/service/token/items/token
import dto/asset_group_item

type
  TokenLookup* = proc(key: string): TokenItem

  PendingBalances* = object
    byAccount: OrderedTable[string, JsonNode] # [account, balance details array]

  GroupedBalances* = object
    accounts*: seq[string]
    assets*: seq[AssetGroupItem]
    allTokensHaveError*: bool
    unknownTokenKeys*: seq[string] # skipped after the token map was ready

proc hasPending*(self: PendingBalances): bool =
  self.byAccount.len > 0

proc takeAll*(self: var PendingBalances): JsonNode =
  ## Drain the held balances as a `result` object ready to be grouped again.
  result = newJObject()
  for account, balances in self.byAccount:
    result[account] = balances
  self.byAccount.clear()

proc groupAccountBalances*(current: seq[AssetGroupItem], resultObj: JsonNode, lookup: TokenLookup,
    tokensReady: bool, pending: var PendingBalances): GroupedBalances =
  result.allTokensHaveError = true

  var groupedAssetsBalances: Table[string, AssetGroupItem] # [crossChainId (or tokenKey if crossChainId is empty), AssetGroupItem]
  # add current assets to the groupedAssetsBalances first
  for asset in current:
    if not groupedAssetsBalances.hasKey(asset.key):
      groupedAssetsBalances[asset.key] = asset
    else:
      groupedAssetsBalances[asset.key].balancesPerAccount.add(asset.balancesPerAccount)

  if not resultObj.isNil and resultObj.kind == JObject:
    for accountAddress, balanceDetailsObj in resultObj:
      result.accounts.add(accountAddress)
      # A newer response supersedes whatever was held for the account.
      pending.byAccount.del(accountAddress)

      # Delete all existing entries for the account for whom assets were requested,
      # for a new account the balances per address per chain will simply be appended later
      var assetsToBeDeleted: seq[string] = @[]
      for _, asset in groupedAssetsBalances:
        asset.balancesPerAccount = asset.balancesPerAccount.filter(balanceItem => balanceItem.account != accountAddress)
        if asset.balancesPerAccount.len == 0:
          assetsToBeDeleted.add(asset.key)

      for a in assetsToBeDeleted:
        groupedAssetsBalances.del(a)

      if balanceDetailsObj.kind != JArray:
        continue

      for balanceDetail in balanceDetailsObj.getElems():
        let tokenItem = createTokenItem(TokenDto(
          address: balanceDetail{"tokenAddress"}.getStr,
          chainId: balanceDetail{"tokenChainId"}.getInt
        ))

        let token = lookup(tokenItem.key)
        if token.isNil:
          if tokensReady:
            result.unknownTokenKeys.add(tokenItem.key)
          else:
            pending.byAccount[accountAddress] = balanceDetailsObj
          continue

        # Expecting "<nil>" values comming from status-go when the entry is nil, but with new format it should never be nil
        var rawBalance: Uint256 = u256(0)
        let rawBalanceStr = balanceDetail{"rawBalance"}.getStr
        if not rawBalanceStr.contains("nil"):
          rawBalance = rawBalanceStr.parse(Uint256)

        let hasError = balanceDetail{"hasError"}.getBool
        if not hasError:
          result.allTokensHaveError = false

        let groupKey = token.groupKey
        if not groupedAssetsBalances.hasKey(groupKey):
          groupedAssetsBalances[groupKey] = AssetGroupItem(key: groupKey)

        groupedAssetsBalances[groupKey].balancesPerAccount.add(BalanceItem(
          account: accountAddress,
          groupKey: groupKey,
          tokenKey: token.key,
          tokenAddress: token.address,
          chainId: token.chainId,
          balance: rawBalance,
          loading: hasError
        ))

  result.assets = toSeq(groupedAssetsBalances.values)
