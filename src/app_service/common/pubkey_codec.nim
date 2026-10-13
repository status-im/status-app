## Raw secp256k1 public keys (X || Y, without the 0x04 prefix) and their
## textual forms: "0x04…" hex and the "zQ3…" compressed key, so lists can
## keep 64 bytes per key and format only when a value is shown or sent.

type RawPubKey* = array[64, byte]

const
  HexDigits = "0123456789abcdef"
  Base58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  # multicodec secp256k1-pub, varint encoded
  Secp256k1Codec = [0xe7'u8, 0x01'u8]

proc hexNibble(c: char): int {.inline.} =
  case c
  of '0'..'9': ord(c) - ord('0')
  of 'a'..'f': ord(c) - ord('a') + 10
  of 'A'..'F': ord(c) - ord('A') + 10
  else: -1

proc parseRawPubKey*(hex: string, key: var RawPubKey): bool =
  ## Parses an uncompressed "0x04…" key.
  if hex.len != 4 + 2 * key.len or hex[0] != '0' or hex[1] notin {'x', 'X'} or
      hex[2] != '0' or hex[3] != '4':
    return false
  for i in 0 ..< key.len:
    let hi = hexNibble(hex[4 + 2 * i])
    let lo = hexNibble(hex[5 + 2 * i])
    if hi < 0 or lo < 0:
      return false
    key[i] = byte(hi shl 4 or lo)
  true

proc toPubKeyHex*(key: RawPubKey): string =
  result = newString(4 + 2 * key.len)
  result[0] = '0'
  result[1] = 'x'
  result[2] = '0'
  result[3] = '4'
  for i, b in key:
    result[4 + 2 * i] = HexDigits[int(b shr 4)]
    result[5 + 2 * i] = HexDigits[int(b and 0x0f)]

proc base58Encode(input: openArray[byte]): string =
  var zeros = 0
  while zeros < input.len and input[zeros] == 0:
    inc zeros
  # log(256) / log(58) < 1.37
  var digits = newSeq[byte](input.len * 137 div 100 + 1)
  var used = 0
  for i in zeros ..< input.len:
    var carry = int(input[i])
    var j = 0
    while j < used or carry != 0:
      if j < used:
        carry += int(digits[j]) shl 8
      digits[j] = byte(carry mod 58)
      carry = carry div 58
      inc j
    used = j
  result = newStringOfCap(zeros + used)
  for _ in 0 ..< zeros:
    result.add Base58Alphabet[0]
  for j in countdown(used - 1, 0):
    result.add Base58Alphabet[int(digits[j])]

proc compressedPubKey*(key: RawPubKey): string =
  ## "z" + base58btc(0xe7 0x01 + (0x02 | 0x03 by Y parity) + X), as status-go
  ## multiformat.SerializeLegacyKey.
  var payload: array[Secp256k1Codec.len + 33, byte]
  payload[0] = Secp256k1Codec[0]
  payload[1] = Secp256k1Codec[1]
  payload[2] = if (key[63] and 1) == 1: 0x03 else: 0x02
  for i in 0 ..< 32:
    payload[3 + i] = key[i]
  "z" & base58Encode(payload)
