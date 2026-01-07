import nimqml, tables, std/strformat, sequtils, stint
import token_item
import token_owners_item
import token_owners_model
import ../../../../../../app_service/service/community/dto/community
import ../../../../../../app_service/service/community_tokens/dto/community_token
import ../../../../../../app_service/service/community_tokens/community_collectible_owner
import ../../../../../../app_service/common/utils
import ../../../../../../app_service/common/types
import app/global/global_singleton

type
  ModelRole {.pure.} = enum
    ContractUniqueKey = UserRole + 1
    TokenType
    TokenAddress
    Name
    Symbol
    Description
    Supply
    InfiniteSupply
    Transferable
    RemoteSelfDestruct
    ChainId
    DeployState
    Image
    ChainName
    ChainIcon
    TokenOwnersModel
    TokenHoldersLoading
    AccountName
    AccountAddress
    RemainingSupply
    Decimals
    BurnState
    RemotelyDestructState
    PrivilegesLevel
    MultiplierIndex

QtObject:
  type TokenModel* = ref object of QAbstractListModel
    items*: seq[TokenItem]

  proc setup(self: TokenModel)
  proc delete(self: TokenModel)
  proc newTokenModel*(): TokenModel =
    new(result, delete)
    result.setup

  proc getItemIndex(self: TokenModel, chainId: int, contractAddress: string): int =
    for i in 0 ..< self.items.len:
      if self.items[i].tokenDto.address == contractAddress and self.items[i].tokenDto.chainId == chainId:
        return i
    return -1

  proc updateDeployState*(self: TokenModel, chainId: int, contractAddress: string, deployState: DeployState) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1 or self.items[itemIdx].tokenDto.deployState == deployState:
      return

    self.items[itemIdx].tokenDto.deployState = deployState
    let index = self.createIndex(itemIdx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.DeployState.int])

  proc updateAddress*(self: TokenModel, chainId: int, oldContractAddress: string, newContractAddress: string) =
    let itemIdx = self.getItemIndex(chainId, oldContractAddress)
    if itemIdx == -1 or self.items[itemIdx].tokenDto.address == newContractAddress:
      return

    self.items[itemIdx].tokenDto.address = newContractAddress
    let index = self.createIndex(itemIdx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.TokenAddress.int])

  proc updateBurnState*(self: TokenModel, chainId: int, contractAddress: string, burnState: ContractTransactionStatus) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1 or self.items[itemIdx].burnState == burnState:
      return
  
    self.items[itemIdx].burnState = burnState
    let index = self.createIndex(itemIdx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.BurnState.int])

  proc updateRemoteDestructedAddresses*(self: TokenModel, chainId: int, contractAddress: string, remoteDestructedAddresses: seq[string]) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1 or self.items[itemIdx].remoteDestructedAddresses == remoteDestructedAddresses:
      return

    self.items[itemIdx].remoteDestructedAddresses = remoteDestructedAddresses
    let index = self.createIndex(itemIdx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.RemotelyDestructState.int])
    self.items[itemIdx].tokenOwnersModel.updateRemoteDestructState(remoteDestructedAddresses)
    self.dataChanged(index, index, @[ModelRole.TokenOwnersModel.int])

  proc updateSupply*(self: TokenModel, chainId: int, contractAddress: string, supply: Uint256, destructedAmount: Uint256) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1:
      return

    if self.items[itemIdx].tokenDto.supply != supply or self.items[itemIdx].destructedAmount != destructedAmount:
      self.items[itemIdx].tokenDto.supply = supply
      self.items[itemIdx].destructedAmount = destructedAmount
      let index = self.createIndex(itemIdx, 0, nil)
      defer: index.delete
      self.dataChanged(index, index, @[ModelRole.Supply.int])

  proc updateRemainingSupply*(self: TokenModel, chainId: int, contractAddress: string, remainingSupply: Uint256) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1 or self.items[itemIdx].remainingSupply == remainingSupply:
      return

    self.items[itemIdx].remainingSupply = remainingSupply
    let index = self.createIndex(itemIdx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.RemainingSupply.int])

  proc hasTokenHolders*(self: TokenModel, chainId: int, contractAddress: string): bool =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1:
      return false
    return self.items[itemIdx].tokenOwnersModel.count > 0

  proc setCommunityTokenOwners*(self: TokenModel, chainId: int, contractAddress: string, owners: seq[CommunityCollectibleOwner], isOwner: bool) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1:
      return

    self.items[itemIdx].tokenHoldersLoading = false
    let isMyOwnerToken = isOwner and self.items[itemIdx].tokenDto.privilegesLevel == PrivilegesLevel.Owner
    self.items[itemIdx].tokenOwnersModel.setItems(owners.map(proc(owner: CommunityCollectibleOwner): TokenOwnersItem =
      var contactId = owner.contactId
      var name = owner.name
      if isMyOwnerToken:
        # This is the Owner token and we are the Owner. We can hardcode the pubkey
        # The DB doesn't store our own address in the RevealedAddresses list so we patch it here
        contactId = singletonInstance.userProfile.getPubKey()
        name = singletonInstance.userProfile.getName()
      # TODO: provide number of messages here
      result = initTokenOwnersItem(contactId, name, owner.imageSource, 0, owner.collectibleOwner, self.items[itemIdx].remoteDestructedAddresses)
    ))
    let index = self.createIndex(itemIdx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.TokenOwnersModel.int, ModelRole.TokenHoldersLoading.int])

  proc setCommunityTokenHoldersLoading*(self: TokenModel, chainId: int, contractAddress: string, value: bool) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1 or self.items[itemIdx].tokenHoldersLoading == value:
      return

    self.items[itemIdx].tokenHoldersLoading = value
    let index = self.createIndex(itemIdx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.TokenHoldersLoading.int])

  proc countChanged(self: TokenModel) {.signal.}

  proc setItems*(self: TokenModel, items: seq[TokenItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc getOwnerToken*(self: TokenModel): TokenItem =
    for i in 0 ..< self.items.len:
      if(self.items[i].tokenDto.privilegesLevel == PrivilegesLevel.Owner):
        return self.items[i]

  proc appendItem*(self: TokenModel, item: TokenItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc removeItemByChainIdAndAddress*(self: TokenModel, chainId: int, contractAddress: string) =
    let itemIdx = self.getItemIndex(chainId, contractAddress)
    if itemIdx == -1:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, itemIdx, itemIdx)
    self.items.delete(itemIdx)
    self.endRemoveRows()
    self.countChanged()

  proc getCount*(self: TokenModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: TokenModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: TokenModel): Table[int, string] =
    {
      ModelRole.ContractUniqueKey.int:"contractUniqueKey",
      ModelRole.TokenType.int:"tokenType",
      ModelRole.TokenAddress.int:"tokenAddress",
      ModelRole.Name.int:"name",
      ModelRole.Symbol.int:"symbol",
      ModelRole.Description.int:"description",
      ModelRole.Supply.int:"supply",
      ModelRole.InfiniteSupply.int:"infiniteSupply",
      ModelRole.Transferable.int:"transferable",
      ModelRole.RemoteSelfDestruct.int:"remoteSelfDestruct",
      ModelRole.ChainId.int:"chainId",
      ModelRole.DeployState.int:"deployState",
      ModelRole.Image.int:"image",
      ModelRole.ChainName.int:"chainName",
      ModelRole.ChainIcon.int:"chainIcon",
      ModelRole.TokenOwnersModel.int:"tokenOwnersModel",
      ModelRole.TokenHoldersLoading.int:"tokenHoldersLoading",
      ModelRole.AccountName.int:"accountName",
      ModelRole.AccountAddress.int:"accountAddress",
      ModelRole.RemainingSupply.int:"remainingSupply",
      ModelRole.Decimals.int:"decimals",
      ModelRole.BurnState.int:"burnState",
      ModelRole.RemotelyDestructState.int:"remotelyDestructState",
      ModelRole.PrivilegesLevel.int:"privilegesLevel",
      ModelRole.MultiplierIndex.int:"multiplierIndex"
    }.toTable

  method data(self: TokenModel, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.items.len:
      return
    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.ContractUniqueKey:
        result = newQVariant(contractUniqueKey(item.tokenDto.chainId, item.tokenDto.address))
      of ModelRole.TokenType:
        result = newQVariant(item.tokenDto.tokenType.int)
      of ModelRole.TokenAddress:
        result = newQVariant(item.tokenDto.address)
      of ModelRole.Name:
        result = newQVariant(item.tokenDto.name)
      of ModelRole.Symbol:
        result = newQVariant(item.tokenDto.symbol)
      of ModelRole.Description:
        result = newQVariant(item.tokenDto.description)
      of ModelRole.Supply:
        # we need to present maxSupply - destructedAmount
        result = newQVariant((item.tokenDto.supply - item.destructedAmount).toString(10))
      of ModelRole.InfiniteSupply:
        result = newQVariant(item.tokenDto.infiniteSupply)
      of ModelRole.Transferable:
        result = newQVariant(item.tokenDto.transferable)
      of ModelRole.RemoteSelfDestruct:
        result = newQVariant(item.tokenDto.remoteSelfDestruct)
      of ModelRole.ChainId:
        result = newQVariant(item.tokenDto.chainId)
      of ModelRole.DeployState:
        result = newQVariant(item.tokenDto.deployState.int)
      of ModelRole.Image:
        result = newQVariant(item.tokenDto.image)
      of ModelRole.ChainName:
        result = newQVariant(item.chainName)
      of ModelRole.ChainIcon:
        result = newQVariant(item.chainIcon)
      of ModelRole.TokenOwnersModel:
        result = newQVariant(item.tokenOwnersModel)
      of ModelRole.TokenHoldersLoading:
        result = newQVariant(item.tokenHoldersLoading)
      of ModelRole.AccountName:
        result = newQVariant(item.accountName)
      of ModelRole.AccountAddress:
        result = newQVariant(item.tokenDto.deployer)
      of ModelRole.RemainingSupply:
        result = newQVariant(item.remainingSupply.toString(10))
      of ModelRole.Decimals:
        result = newQVariant(item.tokenDto.decimals)
      of ModelRole.BurnState:
        result = newQVariant(item.burnState.int)
      of ModelRole.RemotelyDestructState:
        let destructStatus = if len(item.remoteDestructedAddresses) > 0: ContractTransactionStatus.InProgress.int else: ContractTransactionStatus.Completed.int
        result = newQVariant(destructStatus)
      of ModelRole.PrivilegesLevel:
        result = newQVariant(item.tokenDto.privilegesLevel.int)
      of ModelRole.MultiplierIndex:
        result = newQVariant(if item.tokenDto.tokenType == TokenType.ERC20: 18 else: 0)

  proc `$`*(self: TokenModel): string =
      for i in 0 ..< self.items.len:
        result &= fmt"""TokenModel:
        [{i}]:({$self.items[i]})
        """

  proc setup(self: TokenModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenModel) =
    self.QAbstractListModel.delete

