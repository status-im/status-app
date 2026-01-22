import stint, tables

import backend/collectibles
import app/core/tasks/qt
import ../community/dto/community
import app_service/common/utils as common_utils

include app/core/tasks/common
include app_service/common/json_utils

proc balanceInfoToTable(jsonNode: JsonNode): Table[string, UInt256] =
  for chainBalancesPair in jsonNode.pairs():
    for addressTokenBalancesPair in chainBalancesPair.val.pairs():
      for tokenBalancesPair in addressTokenBalancesPair.val.pairs():
        let amount = fromHex(UInt256, tokenBalancesPair.val.getStr)
        if amount != stint.u256(0):
          result[addressTokenBalancesPair.key.toUpper] = amount
        break

type
  FetchCollectibleOwnersArg = ref object of QObjectTaskArg
    chainId*: int
    contractAddress*: string
    communityId*: string

proc fetchCollectibleOwnersTaskArg(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchCollectibleOwnersArg](argEncoded)
  try:
    var response = collectibles.getCollectibleOwnersByContractAddress(arg.chainId, arg.contractAddress)

    var owners = fromJson(response.result, CollectibleContractOwnership).owners
    owners = owners.filter(x => x.address != ZERO_ADDRESS)

    response = communities_backend.getCommunityMembersForWalletAddresses(arg.communityId, arg.chainId)

    let communityCollectibleOwners = owners.map(proc(owner: CollectibleOwner): CommunityCollectibleOwner =
      let ownerAddressUp = owner.address.toUpper()
      for responseAddress in response.result.keys():
        let responseAddressUp = responseAddress.toUpper()
        if ownerAddressUp == responseAddressUp:
          let member = response.result[responseAddress].toContactsDto()
          return CommunityCollectibleOwner(
            contactId: member.id,
            name: member.displayName,
            imageSource: member.image.thumbnail,
            collectibleOwner: owner
          )
      return CommunityCollectibleOwner(collectibleOwner: owner)
    )

    let output = %* {
      "chainId": arg.chainId,
      "contractAddress": arg.contractAddress,
      "communityId": arg.communityId,
      "result": %communityCollectibleOwners,
      "error": ""
    }
    arg.finish(output)
  except Exception as e:
    let output = %* {
      "chainId": arg.chainId,
      "contractAddress": arg.contractAddress,
      "communityId": arg.communityId,
      "result": "",
      "error": e.msg
    }
    arg.finish(output)

type
  FetchAssetOwnersArg = ref object of QObjectTaskArg
    chainId*: int
    contractAddress*: string
    communityId*: string

proc fetchAssetOwnersTaskArg(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchAssetOwnersArg](argEncoded)
  try:
    let addressesResponse = communities_backend.getCommunityMembersForWalletAddresses(arg.communityId, arg.chainId)
    var walletMemberTable: Table[string, ContactsDto]
    var allCommunityMembersAddresses: seq[string] = @[]
    for address, member in addressesResponse.result.pairs():
      allCommunityMembersAddresses.add(address)
      walletMemberTable[address.toUpper] = member.toContactsDto()

    let tokenKey = common_utils.createTokenKey(arg.chainId, arg.contractAddress)
    let balancesResponse = backend.fetchTokenBalances(allCommunityMembersAddresses, @[tokenKey])

    let walletBalanceTable = balanceInfoToTable(balancesResponse.result)

    var collectibleOwners: seq[CommunityCollectibleOwner] = @[]
    for wallet, balance in walletBalanceTable.pairs():
      let member = walletMemberTable[wallet]
      let collectibleBalance = CollectibleBalance(tokenId: stint.u256(0), balance: balance)
      let collectibleOwner = CollectibleOwner(address: wallet, balances: @[collectibleBalance])
      collectibleOwners.add(CommunityCollectibleOwner(
        contactId: member.id,
        name: member.displayName,
        imageSource: member.image.thumbnail,
        collectibleOwner: collectibleOwner
      ))

    let output = %* {
      "chainId": arg.chainId,
      "contractAddress": arg.contractAddress,
      "communityId": arg.communityId,
      "result": %collectibleOwners,
      "error": ""
    }
    arg.finish(output)
  except Exception as e:
    let output = %* {
      "chainId": arg.chainId,
      "contractAddress": arg.contractAddress,
      "communityId": arg.communityId,
      "result": "",
      "error": e.msg
    }
    arg.finish(output)

type
  GetCommunityTokensDetailsArg = ref object of QObjectTaskArg
    communityId*: string

proc getCommunityTokensDetailsTaskArg(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[GetCommunityTokensDetailsArg](argEncoded)

  try:
    proc getRemainingSupply(chainId: int, contractAddress: string): string =
      let response = tokens_backend.remainingSupply(chainId, contractAddress)
      return response.result.getStr()

    proc getPendingTransactions(): seq[TransactionDto] =
      let response = backend.getPendingTransactions().result
      if (response.kind == JArray and response.len > 0):
        return response.getElems().map(x => x.toPendingTransactionDto())

      return @[]

    proc getCommunityTokenBurnState(chainId: int, contractAddress: string): ContractTransactionStatus =
      let allPendingTransactions = getPendingTransactions()

      let burnTransactions = allPendingTransactions.filter(x => x.typeValue == $PendingTransactionTypeDto.BurnCommunityToken)
      for transaction in burnTransactions:
        if transaction.chainId == chainId and transaction.to.toLower == contractAddress.toLower:
          return ContractTransactionStatus.InProgress
      return ContractTransactionStatus.Completed

    proc getRemoteDestructedAddresses(chainId: int, contractAddress: string): seq[string] =
      let allPendingTransactions = getPendingTransactions()
      let remoteDestructTransactions = allPendingTransactions.filter(x => x.typeValue == $PendingTransactionTypeDto.RemoteDestructCollectible)
      for transaction in remoteDestructTransactions:
        let remoteDestructTransactionDetails = toRemoteDestroyTransactionDetails(parseJson(transaction.additionalData))
        if remoteDestructTransactionDetails.chainId == chainId and remoteDestructTransactionDetails.contractAddress == contractAddress:
          return remoteDestructTransactionDetails.addresses

    proc getCommunityToken(communityTokens: seq[CommunityTokenDto], chainId: int, address: string): CommunityTokenDto =
      for token in communityTokens:
        if token.chainId == chainId and token.address == address:
          return token

    proc getRemoteDestructedAmount(communityTokens: seq[CommunityTokenDto],chainId: int, contractAddress: string): string =
      let tokenType = getCommunityToken(communityTokens, chainId, contractAddress).tokenType
      if tokenType != TokenType.ERC721:
        return "0"
      let response = tokens_backend.remoteDestructedAmount(chainId, contractAddress)
      return response.result.getStr()

    proc createTokenItemJson(communityTokens: seq[CommunityTokenDto], tokenDto: CommunityTokenDto): JsonNode =
      try:
        var remainingSupply = tokenDto.supply.toString(10)
        var burnState = ContractTransactionStatus.Completed
        var remoteDestructedAddresses: seq[string] = @[]
        var destructedAmount = "0"

        if tokenDto.deployState == DeployState.Deployed:
          try:
            remainingSupply =
              if tokenDto.infiniteSupply:
                "0"
              else:
                getRemainingSupply(tokenDto.chainId, tokenDto.address)

            burnState = getCommunityTokenBurnState(tokenDto.chainId, tokenDto.address)
            remoteDestructedAddresses = getRemoteDestructedAddresses(tokenDto.chainId, tokenDto.address)

            destructedAmount = getRemoteDestructedAmount(communityTokens, tokenDto.chainId, tokenDto.address)
          except Exception as e:
            error "Remote token state retrieval error", message = getCurrentExceptionMsg()

        return %* {
          "address": tokenDto.address,
          "remainingSupply": remainingSupply,
          "burnState": burnState.int,
          "remoteDestructedAddresses": %* (remoteDestructedAddresses),
          "destructedAmount": destructedAmount,
          "error": "",
        }
      except Exception as e:
        return %* {
          "error": e.msg,
        }

    let response = tokens_backend.getCommunityTokens(arg.communityId)

    if not response.error.isNil:
      raise newException(ValueError, "Error getCommunityTokens" & response.error.message)

    let communityTokens = parseCommunityTokens(response)

    let communityTokenJsonItems = communityTokens.map(proc(tokenDto: CommunityTokenDto): JsonNode =
      result = createTokenItemJson(communityTokens, tokenDto)
      if result["error"].getStr != "":
        raise newException(ValueError, "Error creating token item" & result["error"].getStr)
    )

    let output = %* {
      "communityTokensResponse": response,
      "communityTokenJsonItems": communityTokenJsonItems,
      "communityId": arg.communityId,
      "error": ""
    }
    arg.finish(output)
  except Exception as e:
    let output = %* {
      "communityId": arg.communityId,
      "error": e.msg
    }
    arg.finish(output)

type
  GetAllCommunityTokensArg = ref object of QObjectTaskArg

proc getAllCommunityTokensTaskArg(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[GetAllCommunityTokensArg](argEncoded)
  try:
    let response = tokens_backend.getAllCommunityTokens()

    let output = %* {
      "response": response,
      "error": ""
    }
    arg.finish(output)
  except Exception as e:
    let output = %* {
      "error": e.msg
    }
    arg.finish(output)

type
  GetOwnerTokenOwnerAddressArgs = ref object of QObjectTaskArg
    chainId*: int
    contractAddress*: string

proc getOwnerTokenOwnerAddressTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[GetOwnerTokenOwnerAddressArgs](argEncoded)
  try:
    let response = tokens_backend.getOwnerTokenOwnerAddress(arg.chainId, arg.contractAddress)
    let output = %* {
      "chainId": arg.chainId,
      "contractAddress": arg.contractAddress,
      "address": response.result.getStr(),
      "error": ""
    }
    arg.finish(output)
  except Exception as e:
    let output = %* {
      "chainId": arg.chainId,
      "contractAddress": arg.contractAddress,
      "error": e.msg
    }
    arg.finish(output)