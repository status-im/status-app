import stint

type
  # {.acyclic.}: only value fields, no refs — without it ORC treats the inheritable
  # ref as potentially cyclic, registers every item as a cycle root and runs a full
  # collection from the balances hot path.
  BalanceItem* {.acyclic.} = ref object of RootObj
    account*: string
    groupKey*: string
    tokenKey*: string
    chainId*: int
    tokenAddress*: string
    balance*: Uint256
    loading*: bool ## true while status-go has no fetched balance for this (account, chain, token) yet

type
  # {.acyclic.}: a group holds a seq of (acyclic) BalanceItems and no back-edge, so it
  # is tree-shaped and ORC can skip cycle tracking for it too.
  AssetGroupItem* {.acyclic.} = ref object of RootObj
    key*: string # crossChainId or tokenKey if crossChainId is empty
    balancesPerAccount*: seq[BalanceItem]
