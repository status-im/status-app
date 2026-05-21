import stint

type
  BalanceItem* = ref object of RootObj
    account*: string
    groupKey*: string
    tokenKey*: string
    chainId*: int
    tokenAddress*: string
    balance*: Uint256
    loading*: bool ## true while status-go has no fetched balance for this (account, chain, token) yet

type
  AssetGroupItem* = ref object of RootObj
    key*: string # crossChainId or tokenKey if crossChainId is empty
    balancesPerAccount*: seq[BalanceItem]
