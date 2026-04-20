# Verbatim copy of the master version of
# src/app_service/service/wallet_account/dto/asset_group_item.nim
# (the OLD ref-object DTOs).
#
# Renamed with `Old` suffix so the bench lib can host BOTH old and new
# variants in the same translation unit without symbol clashes.

import stint

type
  BalanceItemOld* = ref object of RootObj
    account*: string
    groupKey*: string
    tokenKey*: string
    chainId*: int
    tokenAddress*: string
    balance*: Uint256

type
  AssetGroupItemOld* = ref object of RootObj
    key*: string # crossChainId or tokenKey if crossChainId is empty
    balancesPerAccount*: seq[BalanceItemOld]
