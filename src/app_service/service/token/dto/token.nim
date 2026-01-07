import std/strformat, json_serialization


type CommunityDataDto* = object
  id* {.serializedFieldName("id").}: string
  name* {.serializedFieldName("name").}: string
  color* {.serializedFieldName("color").}: string
  image* {.serializedFieldName("image").}: string

type TokenDetailsDto* = object
  description* {.serializedFieldName("Description").}: string
  assetWebsiteUrl* {.serializedFieldName("AssetWebsiteUrl").}: string

type TokenDto* = object
  crossChainId* {.serializedFieldName("crossChainId").}: string
  address* {.serializedFieldName("address").}: string
  name* {.serializedFieldName("name").}: string
  symbol* {.serializedFieldName("symbol").}: string
  decimals* {.serializedFieldName("decimals").}: int
  chainId* {.serializedFieldName("chainId").}: int
  logoUri* {.serializedFieldName("logoUri").}: string
  customToken* {.serializedFieldName("custom").}: bool
  communityData* {.serializedFieldName("communityData").}: CommunityDataDto

type TokenDtoSafe* = TokenDto

proc `$`*(self: CommunityDataDto): string =
  result = fmt"""CommunityDataDto[
    id: {self.id},
    name: {self.name},
    color: {self.color},
    image: {self.image}
  ]"""

proc `$`*(self: TokenDto): string =
  result = fmt"""TokenDto[
    crossChainId: {self.crossChainId},
    address: {self.address},
    name: {self.name},
    symbol: {self.symbol},
    decimals: {self.decimals},
    chainId: {self.chainId},
    logoUri: {self.logoUri},
    customToken: {self.customToken},
    communityData: {self.communityData},
    ]"""
