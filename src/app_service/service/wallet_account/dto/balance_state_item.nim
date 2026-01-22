type BalanceStateItem* = ref object of RootObj
  account*: string
  chainId*: int
  state*: int # LoaderState from backend
  atBlockNumber*: string
  atBlockHash*: string
  fetchedAt*: int64