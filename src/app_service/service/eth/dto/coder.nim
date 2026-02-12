import stint, web3/eth_api_types

type
  Transfer* = object
    to*: Address
    value*: Stuint[256]

  Approve* = object
    to*: Address
    value*: Stuint[256]

# TODO: Figure out a way to parse a bool as a Bool instead of bool, as it is
# done in nim-web3
func decode*(input: string, offset: int, to: var bool): int {.inline.} =
  let val = input[offset..offset+63].parse(Int256)
  to = val.truncate(int) == 1
  64

# TODO: This is taken directly from nim-web3 in order to be able to decode
# booleans. I could not get the type Bool, as used in nim-web3, to be decoded
# properly, and instead resorted to a standard bool type.
func decodeHere*(input: string, offset: int, obj: var object): int =
  var offset = offset
  for field in fields(obj):
    offset += decode(input, offset, field)

func decodeContractResponse*[T](input: string): T =
  result = T()
  discard decodeHere(input.strip0xPrefix, 0, result)