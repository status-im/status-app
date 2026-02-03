import std/[json, os, sugar, strutils]
import tables, stint, regex, times, chronicles

import nimcrypto
import account_constants, wallet_constants

import constants as main_constants

const STATUS_DOMAIN* = ".stateofus.eth"
const ETH_DOMAIN* = ".eth"

proc arrayContains*[T](arr: seq[T], value: T): bool =
  return arr.any(x => x == value)

proc hashPassword*(password: string, lower: bool = true): string =
  let hashed = "0x" & $nimcrypto.keccak256.digest(password)

  if lower:
    return hashed.toLowerAscii()

  return hashed

proc prefix*(methodName: string): string =
  result = "wakuext_" & methodName

proc first*(jArray: JsonNode, fieldName, id: string): JsonNode =
  if jArray == nil:
    return nil
  if jArray.kind != JArray:
    raise newException(ValueError, "Parameter 'jArray' is a " & $jArray.kind & ", but must be a JArray")
  for child in jArray.getElems:
    if child{fieldName}.getStr.toLower == id.toLower:
      return child

const sep = when defined(windows): "\\" else: "/"

proc defaultDataDir(): string =
  let homeDir = getHomeDir()
  let parentDir =
    if defined(development):
      parentDir(getAppDir())
    elif homeDir == "":
      getCurrentDir()
    elif main_constants.IS_MACOS:
      joinPath(homeDir, "Library", "Application Support")
    elif defined(windows):
      let targetDir = getEnv("LOCALAPPDATA").string
      if targetDir == "":
        joinPath(homeDir, "AppData", "Local")
      else:
        targetDir
    else:
      let targetDir = getEnv("XDG_CONFIG_HOME").string
      if targetDir == "":
        joinPath(homeDir, ".config")
      else:
        targetDir
  absolutePath(joinPath(parentDir, "Status"))

proc validateLink*(link: string): bool =
  result = true
  if link.len() != 0:
    if not match(
        link, re2"[(http(s)?):\/\/(www\.)?a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)"):
      error "Invalid social link", errDescription = link
      result = false

proc isPathOutOfTheDefaultStatusDerivationTree*(path: string): bool =
  if not path.startsWith(account_constants.PATH_WALLET_ROOT&"/") or
    path.count("'") != 3 or
    path.count("/") != 5:
      return true
  return false

proc contractUniqueKey*(chainId: int, contractAddress: string): string =
  return $chainId & "_" & contractAddress.toLower()

proc intersectSeqs*[T](seq1, seq2: seq[T]): seq[T] =
  for item in seq1:
    if item in seq2:
      result.add(item)

proc stringToUint256*(value: string): Uint256 =
  try:
    value.parse(Uint256)
  except:
    stint.u256(0)

proc createHash*(signature: string): string =
  let signatureHex = if signature.startsWith("0x"): signature[2..^1] else: signature

  return hashPassword(signatureHex, true)

proc resolveUri*(uri: string): string =
  if uri.startsWith(wallet_constants.IPFS_SCHEMA):
    return uri.replace(wallet_constants.IPFS_SCHEMA, wallet_constants.IPFS_GATEWAY)
  return uri

proc timestampToUnix*(timestamp: string, format: string): int64 =
  if timestamp.isEmptyOrWhitespace:
    return 0
  try:
    let dateTime = parse(timestamp, format)
    return dateTime.toTime().toUnix()
  except Exception as e:
    warn "failed to parse timestamp: ", data=timestamp, errName = e.name, errDesription = e.msg

proc timestampToUnix*(timestamp: string): int64 =
  if timestamp.isEmptyOrWhitespace:
    return 0

  var normalized = timestamp

  if normalized.endsWith("Z"):
    normalized = normalized[0..^2] & "+00:00"

  normalized = normalized.replace(" ", "T")

  let dotIdx = normalized.find('.')
  if dotIdx != -1:
    # Find where timezone starts (+ or -)
    var tzIdx = -1
    for i in dotIdx+1..<normalized.len:
      if normalized[i] in {'+', '-'}:
        tzIdx = i
        break

    if tzIdx != -1:
      let fracStr = normalized[dotIdx+1..<tzIdx]

      # Pad to 6 digits or truncate
      var normalizedFrac = fracStr
      while normalizedFrac.len < 6:
        normalizedFrac.add('0')
      if normalizedFrac.len > 6:
        normalizedFrac = normalizedFrac[0..5]

      normalized = normalized[0..dotIdx] & normalizedFrac & normalized[tzIdx..^1]
  else:
    # No fractional seconds - add .000000 before timezone
    var tzIdx = -1
    for i in countdown(normalized.len-1, 0):
      if normalized[i] in {'+', '-'}:
        tzIdx = i
        break

    if tzIdx != -1:
      normalized = normalized[0..<tzIdx] & ".000000" & normalized[tzIdx..^1]

  try:
    let dt = parse(normalized, main_constants.DATE_TIME_FORMAT_2)
    result = dt.toTime.toUnix
    if result < 0:
      result = 0
  except Exception as e:
    warn "failed to parse timestamp: ", data=normalized, errName = e.name, errDesription = e.msg
    return 0

proc isTokenKey*(key: string): bool =
  return not key.isEmptyOrWhitespace and key.toLower.contains("-0x")

proc createTokenKey*(chainId: int, address: string): string =
  return $chainId & wallet_constants.TOKEN_KEY_DELIMITER & address.toLower()

proc createNativeTokenKey*(chainId: int): string =
  return createTokenKey(chainId, wallet_constants.ZERO_ADDRESS)

proc communityKeyToTokenKey*(communityTokenKey: string): string =
  var parts = communityTokenKey.split(wallet_constants.COMMUNITY_TOKEN_KEY_DELIMITER)
  if parts.len < 2:
    raise newException(ValueError, "unsupported community token format")

  return createTokenKey(parts[0].parseInt(), parts[1])