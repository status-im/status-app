import nimqml
import std/[strformat, strutils, httpclient, os, uri], regex, stint
import stew/byteutils
import ./utils/qrcodegen

# Services as instances shouldn't be used in this class, just some general/global procs
import ../../app_service/common/conversion
import ../../app_service/service/visual_identity/service as procs_from_visual_identity_service
import ../../backend/accounts as status_accounts

include ../../app_service/service/accounts/utils

const URL_STATUS_OK* = "200 OK"

QtObject:
  type Utils* = ref object of QObject

  proc isCompressedPubKey*(self: Utils, publicKey: string): bool
  proc getDecompressedPk*(self: Utils, compressedKey: string): string

  proc setup(self: Utils)
  proc delete*(self: Utils)
  proc newUtils*(): Utils =
    new(result, delete)
    result.setup

  proc setup(self: Utils) =
    self.QObject.setup

  proc delete*(self: Utils) =
    self.QObject.delete

  proc fromPathUri*(self: Utils, path: string): string {.slot.} =
    var formattedPath = replace(path, "file://", "")
    # Sometimes the original path only contains `file:` without the `//`
    formattedPath = replace(formattedPath, "file:", "")
    result = uri.decodeUrl(formattedPath, decodePlus=false)
    if defined(windows):
      # Windows doesn't work with paths starting with a slash
      result.removePrefix('/')

  proc toFileUri*(self: Utils, path: string): string {.slot.} =
    let absPath = absolutePath(path)   # Ensure it's absolute
    let uriPath = if defined(windows):
                    # Convert to URI-compliant format
                    "file:///" & absPath.replace("\\", "/")
                  else:
                    "file://" & absPath
    return uriPath

  proc isAlias*(self: Utils, value: string): bool {.slot.} =
    result = isAlias(value)

  proc generateAlias*(self: Utils, publicKey: string): string {.slot.} =
    return generateAlias(publicKey)

  proc eth2Hex*(self: Utils, eth: float): string {.slot.} =
    return "0x" & conversion.eth2Wei(eth, 18).toHex()

  proc wei2Eth*(self: Utils, wei: string, decimals: int): string {.slot.} =
    var weiValue = wei
    if(weiValue.startsWith("0x")):
      weiValue = fromHex(Stuint[256], weiValue).toString()
    return conversion.wei2Eth(weiValue, decimals)

  proc hexToDec*(self: Utils, hexValue: string): string  {.slot.} =
    return fromHex(Stuint[256], hexValue).toString()

  proc hex2Ascii*(self: Utils, value: string): string {.slot.} =
    result = string.fromBytes(hexToSeqByte(value))

  proc ascii2Hex*(self: Utils, value: string): string {.slot.} =
    result = "0x" & toHex(value)

  proc stripTrailingZeroes(value: string): string =
    var str = value.strip(leading = false, chars = {'0'})
    if str[str.len - 1] == '.':
      add(str, "0")
    return str

  proc gwei2Hex*(self: Utils, gwei: float): string {.slot.} =
    return "0x" & conversion.gwei2Wei(gwei).toHex()

  proc generateQRCodeSVG*(self: Utils, text: string, border: int = 0): string =
    var qr0: array[0..qrcodegen_BUFFER_LEN_MAX, uint8]
    var tempBuffer: array[0..qrcodegen_BUFFER_LEN_MAX, uint8]
    let ok: bool = qrcodegen_encodeText(text, tempBuffer[0].addr, qr0[0].addr, qrcodegen_Ecc_MEDIUM, qrcodegen_VERSION_MIN, qrcodegen_VERSION_MAX, qrcodegen_Mask_AUTO, true);
    if not ok:
      raise newException(Exception, "Error generating QR Code")
    else:
      var parts: seq[string] = @[]
      let size = qrcodegen_getSize(qr0[0].addr);
      for y in countup(0, size):
        for x in countup(0, size):
          if qrcodegen_getModule(qr0[0].addr, x.cint, y.cint):
            parts.add(&"M{x + border},{y + border}h1v1h-1z")
      let partsStr = parts.join(" ")
      result = &"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\"><svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" viewBox=\"0 0 {size + border * 2} {size + border * 2}\" stroke=\"none\"><rect width=\"100%\" height=\"100%\" fill=\"#FFFFFF\"/><path d=\"{partsStr}\" fill=\"#000000\"/></svg>"

  proc qrCode*(self: Utils, text:string): string {.slot.} =
    result = "data:image/svg+xml;utf8," & self.generateQRCodeSVG(text, 2)

  proc plainText*(self: Utils, text: string): string {.slot.} =
    result = plain_text(text)

  proc escapeHtml*(self: Utils, text: string): string {.slot.} =
    result = escape_html(text)

  proc getEmojiHashAsJson*(self: Utils, publicKey: string): string {.slot.} =
    var pk = publicKey
    if self.isCompressedPubKey(publicKey):
      pk = self.getDecompressedPk(publicKey)
    procs_from_visual_identity_service.getEmojiHashAsJson(pk)

  proc getColorId*(self: Utils, publicKey: string): int {.slot.} =
    var pk = publicKey
    if self.isCompressedPubKey(publicKey):
      pk = self.getDecompressedPk(publicKey)
    int(procs_from_visual_identity_service.colorIdOf(pk))

  proc getCompressedPk*(self: Utils, publicKey: string): string {.slot.} =
    compressPk(publicKey)

  proc getDecompressedPk*(self: Utils, compressedKey: string): string {.slot.} =
    decompressPk(compressedKey)

  proc decompressCommunityKey*(self: Utils, publicKey: string): string {.slot.} =
    decompressCommunityKey(publicKey)

  proc compressCommunityKey*(self: Utils, publicKey: string): string {.slot.} =
    compressCommunityKey(publicKey)

  proc isCompressedPubKey*(self: Utils, publicKey: string): bool {.slot.} =
    conversion.isCompressedPubKey(publicKey)

  # Changes publicKey compression between 33-bytes and multiformat zQ..
  proc changeCommunityKeyCompression*(self: Utils, publicKey: string): string {.slot.} =
    changeCommunityKeyCompression(publicKey)

  proc removeHexPrefix*(self: Utils, value: string): string =
    if value.startsWith("0x"):
      return value[2..^1]
    return value

  proc isValidURL*(self: Utils, url: string): bool {.slot.} =
    var client = newHttpClient()
    defer: client.close()
    try:
      return client.head(url).status == URL_STATUS_OK
    except:
      return false

  proc isHexFormat*(self: Utils, value: string): bool {.slot.} =
    return value.match(re2"^0x[0-9a-fA-F]+$")

  proc isChatKey*(self: Utils, value: string): bool {.slot.} =
    result = (self.isHexFormat(value) and len(value) == 132) or self.isCompressedPubKey(value)

  # Check if a string is a valid Base64 data URL
  # This function is to be used in async tasks
  proc isBase64DataUrl*(str: string): bool =
    return str.match(re2"(?i)^data:[^,]*;base64,[A-Za-z0-9+/=]+$")

  # This function is to be used in QML
  proc isBase64DataUrl*(self: Utils, str: string): bool {.slot.} =
    return isBase64DataUrl(str)
