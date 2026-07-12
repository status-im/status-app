# DTOs consumed by TokenSelectorModel, the terminal model behind the send/swap/buy
# token pickers. Qt-free so the builder and its DTOs unit-test with a plain
# `nim c -r` (no nimqml/seaqt toolchain).
#
# The per-chain `chips` are the `balances` submodel the picker delegate renders
# (network icon + formatted amount). Balance is carried as a float in logical
# units; locale formatting stays in the QML delegate (guideline: convert to
# display form only at the UI layer).

type
  TokenSelectorChip* = object
    chainId*: int
    iconUrl*: string     ## network icon
    chainName*: string
    balance*: float      ## logical units (already divided by decimals), for display
    rawBalance*: string  ## on-chain wei as a BigInt string; send reads this directly

  TokenSelectorTokenRef* = object
    ## Per-chain token identity, independent of balances. Feeds the `tokens`
    ## submodel the buy modal's provider filter reads (chainId + token key) — the
    ## non-owned popular tokens carry no chips, so this is the only source of it.
    key*: string
    chainId*: int

  TokenSelectorItem* = object
    key*: string
    name*: string
    symbol*: string
    logoUri*: string
    communityId*: string
    decimals*: int           ## token decimals; send pairs it with a chip's rawBalance
    marketPrice*: float      ## per-token fiat price; swap reads it as `cryptoPrice`
    currentBalance*: float   ## summed token amount over the filtered chips
    currencyBalance*: float  ## currentBalance * marketPrice (fiat), 0 when no price
    hasBalance*: bool        ## currentBalance != 0 -> "owned" section, else "popular"
    chips*: seq[TokenSelectorChip]
    tokens*: seq[TokenSelectorTokenRef]
