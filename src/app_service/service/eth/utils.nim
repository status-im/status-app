import
  std/[json, net, sequtils, strutils, times, unicode],
  std/strformat,
  stew/byteutils,
  json_serialization,
  stint

from sugar import `=>`, `->`

import ../../common/conversion as common_conversion

export common_conversion

proc isOneToOneChat*(chatId: string): bool =
  result = chatId.startsWith("0x") # There is probably a better way to do this

proc keys*(obj: JsonNode): seq[string] =
  result = newSeq[string]()
  for k, _ in obj:
    result.add k

proc handleRPCErrors*(response: string) =
  let parsedReponse = parseJson(response)
  if (parsedReponse.hasKey("error")):
    raise newException(ValueError, parsedReponse["error"]["message"].str)

proc toStUInt*[bits: static[int]](flt: float, T: typedesc[StUint[bits]]): T =
  var stringValue =  fmt"{flt:<.0f}"
  stringValue.removeSuffix('.')
  if (flt >= 0):
    result = parse($stringValue, StUint[bits])
  else:
    result = parse("0", StUint[bits])

proc first*(jArray: JsonNode, fieldName, id: string): JsonNode =
  if jArray == nil:
    return nil
  if jArray.kind != JArray:
    raise newException(ValueError, "Parameter 'jArray' is a " & $jArray.kind & ", but must be a JArray")
  for child in jArray.getElems:
    if child{fieldName}.getStr.toLower == id.toLower:
      return child

proc any*(jArray: JsonNode, fieldName, id: string): bool =
  if jArray == nil:
    return false
  result = false
  for child in jArray.getElems:
    if child{fieldName}.getStr.toLower == id.toLower:
      return true

proc isEmpty*(a: JsonNode): bool =
  case a.kind:
  of JObject: return a.fields.len == 0
  of JArray: return a.elems.len == 0
  of JString: return a.str == ""
  of JNull: return true
  else:
    return false

proc find*[T](s: seq[T], pred: proc(x: T): bool {.closure.}): T {.inline.} =
  let results = s.filter(pred)
  if results.len == 0:
    return default(type(T))
  result = results[0]

proc find*[T](s: seq[T], pred: proc(x: T): bool {.closure.}, found: var bool): T {.inline.} =
  let results = s.filter(pred)
  if results.len == 0:
    found = false
    return default(type(T))
  result = results[0]
  found = true

proc validateTransactionInput*(from_addr, to_addr, assetAddress, value, gas, gasPrice, data: string, isEIP1599Enabled: bool, maxPriorityFeePerGas, maxFeePerGas, uuid: string) =
  if not isAddress(from_addr): raise newException(ValueError, "from_addr is not a valid ETH address")
  if not isAddress(to_addr): raise newException(ValueError, "to_addr is not a valid ETH address")
  if parseFloat(value) < 0: raise newException(ValueError, "value should be a number >= 0")
  if parseInt(gas) <= 0: raise newException(ValueError, "gas should be a number > 0")

  if isEIP1599Enabled:
    if gasPrice != "" and (maxPriorityFeePerGas != "" or maxFeePerGas != ""):
      raise newException(ValueError, "gasPrice can't be used with maxPriorityFeePerGas and maxFeePerGas")
    if gasPrice == "":
      if parseFloat(maxPriorityFeePerGas) <= 0: raise newException(ValueError, "maxPriorityFeePerGas should be a number > 0")
      if parseFloat(maxFeePerGas) <= 0: raise newException(ValueError, "maxFeePerGas should be a number > 0")
  else:
    if parseFloat(gasPrice) <= 0: raise newException(ValueError, "gasPrice should be a number > 0")

  if uuid.isEmptyOrWhitespace(): raise newException(ValueError, "uuid is required")

  if assetAddress != "": # If a token is being used
    if not isAddress(assetAddress): raise newException(ValueError, "assetAddress is not a valid ETH address")
    if assetAddress == "0x0000000000000000000000000000000000000000":  raise newException(ValueError, "assetAddress requires a valid token address")

  if data != "": # If data is being used
    try:
      discard hexToSeqByte(data)
    except ValueError:
      raise newException(ValueError, "data should contain a valid hex string")

proc hex2Time*(hex: string): Time =
  # represents the time since 1970-01-01T00:00:00Z
  fromUnix(fromHex[int64](hex))

proc hex2LocalDateTime*(hex: string): DateTime =
  # Convert hex time (since 1970-01-01T00:00:00Z) into a DateTime using the
  # local timezone.
  hex.hex2Time.local

proc isUnique*[T](key: T, existingKeys: var seq[T]): bool =
  # If the key doesn't exist in the existingKeys seq, add it and return true.
  # Otherwise, the key already existed, so return false.
  # Can be used to deduplicate sequences with `deduplicate[T]`.
  if not existingKeys.contains(key):
    existingKeys.add key
    return true
  return false

proc deduplicate*[T](txs: var seq[T], key: (T) -> string) =
  var existingKeys: seq[string] = @[]
  txs.keepIf(tx => tx.key().isUnique(existingKeys))

# TODO: make this public in nim-web3 lib
proc stripLeadingZeros*(value: string): string =
  var cidx = 0
  # ignore the last character so we retain '0' on zero value
  while cidx < value.len - 1 and value[cidx] == '0':
    cidx.inc
  value[cidx .. ^1]
