import stint

type
  # Flat balance item without group key - used for storing raw balance data
  FlatBalanceItem* = ref object of RootObj
    account*: string
    chainId*: int
    tokenAddress*: string
    tokenKey*: string
    balance*: Uint256

  # Balance item with group key - used in grouped assets model
  BalanceItem* = ref object of RootObj
    account*: string
    groupKey*: string
    tokenKey*: string
    chainId*: int
    tokenAddress*: string
    balance*: Uint256

  # State information for balance fetching per chain/account
  BalanceState* = ref object of RootObj
    state*: int # LoaderState from status-go
    atBlockNumber*: string
    atBlockHash*: string
    fetchedAt*: int64

  AssetGroupItem* = ref object of RootObj
    key*: string # crossChainId or tokenKey if crossChainId is empty
    balancesPerAccount*: seq[BalanceItem]
