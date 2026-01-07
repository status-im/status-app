import std/strformat

type Item* = ref object
  key: string
  chainId: int
  address: string

proc initItem*(chainID: int, address: string): Item =
  result = Item()
  result.key = $chainID & address
  result.chainID = chainID
  result.address = address

proc `$`*(self: Item): string =
  result = fmt"""ContractItem(
    key: {self.key},
    chainId: {$self.chainId},
    address: {self.address},
    ]"""

proc key*(self: Item): string {.inline.} =
  self.key

proc chainId*(self: Item): int {.inline.} =
  self.chainId

proc address*(self: Item): string {.inline.} =
  self.address
