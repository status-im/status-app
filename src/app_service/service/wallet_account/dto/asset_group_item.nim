import stint

# Value types (not `ref object`) so they can live in a CowSeq.  CoW depends
# on Nim's value-copy semantics: every CoW fork must be an independent copy,
# which means the inner items must not share heap state via references.
#
# `==` is implemented explicitly because model_sync's diff calls it through
# the field-level `getRoles` callbacks (and tests rely on it directly).

type
  BalanceItem* = object
    account*: string
    groupKey*: string
    tokenKey*: string
    chainId*: int
    tokenAddress*: string
    balance*: Uint256

proc `==`*(a, b: BalanceItem): bool =
  a.account == b.account and
    a.groupKey == b.groupKey and
    a.tokenKey == b.tokenKey and
    a.chainId == b.chainId and
    a.tokenAddress == b.tokenAddress and
    a.balance == b.balance

type
  AssetGroupItem* = object
    key*: string  # crossChainId or tokenKey if crossChainId is empty
    balancesPerAccount*: seq[BalanceItem]

proc `==`*(a, b: AssetGroupItem): bool =
  a.key == b.key and a.balancesPerAccount == b.balancesPerAccount
