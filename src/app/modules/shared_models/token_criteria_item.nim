import std/strformat, tables
import backend/collectibles_types

type
  TokenCriteriaItem* = object
    symbol*: string
    name*: string
    amount*: string
    decimals*: int
    `type`*: int
    ensPattern*: string
    criteriaMet*: bool
    addresses*: Table[int, string]

proc initTokenCriteriaItem*(
  symbol: string,
  name: string,
  amount: string,
  decimals: int,
  `type`: int,
  ensPattern: string,
  criteriaMet: bool,
  addresses: Table[int, string]
): TokenCriteriaItem =
  result.symbol = symbol
  result.name = name
  result.`type` = `type`
  result.ensPattern = ensPattern
  result.amount = amount
  result.decimals = decimals
  result.criteriaMet = criteriaMet
  result.addresses = addresses

proc `$`*(self: TokenCriteriaItem): string =
  result = fmt"""TokenCriteriaItem(
    symbol: {self.symbol},
    name: {self.name},
    amount: {self.amount},
    decimals: {self.decimals},
    type: {self.type},
    ensPattern: {self.ensPattern},
    criteriaMet: {self.criteriaMet},
    addresses: {self.addresses}
    ]"""

proc getType*(self: TokenCriteriaItem): int =
  return self.`type`

proc getSymbol*(self: TokenCriteriaItem): string =
  return self.symbol

proc getName*(self: TokenCriteriaItem): string =
  return self.name

proc getAmount*(self: TokenCriteriaItem): string =
  return self.amount

proc getDecimals*(self: TokenCriteriaItem): int =
  return self.decimals

proc getEnsPattern*(self: TokenCriteriaItem): string =
  return self.ensPattern

proc getCriteriaMet*(self: TokenCriteriaItem): bool =
  return self.criteriaMet

proc getAddresses*(self: TokenCriteriaItem): Table[int, string] =
  return self.addresses

proc getContractIdFromFirstAddress*(self: TokenCriteriaItem): string =
  for chainID, address in self.addresses:
    let contractId = ContractID(chainID: chainID, address: address)
    return contractId.toString()
  return ""
