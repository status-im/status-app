import std/strformat, stint
import backend/collectibles_types
import ../../../../../../app_service/common/types

type
  TokenOwnersItem* = object
    contactId*: string
    name*: string
    imageSource*: string
    numberOfMessages*: int
    ownerDetails*: CollectibleOwner
    amount*: Uint256
    remotelyDestructState*: ContractTransactionStatus

proc remoteDestructTransactionStatus*(remoteDestructedAddresses: seq[string], address: string): ContractTransactionStatus =
  if remoteDestructedAddresses.contains(address):
    return ContractTransactionStatus.InProgress
  return ContractTransactionStatus.Completed

proc initTokenOwnersItem*(
  contactId: string,
  name: string,
  imageSource: string,
  numberOfMessages: int,
  ownerDetails: CollectibleOwner,
  remoteDestructedAddresses: seq[string]
): TokenOwnersItem =
  result.contactId = contactId
  result.name = name
  result.imageSource = imageSource
  result.numberOfMessages = numberOfMessages
  result.ownerDetails = ownerDetails
  result.remotelyDestructState = remoteDestructTransactionStatus(remoteDestructedAddresses, ownerDetails.address)
  for balance in ownerDetails.balances:
    result.amount = result.amount + balance.balance

proc `$`*(self: TokenOwnersItem): string =
  result = fmt"""TokenOwnersItem(
    contactId: {self.contactId},
    name: {self.name},
    numberOfMessages: {self.numberOfMessages},
    amount: {self.amount},
    ownerDetails: {self.ownerDetails}
    ]"""

