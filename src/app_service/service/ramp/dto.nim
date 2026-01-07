
import json, json_serialization, std/strformat
import options

include app_service/common/json_utils
import app_service/service/token/dto/token

type
  CryptoRampDto* = ref object of RootObj
    id*: string
    name*: string
    description*: string
    fees*: string
    logoUrl*: string
    hostname*: string
    supportsSinglePurchase*: bool
    supportsRecurrentPurchase*: bool
    supportedChainIds*: seq[int]
    supportedTokens*: seq[TokenDto]
    urlsNeedParameters*: bool

type 
  CryptoRampParametersDto* = ref object of RootObj
    isRecurrent*: bool
    destinationAddress*: Option[string]
    chainID*: Option[int]
    symbol*: Option[string]

proc `$`*(self: CryptoRampDto): string =
  result = "CryptoRampDto("
  result &= fmt"id:{self.id}, "
  result &= fmt"name:{self.name}, "
  result &= fmt"description:{self.description}, "
  result &= fmt"fees:{self.fees}, "
  result &= fmt"logoUrl:{self.logoUrl}, "
  result &= fmt"hostname:{self.hostname}, "
  result &= fmt"supportsSinglePurchase:{self.supportsSinglePurchase}, "
  result &= fmt"supportsRecurrentPurchase:{self.supportsRecurrentPurchase}, "
  result &= fmt"supportedChainIds:{self.supportedChainIds}, "
  result &= fmt"supportedTokens:{self.supportedTokens}, "
  result &= fmt"urlsNeedParameters:{self.urlsNeedParameters}"
  result &= ")"

proc toCryptoRampDto*(jsonObj: JsonNode): CryptoRampDto =
  result = CryptoRampDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("description", result.description)
  discard jsonObj.getProp("fees", result.fees)
  discard jsonObj.getProp("logoUrl", result.logoUrl)
  discard jsonObj.getProp("hostname", result.hostname)
  discard jsonObj.getProp("supportsSinglePurchase", result.supportsSinglePurchase)
  discard jsonObj.getProp("supportsRecurrentPurchase", result.supportsRecurrentPurchase)
  for chainID in jsonObj["supportedChainIds"].getElems():
    result.supportedChainIds.add(chainID.getInt())
  for token in jsonObj["supportedTokens"].getElems():
    let tokenDto = Json.decode($token, TokenDto, allowUnknownFields = true)
    result.supportedTokens.add(tokenDto)
  discard jsonObj.getProp("urlsNeedParameters", result.urlsNeedParameters)

proc `%`*(self: CryptoRampParametersDto): JsonNode =
  result = newJObject()
  result["isRecurrent"] = %(self.isRecurrent)
  if self.destinationAddress.isSome:
    result["destAddress"] = %(self.destinationAddress.get)
  if self.chainID.isSome:
    result["chainID"] = %(self.chainID.get)
  if self.symbol.isSome:
    result["symbol"] = %(self.symbol.get)

proc fromJson*(self: JsonNode, T: typedesc[CryptoRampParametersDto]): CryptoRampParametersDto {.inline.}  =
  result = CryptoRampParametersDto()
  discard self.getProp("isRecurrent", result.isRecurrent)
  if self.contains("destAddress"):
    result.destinationAddress = some(self["destAddress"].getStr())
  if self.contains("chainID"):
    result.chainID = some(self["chainID"].getInt())
  if self.contains("symbol"):
    result.symbol = some(self["symbol"].getStr())
