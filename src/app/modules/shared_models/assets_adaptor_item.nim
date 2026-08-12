# AssetItem — the flat, already-aggregated value DTO consumed by
# AssetsAdaptorModel. Qt-free so the aggregation core and its DTO can be
# unit-tested with a plain `nim c -r` (no nimqml/seaqt toolchain).
#
# balanceText and error are intentionally left for the QML layer: they depend on
# the user's currency (currencyStore) and live network state
# (networkConnectionStore) and are computed in AssetsView's delegate. chainIds
# carries the token's contributing chains so the delegate can call chainsError.

type
  AssetItem* = object
    key*: string
    name*: string
    symbol*: string
    logoUri*: string
    balance*: float
    balanceText*: string
    balanceLoading*: bool
    error*: string
    marketPrice*: float
    marketChangePct24hour*: float
    marketDetailsAvailable*: bool
    marketDetailsLoading*: bool
    communityId*: string
    communityName*: string
    communityImage*: string
    soulbound*: bool
    ownerToken*: bool
    canBeHidden*: bool
    position*: int
    visible*: bool
    chainIds*: seq[int]
