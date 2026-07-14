# DTOs consumed by CollectiblesSelectorModel, the terminal model behind the send
# modal's collectibles picker. Qt-free so the builder and its DTOs unit-test with
# a plain `nim c -r` (no nimqml/seaqt toolchain).
#
# Balances are plain ints (ERC-721 = 1, ERC-1155 = on-chain count); no floats.
# Icon fallback to the default token icon stays in the QML delegate (needs the
# Assets singleton), so `icon` here is only imageUrl-or-mediaUrl.

type
  CollectibleOwnership* = object
    ## One (account, balance) entry of a collectible's ownership submodel.
    accountAddress*: string
    balance*: int

  CollectibleItem* = object
    ## Input-shaped collectible (the raw cross-chain universe row). Mirrors the
    ## adaptor's `collectiblesModel` contract; the producer maps the service model
    ## onto this (note: the raw model's key role is `uid`).
    key*: string                            ## == the raw model's `uid` role value
    chainId*: int
    collectionUid*: string
    contractAddress*: string
    tokenId*: string
    tokenType*: int                         ## Constants.TokenType (ERC721 = 2, ERC1155 = 3)
    name*: string
    collectionName*: string
    mediaUrl*: string
    imageUrl*: string
    communityId*: string
    communityName*: string
    communityImage*: string
    communityPrivilegesLevel*: int
    ownership*: seq[CollectibleOwnership]

  CollectiblesNetworkInfo* = object
    chainId*: int
    chainName*: string
    iconUrl*: string

  CollectiblesSelectorParams* = object
    accountKey*: string                     ## empty = any account
    enabledChainIds*: seq[int]              ## empty = any chain
    filterCommunityOwnerAndMasterTokens*: bool

  FlatCollectible* = object
    ## A row of the `filteredFlatModel` view: input-shaped, filtered to the
    ## account + chains with per-account balance >= 1, joined with its network.
    ## `groupingValue` (communityId else collectionUid) drives grouping + sort.
    key*: string                           ## == uid (identity); also exposed as `uid`
    chainId*: int
    collectionUid*: string
    contractAddress*: string
    tokenId*: string
    tokenType*: int                        ## Constants.TokenType (ERC721/ERC1155)
    name*: string
    collectionName*: string
    mediaUrl*: string
    imageUrl*: string
    icon*: string                          ## imageUrl or mediaUrl (default in QML)
    iconUrl*: string                       ## network icon (joined)
    chainName*: string
    communityId*: string
    communityName*: string
    communityImage*: string
    communityPrivilegesLevel*: int
    balance*: int                          ## summed ownership for the account
    groupingValue*: string

  CollectibleSubItem* = object
    ## A subitem row of a group: a collectible (other groups) or a collection
    ## (community groups). `balance` = the collectible's owned amount, or the
    ## collection's item count.
    key*: string
    name*: string
    balance*: int
    icon*: string
    iconUrl*: string

  CollectibleGroup* = object
    ## A top-level grouped row. `groupKey` (== groupingValue) is the diff identity.
    groupKey*: string
    groupName*: string
    icon*: string
    iconUrl*: string
    imageUrl*: string                      ## representative collectible's imageUrl
    mediaUrl*: string                      ## representative collectible's mediaUrl
    groupType*: string                     ## "community" | "other"
    subitems*: seq[CollectibleSubItem]
