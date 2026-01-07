import std/strformat, sequtils, stint
import app_service/service/community_tokens/dto/community_token
import app_service/service/community_tokens/community_collectible_owner
import app_service/service/network/network_item
import app_service/common/types

import token_owners_model
import token_owners_item

export community_token

type
  TokenItem* = object
    tokenDto*: CommunityTokenDto
    chainName*: string
    chainIcon*: string
    accountName*: string
    remainingSupply*: Uint256
    destructedAmount*: Uint256
    burnState*: ContractTransactionStatus
    remoteDestructedAddresses*: seq[string]
    tokenOwnersModel*: token_owners_model.TokenOwnersModel
    tokenHoldersLoading*: bool

proc initTokenItem*(
  tokenDto: CommunityTokenDto,
  network: NetworkItem,
  tokenOwners: seq[CommunityCollectibleOwner],
  accountName: string,
  burnState: ContractTransactionStatus,
  remoteDestructedAddresses: seq[string],
  remainingSupply: Uint256,
  destructedAmount: Uint256,
): TokenItem =
  result.tokenDto = tokenDto
  if network != nil:
    result.chainName = network.chainName
    result.chainIcon = network.iconURL
  result.accountName = accountName
  result.remainingSupply = remainingSupply
  result.destructedAmount = destructedAmount
  result.burnState = burnState
  result.remoteDestructedAddresses = remoteDestructedAddresses
  result.tokenOwnersModel = newTokenOwnersModel()
  result.tokenOwnersModel.setItems(tokenOwners.map(proc(owner: CommunityCollectibleOwner): TokenOwnersItem =
    # TODO: provide number of messages here
    result = initTokenOwnersItem(owner.contactId, owner.name, owner.imageSource, 0, owner.collectibleOwner, remoteDestructedAddresses)
  ))
  result.tokenHoldersLoading = false

proc `$`*(self: TokenItem): string =
  result = fmt"""TokenItem(
    tokenDto: {self.tokenDto},
    chainName: {self.chainName},
    chainIcon: {self.chainIcon},
    remainingSupply: {self.remainingSupply},
    destructedAmount: {self.destructedAmount},
    burnState: {self.burnState},
    tokenOwnersModel: {self.tokenOwnersModel},
    tokenHoldersLoading: {self.tokenHoldersLoading},
    remoteDestructedAddresses: {self.remoteDestructedAddresses}
    ]"""

